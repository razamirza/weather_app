# Weather Forecast

A small Ruby on Rails app that shows the current weather (and high/low) for any address. Geocoding and weather use free APIs; Geocoding and weather use free APIs (Nominatim, Open-Meteo).

## What it does

- **Address in** – Type a street, city, or zip; submit to get a forecast.
- **Forecast** – Current temperature plus daily high and low (from [Open-Meteo](https://open-meteo.com/)).
- **Caching** – Results are cached by area (zip or lat/lon); TTL is configurable (default 30 minutes). Development uses an in-memory store; production uses Solid Cache. A “Served from cache” message appears when the result is from cache.
---

## How to run it

**Prerequisites:** Ruby 3.3.x and Bundler. The repo has a `.ruby-version` file (3.3.8); with [rbenv](https://github.com/rbenv/rbenv) run `rbenv install` in the project folder to install that Ruby. No Node.js or Yarn are required (the app uses import maps and Propshaft).

1. Clone and go into the project:
   ```bash
   git clone git@github.com:razamirza/weather_app.git
   cd weather_app
   ```

2. Install dependencies:
   ```bash
   bundle install
   ```

3. Set up the cache:
   - Copy `config/database.yml.example` to `config/database.yml` if you need to change anything.
   - Run: `bin/rails db:setup` (creates the cache DB used by Solid Cache in production; in development the app uses an in-memory store).

4. Start the server:
   ```bash
   bin/rails server
   ```

5. Open **http://localhost:3000** in your browser, enter an address, and click “Get forecast”.

### Running tests

Run the test suite with:

```bash
bin/rails test
```

Tests include unit tests for `ForecastService` (with stubbed geocoding and weather clients) and request tests for `ForecastsController`.


**Nominatim (geocoding):** We use [OpenStreetMap Nominatim](https://nominatim.openstreetmap.org/) for address lookup. Please respect the [Nominatim usage policy](https://operations.osmfoundation.org/policies/nominatim/): maximum 1 request per second, and cache results. This app caches forecast results (including geocoding) for 30 minutes by area. There is no in-app rate limiting; we rely on that cache to reduce calls. If you expect high or burst traffic, consider adding throttling (see comments in `GeocodingService`).

## Architecture

**Architectural note:** There is no application database for local data. The app only calls external APIs (geocoding, weather) and caches results (in-memory in development, Solid Cache in production). The service layer (`ForecastService`) handles API calls and cache; no ActiveRecord models are used for app data.

The application is built lean: we don’t store any local data except the cache. All forecast data comes from external APIs (Nominatim for geocoding, Open-Meteo for weather). The service talks to those APIs and to the configured cache store—not to an application database. So there is no ActiveRecord model layer for app data; the “model” of the system is API + cache.

### File structure

```
Weather/
├── app/
│   ├── controllers/
│   │   ├── application_controller.rb   # Base controller
│   │   └── forecasts_controller.rb     # Form + address param; calls ForecastService; sets @result
│   ├── services/
│   │   ├── http_client_support.rb       # Shared HTTP/SSL logic for API clients
│   │   ├── service_logging.rb          # Shared log format (timestamp, level, service, event)
│   │   ├── geocoding_service.rb        # Nominatim client; geocode(address) → location or error
│   │   ├── weather_service.rb           # Open-Meteo client; forecast(lat, lon) → raw or error
│   │   └── forecast_service.rb         # Composes geocoder + weather; cache by zip/area (TTL from config)
│   ├── views/
│   │   ├── layouts/application.html.erb
│   │   └── forecasts/index.html.erb    # Address form, forecast result + cache indicator
│   ├── helpers/, assets/, javascript/  # application_helper, stylesheets (forecasts.css), importmap
│   └── models/                         # Empty; no app models (data from API + cache)
├── config/
│   ├── routes.rb                       # root + GET forecasts
│   ├── cable.yml                       # Action Cable (async/test/async)
│   ├── database.yml.example            # Primary + cache (production: one SQLite file)
│   ├── cache.yml                       # Solid Cache config
│   ├── environments/                   # development, test, production
│   └── ...                             # Boot, puma, importmap, locales, initializers, etc.
├── db/
│   ├── schema.rb                       # Empty (no application tables)
│   ├── cache_schema.rb                 # Solid Cache table definition
│   ├── cache_migrate/                  # Migration that creates solid_cache_entries
│   └── seeds.rb                        # Unused
├── test/
│   ├── controllers/forecasts_controller_test.rb  # Request tests (stubbed ForecastService)
│   ├── services/
│   │   ├── forecast_service_test.rb    # Unit tests (stubbed geocoder + weather)
│   │   ├── geocoding_service_test.rb  # Unit tests (stubbed HTTP)
│   │   └── weather_service_test.rb    # Unit tests (stubbed HTTP)
│   └── test_helper.rb
├── Gemfile                             # Rails, sqlite3, solid_cache, turbo, stimulus, tooling
├── .ruby-version                       # 3.3.8
└── README.md
```

---
