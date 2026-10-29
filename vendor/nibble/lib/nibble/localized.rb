module Nibble
  module Localized
    module_function

    def resolve(value, locale = nil)
      return value unless value.is_a?(Hash)

      default = Nibble.config.default_locale.code
      value[(locale || default).to_s] || value[default] || value.values.first
    end

    def i18n_locale(code)
      code = code.to_s
      code.present? && I18n.available_locales.map(&:to_s).include?(code) ? code.to_sym : I18n.locale
    end

    def problems(value, locales, label)
      return [] unless value.is_a?(Hash)

      (value.keys.map(&:to_s) - locales).map { |code| "#{label} has text for locale '#{code}', which the site doesn't have" }
    end
  end
end
