# frozen_string_literal: true

require "test_helper"

class ForecastServiceTest < ActiveSupport::TestCase
  setup do
    @location = {
      lat: 41.88,
      lon: -87.63,
      display_name: "Chicago, IL, USA",
      postcode: "60601",
      country_code: "US"
    }
    @weather_raw = {
      "current" => { "temperature_2m" => 5.0, "weather_code" => 0 },
      "daily" => {
        "temperature_2m_max" => [8.0],
        "temperature_2m_min" => [2.0]
      }
    }
  end

  test "returns error for blank address" do
    # Service strips address, so geocoder receives ""
    geocoder = double_geocoder("", { error: "Please enter an address.", error_code: :blank_address })
    result = ForecastService.fetch("  ", geocoder: geocoder, weather: double_weather(0, 0, {}))
    assert result.key?(:error)
    assert_equal "Please enter an address.", result[:error]
  end

  test "propagates geocoder error" do
    geocoder = double_geocoder("nowhere", { error: "Address not found.", error_code: :address_not_found })
    result = ForecastService.fetch("nowhere", geocoder: geocoder, weather: double_weather(0, 0, {}))
    assert result.key?(:error)
    assert_equal "Address not found.", result[:error]
  end

  test "propagates weather error" do
    geocoder = double_geocoder("Chicago", @location)
    weather = double_weather(41.88, -87.63, { error: "Weather service unavailable.", error_code: :weather_unavailable })
    result = ForecastService.fetch("Chicago", geocoder: geocoder, weather: weather)
    assert result.key?(:error)
    assert_equal "Weather service unavailable.", result[:error]
  end

  test "returns built result on success" do
    geocoder = double_geocoder("Chicago", @location)
    weather = double_weather(41.88, -87.63, @weather_raw)
    result = ForecastService.fetch("Chicago", geocoder: geocoder, weather: weather)
    assert_not result.key?(:error)
    assert_equal "Chicago, IL, USA", result[:address]
    assert_equal 5.0, result[:current_temp]
    assert_equal 8.0, result[:high]
    assert_equal 2.0, result[:low]
    assert_equal false, result[:from_cache]
  end

  test "returns cached result when cache hit" do
    # Test env uses null_store; temporarily use MemoryStore so cache is read
    cached = {
      address: "Chicago, IL, USA",
      lat: 41.88,
      lon: -87.63,
      current_temp: 4.0,
      weather_code: 0,
      high: 7.0,
      low: 1.0,
      from_cache: false
    }
    mem = ActiveSupport::Cache::MemoryStore.new
    mem.write("forecast/zip/60601", cached, expires_in: 30.minutes)
    geocoder = double_geocoder("Chicago", @location)
    weather = double_weather(41.88, -87.63, @weather_raw)
    old_cache = Rails.cache
    Rails.cache = mem
    result = ForecastService.fetch("Chicago", geocoder: geocoder, weather: weather)
    assert result[:from_cache], "expected from_cache to be true"
    assert result.key?(:cache_key)
    assert_equal "forecast/zip/60601", result[:cache_key]
  ensure
    Rails.cache = old_cache if defined?(old_cache)
  end

  private

  def double_geocoder(_address_arg, return_value)
    obj = Object.new
    obj.define_singleton_method(:geocode) { |_addr| return_value }
    obj
  end

  def double_weather(_lat, _lon, return_value)
    obj = Object.new
    obj.define_singleton_method(:forecast) { |_l, _lo| return_value }
    obj
  end
end
