# Without this, `resources :media` singularizes to "medium" (Rails' default English inflection),
# so member routes generate `admin_medium_path` instead of `admin_media_path`.
ActiveSupport::Inflector.inflections(:en) { |inflect| inflect.uncountable "media" }
