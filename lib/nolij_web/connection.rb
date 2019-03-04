
require 'rest_client'
require 'logger'

module NolijWeb
=begin rdoc
Nolijweb::Connection is the class that handles actual Nolijweb api sessions and requests. 

===Basic Usage

#get, #post, #delete will automatically wrap your request in open and close connection. Arguments are passed through to RestClient, so see RestClient docs for more options.
  
  conn = NolijWeb::Connection.new(config_hash_or_yaml_path)
  conn.get('/print', :query_params => { :document_id => 1})

===Manual Usage
You can manually establish a connection and use the _custom_connection methods to execute multiple requests in series.

Be sure to close the connection when you are finished.

  conn = NolijWeb::Connection.new(config_hash_or_yaml_path)
  conn.establish_connection
   # do some stuff using get, post, etc. (_custom_connection methods)
  close_connection
=end
  class Connection
    attr_reader :base_url
    attr_reader :username
    attr_reader :cookies
    attr_reader :connection
    attr_reader :headers

    @@valid_config_keys = [:username, :password, :base_url, :verify_ssl]

    def initialize(config)
      if config.is_a?(String)
        configure_with(config)
      elsif config.is_a?(Hash)
        configure(config)
      else
        raise ConnectionConfigurationError, 'Invalid configuration options supplied.'
      end
    end

    # Configure using hash
    def configure(opts = {})
      @config = clean_config_hash(opts)

      raise ConnectionConfigurationError, 'Nolij Web Connection configuration failed.' unless @config

      @base_url = @config[:base_url] || ''
      @username = @config[:username] || ''
      @password = @config[:password] || ''
      @verify_ssl = (@config[:verify_ssl].nil? || @config[:verify_ssl] === true) ? true : !((@config[:verify_ssl] === false) || (@config[:verify_ssl] =~ /^(false|f|no|n|0)$/i))
      @connection = nil
      @cookies = nil
      @headers = {}
    end

    # Configure with yaml
    def configure_with(path_to_yaml_file)
      raise ConnectionConfigurationError, "Invalid request. #configure_with requires string" unless path_to_yaml_file.is_a?(String)
      begin
        @config = YAML::load(ERB.new(IO.read(path_to_yaml_file)).result)
      rescue Errno::ENOENT
        raise ConnectionConfigurationError, "YAML configuration file was not found."
        return
      rescue Psych::SyntaxError
       raise ConnectionConfigurationError, "YAML configuration file contains invalid syntax."
       return
      end

      configure(@config)
    end

    def establish_connection
      @connection = post_custom_connection("#{@base_url}/j_spring_security_check", {:j_username => @username, :j_password => @password}) { |response, request, result, &block|
        if [301, 302, 307].include? response.code
          response
        else
          response.return!(request, result, &block)
        end
      }
      @cookies = @connection.cookies if @connection
      @headers = {:cookies => @cookies}
      return true if @connection
    end

    def close_connection
      rest_client_wrapper(:get, "#{@base_url}/j_spring_security_logout", :cookies => @cookies) if @connection
      @connection = nil
      @cookies = nil
      @headers = {}
      return true
    end

    def get(path, headers = {}, &block)
      execute(headers) do
        get_custom_connection(path, @headers, &block)
      end
    end

    def delete(path, headers = {}, &block)
      execute(headers) do
        delete_custom_connection(path, @headers, &block)
      end
    end

    def post(path, payload, headers = {}, &block)
      execute(headers) do
        post_custom_connection(path, payload, @headers, &block)
      end
    end

    def execute(headers = {}, &block)
      establish_connection
      if @connection
        merge_headers(headers)
        yield(block)
      end
    ensure
      close_connection
    end

    # Use this inside an execute block to make mulitiple calls in the same request
    def get_custom_connection(path, headers = {}, &block)
      block ||= default_response_handler
      url = URI.join(@base_url, URI.parse(@base_url).path + '/', URI.encode(path.to_s)).to_s
      rest_client_wrapper(:get, url, headers, &block)
    end

    # Use this inside an execute block to make mulitiple calls in the same request
    def delete_custom_connection(path, headers = {}, &block)
      block ||= default_response_handler
      url = URI.join(@base_url, URI.parse(@base_url).path + '/', URI.encode(path.to_s)).to_s
      rest_client_wrapper(:delete, url, headers, &block)
    end

    # Use this inside an execute block to make mulitiple calls in the same request
    def post_custom_connection(path, payload, headers = {}, &block)
      block ||= default_response_handler
      url = URI.join(@base_url, URI.parse(@base_url).path + '/', URI.encode(path.to_s)).to_s
      RestClient::Request.execute(method: :post, url: url, payload: payload, headers: headers, verify_ssl: @verify_ssl, &block)
    end

    # RestClient.get/put/delete offer no way to pass additional arguments, so 
    # a wrapper is recommended: 
    # https://github.com/rest-client/rest-client/issues/297
    def rest_client_wrapper(method, url, headers={}, &block)
      RestClient::Request.execute(method: method, url: url, headers: headers, verify_ssl: @verify_ssl, &block)
    end

private

    def clean_config_hash(config)
      clean_config = {}
      config = config.each {|k,v| config[k.to_sym] = v}
      @@valid_config_keys.each{|k| clean_config[k] = config[k]}

      return clean_config
    end

    def merge_headers(headers = {})
      instance_cookies = @headers.delete(:cookies) || {}
      local_cookies = headers.delete(:cookies) || {}
      @headers = @headers.merge(headers)
      @headers[:cookies] = instance_cookies.merge(local_cookies)
      return @headers
    end

    def default_response_handler
      @default_response_handler ||= lambda{ |response, request, result, &block|
                                      case response.code
                                      when 200
                                        #Success!
                                        return response
                                      when 302
                                        raise AuthenticationError, 'User is not logged in.'
                                      when 401
                                        raise AuthenticationError, 'Request requires authentication'
                                      else
                                        # Some other error. Let it bubble up.
                                        response.return!(request, result, &block)
                                      end
                                    }
    end
  end
end
