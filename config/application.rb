require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Weather
  class Application < Rails::Application
    config.load_defaults 8.1

    # No application DB tables; data comes from APIs + Solid Cache only.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Forecast result cache TTL (override in config/environments or via ENV in production).
    config.x.forecast_cache_ttl = 30.minutes
  end
end
