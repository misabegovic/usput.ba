# frozen_string_literal: true

# Localizable concern for controllers
# Handles locale detection and switching
#
# Priority order:
# 1. URL parameter (?locale=hr)
# 2. Session
# 3. Accept-Language header
# 4. Default locale
#
# Usage in controllers:
#   class ApplicationController < ActionController::Base
#     include Localizable
#   end
#
module Localizable
  extend ActiveSupport::Concern

  included do
    around_action :switch_locale
    helper_method :available_locales, :locale_name, :current_locale
  end

  private

  def switch_locale(&action)
    locale = extract_locale || I18n.default_locale
    I18n.with_locale(locale, &action)
  end

  def extract_locale
    # 1. URL parameter
    locale_from_param ||
      # 2. Session
      locale_from_session ||
      # 3. Accept-Language header
      locale_from_header ||
      # 4. Default
      nil
  end

  def locale_from_param
    locale = params[:locale]
    return nil unless locale

    if valid_locale?(locale)
      # Store in session for future requests
      session[:locale] = locale.to_sym
      locale.to_sym
    end
  end

  def locale_from_session
    locale = session[:locale]
    return nil unless locale

    valid_locale?(locale) ? locale.to_sym : nil
  end

  def locale_from_header
    return nil unless request.env["HTTP_ACCEPT_LANGUAGE"]

    # Parse Accept-Language header
    # Format: "en-US,en;q=0.9,hr;q=0.8"
    accepted = request.env["HTTP_ACCEPT_LANGUAGE"]
                      .split(",")
                      .map { |l| l.split(";").first.strip.split("-").first }

    accepted.each do |locale|
      return locale.to_sym if valid_locale?(locale)
    end

    nil
  end

  def valid_locale?(locale)
    I18n.available_locales.include?(locale.to_sym)
  end

  def current_locale
    I18n.locale
  end

  # Helper for views - returns list of available locales
  def available_locales
    I18n.available_locales
  end

  # Helper for views - returns human-readable locale name
  def locale_name(locale)
    LOCALE_NAMES[locale.to_sym] || locale.to_s.upcase
  end

  # Human-readable locale names
  LOCALE_NAMES = {
    en: "English",
    bs: "Bosanski",
    hr: "Hrvatski",
    de: "Deutsch",
    es: "Español",
    fr: "Français",
    it: "Italiano",
    pt: "Português",
    nl: "Nederlands",
    pl: "Polski",
    cs: "Čeština",
    sk: "Slovenčina",
    sl: "Slovenščina",
    sr: "Српски",
    tr: "Türkçe",
    ar: "العربية"
  }.freeze
end
