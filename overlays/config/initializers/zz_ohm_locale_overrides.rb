# Load OHM locale overrides last so they win over upstream strings.
Rails.application.config.i18n.load_path += Dir[Rails.root.join("config/locales/overrides/*.yml")]
