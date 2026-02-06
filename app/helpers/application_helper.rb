module ApplicationHelper
  # Human-readable forecast cache TTL from config (e.g. "30 min", "1 hr", "2 days").
  def forecast_cache_ttl_display
    ttl = Rails.application.config.x.forecast_cache_ttl || 30.minutes
    total_seconds = ttl.is_a?(ActiveSupport::Duration) ? ttl.to_i : ttl.to_i
    if total_seconds >= 86400
      n = total_seconds / 86400
      "#{n} #{n == 1 ? 'day' : 'days'}"
    elsif total_seconds >= 3600
      n = total_seconds / 3600
      "#{n} #{n == 1 ? 'hr' : 'hrs'}"
    else
      n = total_seconds / 60
      "#{n} min"
    end
  end
end
