require_relative '../test_helper'

describe NolijWeb::AttributeMissingError do
  it "should subclass StandardError" do
    NolijWeb::AttributeMissingError.ancestors.must_include(StandardError)
  end
end
