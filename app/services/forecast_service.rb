# frozen_string_literal: true

# Composes geocoding and weather APIs; caches results by zip or lat/lon.
# Inject geocoder: and weather: for testing or alternate providers.
# Cache TTL is set in config (config.x.forecast_cache_ttl); production can use ENV FORECAST_CACHE_TTL_MINUTES.
class ForecastService
  include ServiceLogging

  def self.fetch(address, geocoder: nil, weather: nil)
    new(address, geocoder: geocoder, weather: weather).fetch
  end

  def initialize(address, geocoder: nil, weather: nil)
    @address = address.to_s.strip
    @geocoder = geocoder || GeocodingService.new
    @weather = weather || WeatherService.new
  end

  def fetch
    location = @geocoder.geocode(@address)
    return location if location.is_a?(Hash) && location.key?(:error)

    cache_key = cache_key_for(location)
    cached = Rails.cache.read(cache_key)
    if cached
      log_event(:info, :cache_hit, cache_key: cache_key)
      cached.merge(from_cache: true, cache_key: cache_key)
    else
      log_event(:info, :cache_miss, cache_key: cache_key)
      raw = @weather.forecast(location[:lat], location[:lon])
      return raw if raw.is_a?(Hash) && raw.key?(:error)

      result = build_result(location, raw, from_cache: false)
      Rails.cache.write(cache_key, result.merge(from_cache: false), expires_in: cache_ttl)
      result
    end
  end

  private

  def cache_ttl
    Rails.application.config.x.forecast_cache_ttl || 30.minutes
  end

  def cache_key_for(location)
    zip = location[:postcode].presence
    zip = zip.gsub(/\s+/, "") if zip
    if zip.present?
      "forecast/zip/#{zip.downcase}"
    else
      "forecast/ll/#{location[:lat].round(2)}/#{location[:lon].round(2)}"
    end
  end

  def build_result(location, raw, from_cache: false)
    current = raw["current"] || {}
    daily = raw["daily"] || {}
    daily_max = daily["temperature_2m_max"]&.first
    daily_min = daily["temperature_2m_min"]&.first

    {
      address: location[:display_name],
      lat: location[:lat],
      lon: location[:lon],
      current_temp: current["temperature_2m"],
      weather_code: current["weather_code"],
      high: daily_max,
      low: daily_min,
      from_cache: from_cache
    }
  end
end
