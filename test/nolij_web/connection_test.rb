require_relative '../test_helper'

describe NolijWeb::Connection do
  # Format cookies for webmock headers
  def to_cookie(cookies = {})
    cookies.sort_by{|k, v| k.to_s}.collect{|c| "#{c[0]}=#{c[1]}"}.join('; ')
  end

  # Set up basic configured connection as @conn
  def setup_configured_connection
    username = 'test_monkey'
    pw = 'test_banana'
    @base_url = 'http://banana.example.com/NolijWeb'
    @conn = NolijWeb::Connection.new({:username => username, :password => pw, :base_url => @base_url})
  end

  #stubs connection and requests for full authenticated round trip
  def stub_connection_round_trip(connection)
    @cookies = {'a' => 'b'}

    @stubbed_login = stub_request(:post, "#{@base_url}/j_spring_security_check").
    with(:body => {"j_password"=> connection.instance_variable_get(:@password), "j_username"=> connection.instance_variable_get(:@username)}).to_return(:status => 200, :headers => {'Set-Cookie' => to_cookie(@cookies)}.merge(WEBMOCK_HEADERS))

    @stubbed_logout = stub_request(:get, "#{@base_url}/j_spring_security_logout").with(:headers => {'Cookie' => to_cookie(@cookies)}.merge(WEBMOCK_HEADERS))
  end

  describe '# initialize' do
    describe 'with no config' do
      it "should raise config error" do
        err = lambda{NolijWeb::Connection.new(nil)}.must_raise(NolijWeb::ConnectionConfigurationError)
        err.to_s.must_match /invalid configuration/i
      end
    end

    describe 'defaults initialization behavior' do
      before do
        @conn = NolijWeb::Connection.new({})
      end

      it "should have nil connection instance var" do
        @conn.instance_variable_get(:@connection).must_be_nil
      end

      it "should have nil cookies instance var" do
        @conn.instance_variable_get(:@cookies).must_be_nil
      end

      it "should have string username instance var" do
        @conn.instance_variable_get(:@username).must_be_kind_of(String)
      end

      it "should have string password instance var" do
        @conn.instance_variable_get(:@password).must_be_kind_of(String)
      end

      it "should have string base_url instance var" do
        @conn.instance_variable_get(:@base_url).must_be_kind_of(String)
      end
    end

    describe 'set config for new instances' do
      describe "with hash config" do
        before do
          @conn = NolijWeb::Connection.new({:username => 'test_monkey', :password => 'banana oooeee', :base_url => 'http://testsomething.example.com/NolijWeb'})
        end

        it "should have string username instance var" do
          @conn.instance_variable_get(:@username).must_equal 'test_monkey'
        end

        it "should have string password instance var" do
          @conn.instance_variable_get(:@password).must_equal 'banana oooeee'
        end

        it "should have string base_url instance var" do
          @conn.instance_variable_get(:@base_url).must_equal 'http://testsomething.example.com/NolijWeb'
        end

        it "should have hash config" do
          @conn.instance_variable_get(:@config).must_be_kind_of(Hash)
        end
      end

      describe "with yaml config" do
        before do
          @conn = NolijWeb::Connection.new(File.join(File.expand_path(File.dirname(__FILE__)), 'test_stubs', 'nolij_config.yml'))
        end

        it "should have string username instance var" do
          @conn.instance_variable_get(:@username).must_equal 'monkey'
        end

        it "should have string password instance var" do
          @conn.instance_variable_get(:@password).must_equal 'banana'
        end

        it "should have string base_url instance var" do
          @conn.instance_variable_get(:@base_url).must_equal 'http://testsomething2.example.com/NolijWeb'
        end

        it "should have hash config" do
          @conn.instance_variable_get(:@config).must_be_kind_of(Hash)
        end
      end
    end
  end

  describe '#configure' do
    before do
      @conn = NolijWeb::Connection.new({})
      @conn.configure({:username => 'new_user', :password => 'new_password', :base_url => 'http://newsomething.example.com/NolijWeb'})
    end

    it "should define config" do
      @conn.instance_variable_get(:@config).must_be_kind_of(Hash)
    end

    it "should define base_url" do
      @conn.instance_variable_get(:@base_url).must_equal 'http://newsomething.example.com/NolijWeb'
    end

    it "should define username" do
      @conn.instance_variable_get(:@username).must_equal 'new_user'
    end

    it "should define password" do
      @conn.instance_variable_get(:@password).must_equal 'new_password'
    end

    it "should define nil connection" do
      @conn.instance_variable_get(:@connection).must_be_nil
    end

    it "should define nil cookies" do
      @conn.instance_variable_get(:@cookies).must_be_nil
    end
  end

  describe '#configure_with' do
    before do
      @conn = NolijWeb::Connection.new({})
    end

    it "should raild ConnectionConfigurationError for invalid string parameter" do
      err = lambda{
                    @conn.configure_with([])
                  }.must_raise(NolijWeb::ConnectionConfigurationError)
      err.to_s.must_match /invalid request/i
    end

    it "should raise ConnectionConfigurationError for invalid syntax" do
      err = lambda{
                    @conn.configure_with(File.join(File.expand_path(File.dirname(__FILE__)), 'test_stubs', 'bad_nolij_config.yml'))
                  }.must_raise(NolijWeb::ConnectionConfigurationError)
      err.to_s.must_match /invalid syntax/i
    end

    it "should raise ConnectionConfigurationError for no file" do
      err = lambda{
                    @conn.configure_with('gobble.yml')
                  }.must_raise(NolijWeb::ConnectionConfigurationError)
      err.to_s.must_match /not found/i
    end  
  end

  describe '#establish_connection' do
    before do
      setup_configured_connection
      stub_connection_round_trip(@conn)
    end

    it "should request login url" do
      @conn.establish_connection
      assert_requested @stubbed_login
    end

    it "should assign instance var cookies" do
      @conn.establish_connection
      @conn.instance_variable_get(:@cookies).must_equal @cookies
    end

    it "should assign not nil connection" do
      @conn.establish_connection
      @conn.instance_variable_get(:@connection).wont_be_nil
    end
  end

  describe '#close_connection' do
    describe "when not logged in" do
      before do
        setup_configured_connection
        @stubbed_logout = stub_request(:get, "#{@base_url}/j_spring_security_logout")
      end

      it "should not request logout url" do
        @conn.close_connection
        @conn.connection.must_be_nil
        assert_not_requested @stubbed_logout
      end

      it "should set nil connection" do
        @conn.instance_variable_set(:@connection, MiniTest::Mock.new)
        @conn.close_connection
        @conn.instance_variable_get(:@connection).must_be_nil
      end

      it "should set nil cookies" do
        @conn.instance_variable_set(:@cookies, MiniTest::Mock.new)
        @conn.close_connection
        @conn.instance_variable_get(:@cookies).must_be_nil
      end
    end

    describe "when logged in" do
      before do
        setup_configured_connection
        stub_connection_round_trip(@conn)
      end

      it "should request logout url" do
        assert @conn.establish_connection
        @conn.close_connection
        assert_requested @stubbed_logout
      end

      it "should reset nil connection" do
        assert @conn.establish_connection
        @conn.instance_variable_get(:@connection).wont_be_nil
        @conn.close_connection
        @conn.instance_variable_get(:@connection).must_be_nil
      end

      it "should set not nil cookies" do
        assert @conn.establish_connection
        @conn.instance_variable_get(:@cookies).wont_be_nil
        @conn.close_connection
        @conn.instance_variable_get(:@cookies).must_be_nil
      end
    end
  end

  describe "#get_custom_connection" do
    before do
      setup_configured_connection
      stub_connection_round_trip(@conn)
      @stubbed_get = stub_request(:get, "#{@base_url}/go").to_return(:status => 200, :headers => {'Cookie' => to_cookie(@cookies)}.merge(WEBMOCK_HEADERS))
    end

    it "should not open connection" do
      @conn.get_custom_connection('go')
      assert_not_requested @stubbed_login
    end

    it "should get input path at base url with cookies" do
      @conn.get_custom_connection('go')
      assert_requested @stubbed_get
    end

    it "should not close connection" do
      @conn.get_custom_connection('go')
      assert_not_requested @stubbed_logout
    end
  end

  describe '#get' do
    before do
      setup_configured_connection
      stub_connection_round_trip(@conn)
      @stubbed_get = stub_request(:get, "#{@base_url}/go").to_return(:status => 200, :headers => {'Cookie' => to_cookie(@cookies)}.merge(WEBMOCK_HEADERS))
    end

    it "should open connection" do
      @conn.get('go')
      assert_requested @stubbed_login
    end

    it "should get input path at base url with cookies" do
      @conn.get('go')
      assert_requested @stubbed_get
    end

    it "should close connection" do
      @conn.get('go', {})
      assert_requested @stubbed_logout
    end
  end

  describe "#delete_custom_connection" do
    before do
      setup_configured_connection
      stub_connection_round_trip(@conn)
      @stubbed_get = stub_request(:delete, "#{@base_url}/go").to_return(:status => 200, :headers => {'Cookie' => to_cookie(@cookies)}.merge(WEBMOCK_HEADERS))
    end

    it "should not open connection" do
      @conn.delete_custom_connection('go')
      assert_not_requested @stubbed_login
    end

    it "should get input path at base url with cookies" do
      @conn.delete_custom_connection('go')
      assert_requested @stubbed_get
    end

    it "should not close connection" do
      @conn.delete_custom_connection('go')
      assert_not_requested @stubbed_logout
    end
  end

  describe '#delete' do
    before do
      setup_configured_connection
      stub_connection_round_trip(@conn)
      @stubbed_get = stub_request(:delete, "#{@base_url}/go").to_return(:status => 200, :headers => {'Cookie' => to_cookie(@cookies)}.merge(WEBMOCK_HEADERS))
    end

    it "should open connection" do
      @conn.delete('go')
      assert_requested @stubbed_login
    end

    it "should get input path at base url with cookies" do
      @conn.delete('go')
      assert_requested @stubbed_get
    end

    it "should close connection" do
      @conn.delete('go', {})
      assert_requested @stubbed_logout
    end
  end

  describe '#post_custom_connection' do
    before do
      setup_configured_connection
      stub_connection_round_trip(@conn)
      @post_params = {'a' => 'b'}
      @stubbed_post = stub_request(:post, "#{@base_url}/go").with(:body => @post_params).to_return(:status => 200, :headers => {'Cookie' => to_cookie(@cookies)}.merge(WEBMOCK_HEADERS))
    end

    it "should not open connection" do
      @conn.post_custom_connection('go', @post_params)
      assert_not_requested @stubbed_login
    end

    it "should post to input path at base url with params and cookies" do
      @conn.post_custom_connection('go', @post_params)
      assert_requested @stubbed_post
    end

    it "should not close connection" do
      @conn.post_custom_connection('go', @post_params)
      assert_not_requested @stubbed_logout
    end
  end

  describe '#post' do
    before do
      setup_configured_connection
      stub_connection_round_trip(@conn)
      @post_params = {'a' => 'b'}
      @stubbed_post = stub_request(:post, "#{@base_url}/go").with(:body => @post_params).to_return(:status => 200, :headers => {'Cookie' => to_cookie(@cookies)}.merge(WEBMOCK_HEADERS))
    end

    it "should open connection" do
      @conn.post('go', @post_params)
      assert_requested @stubbed_login
    end

    it "should post to input path at base url with params and cookies" do
      @conn.post('go', @post_params)
      assert_requested @stubbed_post
    end

    it "should close connection" do
      @conn.post('go', @post_params)
      assert_requested @stubbed_logout
    end
  end

  describe '#execute' do
    before do
      setup_configured_connection
      stub_connection_round_trip(@conn)
    end

    it "should establish connection" do
      @conn.execute { "something to do" }
      assert_requested @stubbed_login
    end

    it "should close connection when successful" do
      @conn.execute { "something to do" }
      assert_requested @stubbed_logout
    end

    it "should yield the block" do
      result = @conn.execute { "something to do" }
      result.must_equal 'something to do'
    end
  end

end
