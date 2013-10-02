require_relative '../test_helper'

describe NolijWeb::Version do
  it "must match format" do
    NolijWeb::Version::VERSION.must_match  /\d+\.\d+\.\d+/
  end
end
