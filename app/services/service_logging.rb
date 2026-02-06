# frozen_string_literal: true

# Shared log format: timestamp, level, service=, event=, key=value (same as ForecastService cache logs).
# Include in services and call log_event(level, event, **key_value_pairs).
module ServiceLogging
  private

  def log_event(level, event, **attrs)
    parts = [
      "[#{Time.current.utc.iso8601}]",
      level.to_s.upcase,
      "service=#{service_name}",
      "event=#{event}"
    ]
    attrs.each { |k, v| parts << "#{k}=#{v}" }
    Rails.logger.public_send(level) { parts.join(" ") }
  end

  def service_name
    self.class.name
  end
end
