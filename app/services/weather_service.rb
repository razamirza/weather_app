# frozen_string_literal: true

require "net/http"
require "json"

# Weather interface: implementors must respond to #forecast(lat, lon) and return
# either a raw API hash (e.g. current, daily) or an error hash { error: "message" }.
class WeatherService
  include HttpClientSupport
  include ServiceLogging

  OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast"

  ERROR_UNAVAILABLE = :weather_unavailable
  ERROR_SSL = :ssl_error
  ERROR_NETWORK = :timeout_or_network

  def forecast(lat, lon)
    uri = URI(OPEN_METEO_URL)
    uri.query = URI.encode_www_form(
      latitude: lat,
      longitude: lon,
      current: "temperature_2m,weather_code",
      daily: "temperature_2m_max,temperature_2m_min",
      timezone: "auto"
    )
    res = http_get(uri)
    unless res.is_a?(Net::HTTPSuccess)
      log_event(:warn, ERROR_UNAVAILABLE, detail: "HTTP #{res.code}")
      return error_response("Weather service unavailable.", ERROR_UNAVAILABLE)
    end

    JSON.parse(res.body)
  rescue OpenSSL::SSL::SSLError => e
    log_event(:warn, ERROR_SSL, detail: e.message)
    error_response("Weather request failed (SSL). Set SKIP_SSL_VERIFY=1 in .env for local dev (see README).", ERROR_SSL)
  rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout, SocketError => e
    log_event(:warn, ERROR_NETWORK, detail: e.message)
    error_response("Could not fetch weather. Please try again.", ERROR_NETWORK)
  end

  private

  def error_response(message, code)
    { error: message, error_code: code }
  end
end
