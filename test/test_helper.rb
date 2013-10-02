require 'rubygems'
gem 'minitest'

require 'minitest/autorun'
require 'minitest/pride'

require 'webmock/minitest'

require File.expand_path('../../lib/nolij_web.rb', __FILE__)

WebMock.disable_net_connect!
