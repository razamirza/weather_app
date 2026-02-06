# frozen_string_literal: true

require "net/http"
require "json"

# Geocoding interface: implementors must respond to #geocode(address) and return
# either a location hash (lat, lon, display_name, postcode, country_code) or
# an error hash { error: "message" }.
class GeocodingService
  include HttpClientSupport
  include ServiceLogging

  # Nominatim usage policy: 1 req/sec, cache results.
  # https://operations.osmfoundation.org/policies/nominatim/
  # This class does not rate-limit; respect the policy via caching (e.g. ForecastService
  # caches by location) and avoid burst traffic. Add throttling here or in the caller if needed.
  NOMINATIM_URL = "https://nominatim.openstreetmap.org/search"

  # Error codes for structured logging and optional handling.
  ERROR_BLANK = :blank_address
  ERROR_UNAVAILABLE = :geocoding_unavailable
  ERROR_NOT_FOUND = :address_not_found
  ERROR_SSL = :ssl_error
  ERROR_NETWORK = :timeout_or_network

  def geocode(address)
    if address.to_s.strip.blank?
      log_event(:warn, ERROR_BLANK, detail: "blank address")
      return error_response("Please enter an address.", ERROR_BLANK)
    end

    uri = URI(NOMINATIM_URL)
    uri.query = URI.encode_www_form(
      q: address.to_s.strip,
      format: "json",
      addressdetails: 1,
      limit: 1
    )
    req = Net::HTTP::Get.new(uri)
    req["User-Agent"] = "WeatherApp (local development)"
    # No rate limiting here; Nominatim allows ~1 req/sec—rely on ForecastService cache to reduce calls.
    res = http_get(uri, req)
    unless res.is_a?(Net::HTTPSuccess)
      log_event(:warn, ERROR_UNAVAILABLE, detail: "HTTP #{res.code}")
      return error_response("Geocoding service unavailable.", ERROR_UNAVAILABLE)
    end

    data = JSON.parse(res.body)
    if data.blank?
      log_event(:warn, ERROR_NOT_FOUND, detail: "no results")
      return error_response("Address not found.", ERROR_NOT_FOUND)
    end

    first = data.first
    addr = first["address"] || {}
    {
      lat: first["lat"].to_f,
      lon: first["lon"].to_f,
      display_name: first["display_name"],
      postcode: addr["postcode"]&.to_s&.strip,
      country_code: addr["country_code"]&.to_s&.upcase
    }
  rescue OpenSSL::SSL::SSLError => e
    log_event(:warn, ERROR_SSL, detail: e.message)
    msg = if ssl_verify_disabled?
      "Could not look up address (SSL error). Check your network or certificates."
    else
      "Geocoding failed due to SSL certificate verification. For local dev only, you can set SKIP_SSL_VERIFY=1 in .env and restart the server (see README)."
    end
    error_response(msg, ERROR_SSL)
  rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout, SocketError => e
    log_event(:warn, ERROR_NETWORK, detail: e.message)
    error_response("Could not look up address. Please try again.", ERROR_NETWORK)
  end

  private

  def error_response(message, code)
    { error: message, error_code: code }
  end
end
