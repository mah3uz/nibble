Rails.application.config.to_prepare { Nibble::Files.watch! } if Rails.env.development?
