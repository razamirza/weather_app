Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "forecasts#index"
  get "forecasts", to: "forecasts#index", as: :forecasts
end
