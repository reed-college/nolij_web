require 'nokogiri'
require 'uri'
module NolijWeb
  class Handler
    @@doc_handler_path   = 'handler/api/docs'
    @@doc_viewer_path    = ''
    @@workflow_path      = 'handler/api/workflow/workcomplete'

    def initialize(connection_config)
      @config = connection_config
      @connection = Connection.new(@config)
    end

    # Folder contents
    # required options: :folder_id
    # additional options: :user_code, :user_id, :sort, :offset, :limit, :wmfa_code
    def folder_info(options = {}, &block)
      raise AttributeMissingError, 'Folder ID is required.' unless options[:folder_id]

      allowed_query_params_keys = [:user_code, :user_id, :sort, :offset, :limit, :wmfa_code]
      formatted_query = query_str(:allowed_query_params_keys => allowed_query_params_keys , :query_params => options)
      relative_path = [@@doc_handler_path, options[:folder_id]].join('/') + formatted_query

      response = @connection.get relative_path, options[:headers] || {}, &block

      folder = Nokogiri.XML(response)
    end

    # Returns an array of hashes with the file info for each file in the folder
    # See #folder_info for options
    def folder_contents(options = {}, &block)
      folder = folder_info(options, &block)
      files = folder.xpath('//folderobjects//folderobject')

      file_attrs = files.collect{|f| f.attributes}
      file_attrs = file_attrs.collect {|attr|
        attr.inject({}){|n, (k,v)| n[k] = v.value; n}
      }
    end

    # Submit a file.
    # A file is required.
    # required options: :folder_id
    # additional options: :user_code, :wmfa_code, :index_code, :dept_code, :custom_name, :folder_name
    def submit_document(local_file, options = {}, &block)
      folder_id = options[:folder_id] || ''
      raise AttributeMissingError, 'Folder ID is required to submit a document.' if folder_id.empty?

      local_file ||= ''
      file = begin
          File.new(local_file)
        rescue Errno::ENOENT
        end
      raise AttributeMissingError, 'Valid file is required to submit a document.' unless file.is_a?(File)

      allowed_query_params_keys = [:user_code, :wmfa_code, :index_code, :dept_code, :custom_name, :folder_name]
      formatted_query = query_str(:allowed_query_params_keys => allowed_query_params_keys , :query_params => options)
      relative_path = [@@doc_handler_path, options[:folder_id]].join('/') + formatted_query

      # TODO custom attributes?
      form_params = {}
      form_params['ocrwords'] = options[:ocr_words]
      form_params['filename'] = local_file

      #upload file to nolijweb
      response = @connection.post relative_path, {:params => form_params, :filename => file}, options[:headers] || {}

      # return Nolij file id
      doc_metadata = Nokogiri.XML(response)
      document_id = doc_metadata.xpath('//documentmeta/@documentid').first
      return document_id.value if document_id
    end

    # Print one or more documents to a single pdf
    # required options: document_ids - can be a numer or an array of numbers
    # additional options: :user_code, :document_id, :user_id
    def print_document(options = {}, &block)
      options.inspect
      doc_ids = options.delete(:document_ids)
      raise AttributeMissingError, 'At least one document ID is required to print a document.' unless doc_ids
      doc_ids = [doc_ids].flatten.compact.collect(&:to_i).join('-')
      options[:document_id] = doc_ids

      allowed_query_params_keys = [:user_code, :document_id, :user_id]
      formatted_query = query_str(:allowed_query_params_keys => allowed_query_params_keys , :query_params => options)
      relative_path = [@@doc_handler_path, 'print'].join('/') + formatted_query

      @connection.get relative_path, options[:headers] || {}, &block
    end


    # URL or path to open the standalone document viewer utility.
    # required options: :document_id is required
    # additional options: :user_code, :wmfa_code
    # use option  :full_url => true for a full url, otherwise a relative path is returned.
    def viewer_url(options = {})
      raise AttributeMissingError, 'Document ID is required to launch viewer' unless options[:document_id].to_i > 0
      full_url = options.delete(:full_url) || false
      url_opts = {}
      allowed_query_params_keys = [:document_id, :user_code, :wmfa_code]
      formatted_query = query_str(:allowed_query_params_keys => allowed_query_params_keys , :query_params => options)
      relative_path = [@@doc_viewer_path, 'documentviewer'].join('/') + formatted_query
      path = relative_path
      url = full_url ? [@connection.base_url, path].join('/') : path
      return url
    end

    # Issue work complete to push item along in work flow
    # required options: :wmfa_code, :folder_name
    # additional options: :user_id, :user_code
    def work_complete(options = {}, &block)
      raise AttributeMissingError, 'Workflow master code is required for workflow requests.' unless options[:wmfa_code]
      raise AttributeMissingError, 'Folder name is required.' unless options[:folder_name]
      folder_id = options[:folder_id]
      raise AttributeMissingError, 'Folder ID is required.' unless folder_id

      allowed_query_params_keys = [:folder_name, :wmfa_code, :user_id, :user_code]
      formatted_query = query_str(:allowed_query_params_keys => allowed_query_params_keys , :query_params => options)
      relative_path = [@@workflow_path, folder_id].join('/') + formatted_query

      @connection.post relative_path, {}, options[:headers] || {}, &block
    end

private

    def query_str(options = {})
      keys = options[:allowed_query_params_keys] || []
      query_params = options[:query_params] || {}
      query_str = query_params.empty? ? '' : URI.encode_www_form(format_query_params(query_params, keys))

      return query_str.empty? ? '' : "?#{query_str}" 
    end

    def format_query_params(params = {}, keys = [])
      keys.inject([]){|m, v| v.to_sym; m}
      query_params = params.select{|k,v| keys.include?(k.to_sym)}
      cleaned = query_params.inject({}) do |p,(k,v)|
        key = k.to_s.gsub('_', '').to_sym
        value = v.to_s #needs_uri_escape_keys.include?(key) ? URI.escape(v.to_s) : v.to_s
        p[key] = value
        p 
      end
      return cleaned.reject{|k,v| v.empty?}
    end

    def needs_uri_escape_keys
      []# [:foldername, :customname]
    end
  end
end
