# frozen_string_literal: true

# Load OHM locale overrides last so they win over upstream strings.
Rails.application.config.i18n.load_path += Rails.root.glob("config/locales/overrides/*.yml")
