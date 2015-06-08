require 'rubygems'
gem 'minitest'

require 'minitest/autorun'
require 'minitest/pride'

require 'webmock/minitest'

require File.expand_path('../../lib/nolij_web.rb', __FILE__)

WebMock.disable_net_connect!(:allow_localhost => true)

WEBMOCK_HEADERS = {'Accept'=>'*/*; q=0.5, application/xml', 'Accept-Encoding'=>'gzip, deflate', 'User-Agent'=>'Ruby'}