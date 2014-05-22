require 'nokogiri'
require 'uri'
module NolijWeb
  class Handler
    @@doc_handler_path    = 'handler/api/docs'
    @@doc_viewer_path     = ''
    @@workflow_path       = 'handler/api/workflow/workcomplete'
    @@api_path            = 'handler/api'

    attr_reader :connection

    def initialize(connection_config)
      @config = connection_config
      @connection = Connection.new(@config)
    end

    # Folder contents as Nokogiri XML
    # required options: :folder_id
    # additional options: :user_code, :user_id, :sort, :offset, :limit, :wfma_code
    def folder_info(options = {}, &block)
      folder_id = options[:folder_id]
      raise AttributeMissingError, 'Folder ID is required.' unless folder_id.is_a?(String) && !folder_id.empty?

      allowed_query_params_keys = [:user_code, :user_id, :sort, :offset, :limit, :wfma_code]
      query_params = format_query_params(options, allowed_query_params_keys)
      headers = options[:headers] || {}
      relative_path = [@@doc_handler_path, options[:folder_id]].join('/')

      response = @connection.get relative_path, headers.merge(:params => query_params),  &block

      folder = Nokogiri.XML(response)
    end

    # Folder contents as array
    # Returns an array of hashes with the file info for each file in the folder
    # See #folder_info for options
    def folder_contents(options = {}, &block)
      folder = folder_info(options, &block)
      files = folder.xpath('//folderobjects//folderobject')

      file_attrs = files.collect(&:attributes)
      file_attrs = file_attrs.collect {|attr|
        attr.inject({}){|n, (k,v)| n[k] = v.value; n}
      }
    end

    # Submit a file.
    # A local file path is required.
    # required options: :folder_id
    # additional options: :user_code, :wfma_code, :index_code, :dept_code, :custom_name, :folder_name
    def submit_document(local_file, options = {}, &block)
      folder_id = options[:folder_id]
      folder_id = if folder_id.kind_of?(Numeric) || folder_id.kind_of?(String)
                    folder_id.to_s
                  else
                    nil
                  end
      raise AttributeMissingError, 'Folder ID is required to submit a document.' unless folder_id.is_a?(String) && !folder_id.empty?

      local_file ||= ''
      file = begin
          File.new(local_file)
        rescue Errno::ENOENT
        end

      raise AttributeMissingError, 'Valid file or local filepath is required to submit a document.' unless file.is_a?(File)
      options[:file_name] = File.basename(file.path)
      allowed_query_params_keys = [:user_code, :wfma_code, :index_code, :dept_code, :custom_name, :file_name]
      formatted_query = query_str(:allowed_query_params_keys => allowed_query_params_keys , :query_params => options)
      relative_path = [@@doc_handler_path, folder_id].join('/') + formatted_query

      # TODO custom attributes?
      form_params = {}
      form_params[:ocrwords] = options[:ocr_words] if options.has_key?(:oci_words)
      form_params[:my_file] = file

      #upload file to nolijweb
      response = @connection.post relative_path, form_params, (options[:headers] || {}), &block

      # return Nolij file id
      doc_metadata = Nokogiri.XML(response)
      document_id = doc_metadata.xpath('//documentmeta/@documentid').first
      return document_id.value if document_id
    end

    # Print one or more documents to a single pdf
    # required options: :document_id - can be a number or an array of numbers
    # additional options: :user_code, :document_id, :user_id
    def print_document(options = {}, &block)
      doc_ids = options.delete(:document_id)
      raise AttributeMissingError, 'At least one document ID is required to print a document.' unless doc_ids
      options[:document_id] = [doc_ids].flatten.compact.collect(&:to_i).join('-')

      allowed_query_params_keys = [:user_code, :wfma_code, :user_id, :document_id]
      query_params = format_query_params(options, allowed_query_params_keys)
      headers = options[:headers] || {}
      relative_path = [@@doc_handler_path, 'print'].join('/')

      @connection.get relative_path, headers.merge(:params => query_params), &block
    end

    # Return a jpeg of a page of a document
    # required options: :document_id, :folder_id
    # additional options: :user_code, :user_id, :rotation, :wpixels, :hpixels, :redact, :annot, :wfma_code, :page
    # :page will default to 1 if no page is provided.
    def retrieve_document_image(options = {}, &block)
      folder_id = options[:folder_id]
      document_id = options[:document_id].to_i
      page = options[:page].to_i
      page = page == 0 ? 1 : page
      raise AttributeMissingError, 'Folder ID is required to retrieve a document.' unless folder_id.is_a?(String) && ! folder_id.empty?
      raise AttributeMissingError, 'Document ID is required to retrieve a document.' unless document_id > 0

      allowed_query_params_keys = [:user_code, :user_id, :rotation, :wpixels, :hpixels, :redact, :annot, :wfma_code]
      query_params = format_query_params(options, allowed_query_params_keys)
      headers = options[:headers] || {}
      relative_path = [@@doc_handler_path, folder_id, document_id, 'page', page].join('/')

      @connection.get relative_path, headers.merge(:params => query_params), &block
    end

    # Delete a document
    # required options: :document_id, :folder_id
    # additional options: :user_code, :user_id, :wfma_code
    def delete_document(options = {}, &block)
      folder_id = options[:folder_id]
      document_id = options[:document_id]
      raise AttributeMissingError, 'Folder ID is required to delete a document.' unless folder_id.is_a?(String) && ! folder_id.empty?
      raise AttributeMissingError, 'Document ID is required to delete a document.' unless document_id.is_a?(String) && ! document_id.empty?

      allowed_query_params_keys = [:user_code, :user_id, :wfma_code]
      query_params = format_query_params(options, allowed_query_params_keys)
      headers = options[:headers] || {}
      relative_path = [@@doc_handler_path, 'delete', folder_id, document_id].join('/') + formatted_query

      @connection.delete relative_path, headers.merge(:params => query_params), &block
    end

    # Retrieve metadata for a document as XML
    # required options: :document_id, :folder_id
    # additional options: :user_code, :user_id, :start, :end, :wfma_code
    def document_metadata_xml(options = {}, &block)
      folder_id = options[:folder_id]
      document_id = options[:document_id].to_i
      raise AttributeMissingError, 'Folder ID is required to retrieve a document.' unless folder_id.is_a?(String) && ! folder_id.empty?
      raise AttributeMissingError, 'Document ID is required to retrieve a document.' unless document_id > 0

      allowed_query_params_keys = [:user_code, :user_id, :start, :end, :wfma_code]
      query_params = format_query_params(options, allowed_query_params_keys)
      headers = options[:headers] || {}
      relative_path = [@@doc_handler_path, folder_id, document_id, 'documentmeta'].join('/')

      response = @connection.get relative_path, headers.merge(:params => query_params), &block
      doc = Nokogiri.XML(response)
    end

    # Retrieve metadata for a document as a hash
    # see #document_metadata_xml for options
    def document_metadata(options = {}, &block)
      doc = document_metadata_xml(options, &block)
      node = doc.xpath('/documentmeta').first
      doc_metadata = node.attributes.inject({}){|n, (k,v)| n[k] = v.value; n}
      doc_metadata['pages'] = node.xpath('//pagemeta').collect{|p|
        p.attributes.inject({}){|n, (k,v)| n[k] = v.value; n}
      }
      return doc_metadata
    end

    # URL or path to verify that user is authenticated to Nolijweb in their browser.
    # If the user is logged in redirect them to :redir path.
    # If not, redirect to login and return them to the URL provided once they've authenticated.
    # Redirect path must be relative to /public
    # :redir is required. A path is returned unless :full_url => true
    def login_check(options = {})
      raise AttributeMissingError, 'Redirect path is required to check login' unless options[:redir].is_a?(String) && !options[:redir].empty?

      full_url = options.delete(:full_url) || false
      allowed_query_params_keys = [:redir]
      formatted_query = query_str(:allowed_query_params_keys => allowed_query_params_keys , :query_params => options)

      relative_path = ['public', 'apiLoginCheck.jsp'].join('/') + formatted_query
      path = relative_path
      url = full_url ? [@connection.base_url, path].join('/') : path
      return url
    end

    # URL or path to open the standalone document viewer utility.
    # required options: :document_id is required
    # additional options: :user_code, :wfma_code
    # use option  :full_url => true for a full url, otherwise a relative path is returned.
    def viewer_url(options = {})
      raise AttributeMissingError, 'Document ID is required to launch viewer' unless (options[:document_id].is_a?(String) && !options[:document_id].empty?) || options[:document_id].is_a?(Integer)
      full_url = options.delete(:full_url) || false
      url_opts = {}
      allowed_query_params_keys = [:document_id, :user_code, :wfma_code]
      formatted_query = query_str(:allowed_query_params_keys => allowed_query_params_keys , :query_params => options)
      relative_path = [@@doc_viewer_path, 'documentviewer'].join('/') + formatted_query
      path = relative_path
      url = full_url ? [@connection.base_url, path].join('/') : path
      return url
    end

    # Issue work complete to push item along in work flow
    # required options: :wfma_code, :folder_name
    # additional options: :user_id, :user_code
    def work_complete(options = {}, &block)
      raise AttributeMissingError, 'Workflow master code is required for workflow requests.' unless options[:wfma_code]
      folder_id = options[:folder_id]
      raise AttributeMissingError, 'Folder ID is required.' unless folder_id

      raise AttributeMissingError, 'Folder name is required.' unless options[:folder_name]

      allowed_query_params_keys = [:wfma_code, :user_id, :user_code, :folder_name]
      formatted_query = query_str(:allowed_query_params_keys => allowed_query_params_keys , :query_params => options)
      relative_path = [@@workflow_path, folder_id, formatted_query].join('/')

      @connection.post relative_path, {}, options[:headers] || {}, &block
    end

    # Nolij Web server version information
    def version(&block)
      relative_path = [@@api_path, 'version'].join('/')
      response = @connection.get relative_path, &block

      info = Nokogiri.XML(response).xpath('//version').collect(&:attributes)
      info= info.collect {|attr|
        attr.inject({}){|n, (k,v)| n[k] = v.value; n}
      }.first
    end

    # TODO Add query and query results methods

private

    def query_str(options = {})
      keys = options[:allowed_query_params_keys] || []
      query_params = options[:query_params] || {}
      query_str = if query_params.empty?
            ''
          else
           format_query_params(query_params, keys).collect{|k,v| "#{k}=#{URI.escape v}"}.join('&')
          end
      return query_str.empty? ? '' : "?#{query_str}" 
    end

    # format param names and return the query hash
    def format_query_params(params = {}, keys = [])
      keys.inject([]){|m, v| v.to_sym; m}
      query_params = params.select{|k,v| keys.include?(k.to_sym)}
      cleaned = query_params.inject({}) do |p,(k,v)|
        key = k.to_s.gsub('_', '').to_sym
        value = v.to_s
        p[key] = value
        p 
      end
      return cleaned.reject{|k,v| v.empty?}
    end
  end
end
