require_relative '../test_helper'

describe NolijWeb::ConnectionConfigurationError do
  it "should subclass StandardError" do
    NolijWeb::ConnectionConfigurationError.ancestors.must_include(StandardError)
  end
end
