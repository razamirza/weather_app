# frozen_string_literal: true

require "net/http"

# Shared HTTP client logic: SSL verification toggle and request options.
# Include in services that call external APIs with Net::HTTP.
module HttpClientSupport
  HTTP_OPEN_TIMEOUT = 5
  HTTP_READ_TIMEOUT = 5

  private

  def ssl_verify_disabled?
    Rails.env.development? && ENV["SKIP_SSL_VERIFY"] == "1"
  end

  def http_options_for(uri)
    opts = {
      open_timeout: HTTP_OPEN_TIMEOUT,
      read_timeout: HTTP_READ_TIMEOUT,
      use_ssl: uri.scheme == "https"
    }
    opts[:verify_mode] = OpenSSL::SSL::VERIFY_NONE if ssl_verify_disabled?
    opts
  end

  def http_get(uri, request = nil)
    req = request || Net::HTTP::Get.new(uri)
    Net::HTTP.start(uri.hostname, uri.port, http_options_for(uri)) { |http| http.request(req) }
  end
end
