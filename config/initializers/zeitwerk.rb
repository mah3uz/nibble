# app/models/blueprints holds PostBlueprint, PageBlueprint, SettingsBlueprint directly (not
# Blueprints::PostBlueprint) — they sit alongside Blueprint itself, not under a namespace.
Rails.autoloaders.main.collapse("#{Rails.root}/app/models/blueprints")
