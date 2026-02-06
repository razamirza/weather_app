# frozen_string_literal: true

require "test_helper"
require "net/http"

class GeocodingServiceTest < ActiveSupport::TestCase
  setup do
    @service = GeocodingService.new
  end

  test "returns error for blank address" do
    result = @service.geocode("   ")
    assert result.key?(:error)
    assert_equal "Please enter an address.", result[:error]
    assert_equal :blank_address, result[:error_code]
  end

  test "returns error when HTTP is not success" do
    stub_http_response(fake_http_response(404, "Not Found")) do
      result = @service.geocode("Chicago")
      assert result.key?(:error)
      assert_equal "Geocoding service unavailable.", result[:error]
      assert_equal :geocoding_unavailable, result[:error_code]
    end
  end

  test "returns error when response body is empty array" do
    stub_http_response(fake_http_response(200, "OK", "[]")) do
      result = @service.geocode("nowhere")
      assert result.key?(:error)
      assert_equal "Address not found.", result[:error]
      assert_equal :address_not_found, result[:error_code]
    end
  end

  test "returns location hash on success" do
    body = [{
      "lat" => "41.88",
      "lon" => "-87.63",
      "display_name" => "Chicago, IL, USA",
      "address" => { "postcode" => "60601", "country_code" => "us" }
    }].to_json
    stub_http_response(fake_http_response(200, "OK", body)) do
      result = @service.geocode("Chicago")
      assert_not result.key?(:error)
      assert_equal 41.88, result[:lat]
      assert_equal(-87.63, result[:lon])
      assert_equal "Chicago, IL, USA", result[:display_name]
      assert_equal "60601", result[:postcode]
      assert_equal "US", result[:country_code]
    end
  end

  private

  def fake_http_response(code, message, body = "[]")
    klass = code == 200 ? Net::HTTPOK : Net::HTTPResponse
    res = klass.new("1.1", code, message)
    res.instance_variable_set(:@read, true)
    res.instance_variable_set(:@body, body)
    res.define_singleton_method(:body) { body }
    res
  end

  def stub_http_response(response)
    original = Net::HTTP.method(:start)
    Net::HTTP.define_singleton_method(:start) do |_host, _port, _opts, &block|
      mock_http = Object.new
      mock_http.define_singleton_method(:request) { |_req| response }
      block.call(mock_http)
      response
    end
    yield
  ensure
    Net::HTTP.define_singleton_method(:start, original)
  end
end
