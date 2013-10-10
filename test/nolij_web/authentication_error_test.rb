require_relative '../test_helper'

describe NolijWeb::AuthenticationError do
  it "should subclass StandardError" do
    NolijWeb::AuthenticationError.ancestors.must_include(StandardError)
  end
end
