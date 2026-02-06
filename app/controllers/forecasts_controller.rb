# frozen_string_literal: true

class ForecastsController < ApplicationController
  def index
    @address = params[:address].to_s.strip
    raw = @address.present? ? ForecastService.fetch(@address) : nil
    @result = raw.is_a?(Hash) ? raw.with_indifferent_access : nil
  end
end
