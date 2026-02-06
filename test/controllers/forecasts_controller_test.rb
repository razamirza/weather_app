# frozen_string_literal: true

require "test_helper"

class ForecastsControllerTest < ActionDispatch::IntegrationTest
  test "GET / renders index" do
    get root_url
    assert_response :success
    assert_select "h1", "Weather forecast"
    assert_select "form[action=?][method=get]", forecasts_path
  end

  test "GET /forecasts with address shows result when service returns success" do
    stub_result = {
      address: "Chicago, IL, USA",
      current_temp: 5.0,
      high: 8.0,
      low: 2.0,
      from_cache: false
    }
    stub_fetch(stub_result) do
      get forecasts_url, params: { address: "Chicago" }
    end
    assert_response :success
    assert_select "input[name=address][value='Chicago']"
    assert_select ".forecasts-result"
    assert_match "5", response.body
  end

  test "GET /forecasts with address shows error when service returns error" do
    stub_fetch({ error: "Address not found." }) do
      get forecasts_url, params: { address: "nowhere" }
    end
    assert_response :success
    assert_select ".forecasts-error", "Address not found."
  end

  test "GET /forecasts with blank address renders form without error" do
    get forecasts_url, params: { address: "   " }
    assert_response :success
    assert_select "h1", "Weather forecast"
  end

  private

  def stub_fetch(return_value)
    original = ForecastService.method(:fetch)
    ForecastService.define_singleton_method(:fetch) { |*_args| return_value }
    yield
  ensure
    ForecastService.define_singleton_method(:fetch, original)
  end
end
