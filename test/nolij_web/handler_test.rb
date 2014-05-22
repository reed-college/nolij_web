require_relative '../test_helper'

describe NolijWeb::Handler do
  before do
    @base_url = 'http://example.reed.edu/NolijWeb'
    @handler = NolijWeb::Handler.new({:username => 'test_user', :password => 'test_password', :base_url => @base_url})
    # stub auth
    stub_request(:post, "#{@base_url}/j_spring_security_check").
  with(:body => {"j_password"=>"test_password", "j_username"=>"test_user"}).to_return(:status => 200)
    stub_request(:get, "http://example.reed.edu/NolijWeb/j_spring_security_logout").to_return(:status => 200)
  end

  describe "initialize" do
    it "should respond to connection" do
      @handler.respond_to?(:connection)
    end

    it "should set a connection" do
      @handler.instance_variable_get(:@connection).wont_be_nil
    end

    it "should set a config" do
      @handler.instance_variable_get(:@config).wont_be_nil
    end
  end

  describe "with valid folder request" do
    before do
      @folder_id = '1_2'
      response = File.new(File.join(File.expand_path(File.dirname(__FILE__)), 'test_stubs', 'folder_info.xml'))
      @stubbed_request = stub_request(:get, /\/handler\/api\/docs\/#{@folder_id}/).to_return(:status => 200, :body => response)
    end

    describe "#folder_info" do
      it "should raise missing attribute if no id is supplied" do
        err = lambda{@handler.folder_info}.must_raise(NolijWeb::AttributeMissingError)
        err.to_s.must_match /Folder ID is required/
      end

      it "should get stubbed url" do
        folder_info = @handler.folder_info(:folder_id => @folder_id)
        assert_requested @stubbed_request
      end

      it "should return nokogiri xml document" do
        folder_info = @handler.folder_info(:folder_id => @folder_id)
        folder_info.must_be_kind_of(Nokogiri::XML::Document)
      end
    end

    describe "#folder_contents" do
      it "should get stubbed url" do
        folder_info = @handler.folder_contents(:folder_id => @folder_id)
        assert_requested @stubbed_request
      end

      it "should return an array" do
        folder_contents = @handler.folder_contents(:folder_id => @folder_id)
        folder_contents.must_be_kind_of(Array)
      end
    end
  end

  describe "#submit_document" do
    it "should raise missing attribute if no folder id is supplied" do
      err = lambda{@handler.submit_document('test_file.txt', {:folder_id => nil})}.must_raise(NolijWeb::AttributeMissingError)
      err.to_s.must_match /Folder ID is required/
    end

    it "should raise missing attribute if folder id is supplied but no file" do
      err = lambda{@handler.submit_document(nil, {:folder_id => '234_324'})}.must_raise(NolijWeb::AttributeMissingError)
      err.to_s.must_match /path is required/
    end

    describe 'with valid folder and file path' do
      before do
        @file_path = File.join(File.expand_path(File.dirname(__FILE__)), 'test_stubs', 'text_file.txt')
        @folder_id = '1_2'
        response = File.new(File.join(File.expand_path(File.dirname(__FILE__)), 'test_stubs', 'document_submitted_success.xml'))
        @stubbed_request = stub_request(:post, /\/handler\/api\/docs\/#{@folder_id}/).to_return(:status => 200, :body => response)
      end

      it "should post to connection url" do
        file_upload = @handler.submit_document(@file_path, :folder_id => @folder_id)
        assert_requested @stubbed_request
      end

      it "should return a file id" do
        #96855 is set in test_stubs/file_posted.xml
        file_upload = @handler.submit_document(@file_path, :folder_id => @folder_id)
        file_upload.must_equal '96855'
      end
    end
  end

  describe '#print_document' do
    before do
      @document_ids = ['12345', '54326']
      @folder_id = '111_2'
      @stubbed_request = stub_request(:get, /\/handler\/api\/docs\/print/).to_return(:status => 200)
    end

    it "should raise missing attribute if no document ids supplied" do
      err = lambda{@handler.print_document}.must_raise(NolijWeb::AttributeMissingError)
      err.to_s.must_match /document ID is required/i
    end

    it "should get print document" do
      @handler.print_document(:document_id => @document_ids)
      assert_requested @stubbed_request
    end
  end


  describe '#retrieve_document_image' do
    before do
      @document_id = '12345'
      @folder_id = '111_2'
      @stubbed_request = stub_request(:get, /\/handler\/api\/docs\/#{@folder_id}\/#{@document_id}\/page\/1/).to_return(:status => 200)
    end

    it "should raise missing attribute if no document id supplied" do
      err = lambda{@handler.retrieve_document_image(:folder_id => '1243')}.must_raise(NolijWeb::AttributeMissingError)
      err.to_s.must_match /document ID is required/i
    end

    it "should raise missing attribute if no folder id supplied" do
      err = lambda{@handler.retrieve_document_image(:document_id => '123')}.must_raise(NolijWeb::AttributeMissingError)
      err.to_s.must_match /folder ID is required/i
    end

    it "should get document image" do
      @handler.retrieve_document_image(:document_id => @document_id, :folder_id => @folder_id, :page => 1)
      assert_requested @stubbed_request
    end

    it "should set page to 1 when no page" do
      @handler.retrieve_document_image(:document_id => @document_id, :folder_id => @folder_id)
      assert_requested @stubbed_request
    end
  end

  describe "document_metadata methods" do
    before do
      @folder_id = '1_2'
      @document_id = '1111'
      response = File.new(File.join(File.expand_path(File.dirname(__FILE__)), 'test_stubs', 'document_metadata.xml'))
      @stubbed_request = stub_request(:get, /\/handler\/api\/docs\/#{@folder_id}\/#{@document_id}\/documentmeta/).to_return(:status => 200, :body => response)
    end

    describe '#document_metadata_xml' do
      it "should raise missing attribute if no folder id is supplied" do
        err = lambda{@handler.document_metadata_xml(:document_id => @document_id)}.must_raise(NolijWeb::AttributeMissingError)
        err.to_s.must_match /Folder ID is required/i
      end

      it "should raise missing attribute if no document_id is supplied" do
        err = lambda{@handler.document_metadata_xml(:folder_id => @folder_id)}.must_raise(NolijWeb::AttributeMissingError)
        err.to_s.must_match /document ID is required/i
      end

      it "should get stubbed url" do
        document_metadata = @handler.document_metadata_xml(:folder_id => @folder_id, :document_id => @document_id)
        assert_requested @stubbed_request
      end

      it "should return nokogiri xml document" do
        document_metadata = @handler.document_metadata_xml(:folder_id => @folder_id, :document_id => @document_id)
        document_metadata.must_be_kind_of(Nokogiri::XML::Document)
      end
    end

    describe '#document_metadata' do
      it "should return nokogiri a hash" do
        document_metadata = @handler.document_metadata(:folder_id => @folder_id, :document_id => @document_id)
        document_metadata.must_be_kind_of(Hash)
      end
    end
  end

  describe '#viewer_url' do
    it "should raise missing attribute if no document id supplied" do
      err = lambda{@handler.viewer_url}.must_raise(NolijWeb::AttributeMissingError)
      err.to_s.must_match /document ID is required/i
    end

    it "should return a full url if full url is true" do
      @handler.viewer_url(:document_id => '1234', :full_url => true).must_match /^#{@base_url}/
    end

    it "return a path if full url is empty" do
      @handler.viewer_url(:document_id => '1234').wont_match /^#{@base_url}/
    end

    it "return a path if full url is false" do
      @handler.viewer_url(:document_id => '1234', :full_url => false).wont_match /^#{@base_url}/
    end

    it "should return a string" do
      @handler.viewer_url(:document_id => '1234').must_be_kind_of(String)
    end
  end

  describe '#login_check' do
    it "should raise missing attribute if no redirect_to_path is supplied" do
      err = lambda{@handler.login_check}.must_raise(NolijWeb::AttributeMissingError)
      err.to_s.must_match /redirect path is required/i
    end

    it "should raise missing attribute if redirect_to_path is empty" do
      err = lambda{@handler.login_check(:redir => '')}.must_raise(NolijWeb::AttributeMissingError)
      err.to_s.must_match /redirect path is required/i
    end

    it "should return a full url if full url is true" do
      @handler.login_check(:redir => '/document_path', :full_url => true).must_match /^#{@base_url}/
    end

    it "return a path if full url is empty" do
      @handler.login_check(:redir => '/document_path').wont_match /^#{@base_url}/
    end

    it "return a path if full url is false" do
      @handler.login_check(:redir => '/document_path', :full_url => false).wont_match /^#{@base_url}/
    end

    it "should return a string" do
      @handler.login_check(:redir => '/document_path').must_be_kind_of(String)
    end
  end

  describe '#work_complete' do
    before do
      @folder_id = '12334'
      @folder_name = "Schmoe, Joe"
      @wfma_code = '12344'
    end

    it "should raise missing attribute if no wfma code supplied" do
      err = lambda{@handler.work_complete(:folder_name => @folder_name, :folder_id => @folder_id)}.must_raise(NolijWeb::AttributeMissingError)
      err.to_s.must_match /workflow master code is required/i
    end

    it "should raise missing attribute if no folder name supplied" do
      err = lambda{@handler.work_complete(:wfma_code => '1234', :folder_id => @folder_id)}.must_raise(NolijWeb::AttributeMissingError)
      err.to_s.must_match /folder name is required/i
    end

    it "should raise missing attribute if no folder id supplied" do
      err = lambda{@handler.work_complete(:wfma_code => '1234', :folder_name => @folder_name)}.must_raise(NolijWeb::AttributeMissingError)
      err.to_s.must_match /folder id is required/i
    end

    it "should post to work complete" do
      stubbed_request = stub_request(:post, /\/handler\/api\/workflow\/workcomplete\/#{@folder_id}/).with(:query => hash_including({:wfmacode => @wfma_code, :foldername => @folder_name.to_s})).to_return(:status => 200)
      @handler.work_complete(:folder_id => @folder_id, :wfma_code => @wfma_code, :folder_name => @folder_name)
      assert_requested stubbed_request
    end
  end

  describe "#version" do
    before do
      response = File.new(File.join(File.expand_path(File.dirname(__FILE__)), 'test_stubs', 'version_info.xml'))
      @stubbed_request = stub_request(:get, /\/handler\/api\/version/).to_return(:status => 200, :body => response)
    end

    it "should get stubbed url" do
      @handler.version
      assert_requested @stubbed_request
    end

    it "should return an hash" do
      @handler.version.must_be_kind_of(Hash)
    end
  end

end
