require 'rest_client'
require 'logger'

module NolijWeb
  class Connection
    attr_reader :base_url
    attr_reader :username
    attr_reader :cookies
    attr_reader :connection

    @@valid_config_keys = [:username, :password, :base_url]

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
      @connection = nil
      @cookies = nil
    end

    # Configure with yaml
    def configure_with(path_to_yaml_file)
      raise ConnectionConfigurationError, "Invalid request. #configure_with requires string" unless path_to_yaml_file.is_a?(String)
      begin
        @config = YAML::load(IO.read(path_to_yaml_file))
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
      @connection = RestClient.post("#{@base_url}/j_spring_security_check", {:j_username => @username, :j_password => @password}) { |response, request, result, &block|
        if [301, 302, 307].include? response.code
          response
        else
          response.return!(request, result, &block)
        end
      }
      @cookies = @connection.cookies if @connection
      return true if @connection
    end

    def close_connection
      RestClient.get("#{@base_url}/j_spring_security_logout", :cookies => @cookies) if @connection
      @connection = nil
      @cookies = nil
      return true
    end

    def get(path, headers = {}, &block)
      url = URI.join(@base_url, URI.parse(@base_url).path + '/', path.to_s).to_s
      execute(headers) do
        headers = apply_connection_cookies(headers)
        RestClient.get(url, headers, &block)
      end
    end

    def post(path, payload, headers = {}, &block)
      url = URI.join(@base_url, URI.parse(@base_url).path + '/', path.to_s).to_s
      execute(headers) do
        headers = apply_connection_cookies(headers)
        RestClient.post(url, payload, headers , &block)
      end
    end

    def execute(headers, &block)
      begin
        establish_connection
        if @connection
          yield(block)
        end
      rescue
      ensure
        close_connection
      end
    end

private

    def clean_config_hash(config)
      clean_config = {}
      config = config.each {|k,v| config[k.to_sym] = v}
      @@valid_config_keys.each{|k| clean_config[k] = config[k]}

      return clean_config
    end

    def apply_connection_cookies(headers)
      if headers[:cookies].is_a?(Hash)
        headers[:cookies].merge(@cookies)
      else
        headers[:cookies] = @cookies
      end
      return headers
    end
  end
end
