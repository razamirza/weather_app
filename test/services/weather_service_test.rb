# frozen_string_literal: true

require "test_helper"
require "net/http"

class WeatherServiceTest < ActiveSupport::TestCase
  setup do
    @service = WeatherService.new
  end

  test "returns error when HTTP is not success" do
    stub_http_response(fake_http_response(503, "Service Unavailable")) do
      result = @service.forecast(41.88, -87.63)
      assert result.key?(:error)
      assert_equal "Weather service unavailable.", result[:error]
      assert_equal :weather_unavailable, result[:error_code]
    end
  end

  test "returns parsed JSON on success" do
    body = {
      "current" => { "temperature_2m" => 5.0, "weather_code" => 0 },
      "daily" => {
        "temperature_2m_max" => [8.0],
        "temperature_2m_min" => [2.0]
      }
    }.to_json
    stub_http_response(fake_http_response(200, "OK", body)) do
      result = @service.forecast(41.88, -87.63)
      assert_not result.key?(:error)
      assert_equal 5.0, result["current"]["temperature_2m"]
      assert_equal [8.0], result["daily"]["temperature_2m_max"]
    end
  end

  private

  def fake_http_response(code, message, body = "{}")
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
