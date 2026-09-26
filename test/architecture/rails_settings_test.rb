require "test_helper"

class RailsSettingsTest < ActiveSupport::TestCase
  APP_WIDE = /\.configure\b|Inflector\.inflections|content_security_policy|assets\.prefix|config\.(time_zone|active_storage|action_mailer|active_job|cache_store)\b/

  test "Nibble keeps no Rails settings of its own, so a site changes every one where any Rails app would" do
    assert_equal %w[routes], Nibble.core_root.join("config").children.map { |path| path.basename.to_s }
  end

  test "no Nibble code configures Rails or a gem for the whole app; what Nibble needs is written into the site's files" do
    offenders = %w[lib app].flat_map { |dir| Nibble.core_root.join(dir).glob("**/*.rb") }.select { |path| path.read.match?(APP_WIDE) }

    assert_empty offenders.map { |path| path.relative_path_from(Nibble.core_root).to_s },
      "a setting changed from inside Nibble is one a site can't see or change where Rails keeps it"
  end

  test "every setting Nibble writes into a site's files says it is Nibble's, so a site knows what its change affects" do
    %w[config/environments/production.rb config/recurring.yml config/initializers/inertia_rails.rb
       config/initializers/webauthn.rb config/initializers/content_security_policy.rb].each do |file|
      assert_match "# Nibble:", Nibble::Install.templates_path.join(file).read, file
    end
  end

  test "Rails' own paths stay Rails': the asset pipeline serves /assets, and /up is the site's route" do
    assert_equal "/assets", Rails.application.config.assets.prefix
    refute_match %r{"up"}, Nibble.core_root.join("config/routes/core.rb").read
    assert_match %r{get "up"}, Nibble::Install.templates_path.join("config/routes.rb").read
  end

  RAILS_NAMES = %w[ApplicationController ApplicationRecord ApplicationJob ApplicationMailer ApplicationHelper ApplicationCable
                   User Session Current Authentication SessionsController PasswordsController PasswordsMailer].freeze

  test "Nibble defines none of the names Rails generates, so a site can run Rails' own generators" do
    nibbles = RAILS_NAMES.filter_map(&:safe_constantize).select do |constant|
      Object.const_source_location(constant.name).first.to_s.start_with?(Nibble.core_root.to_s)
    end

    assert_empty nibbles.map(&:name), "a site's generator would overwrite or collide with these"
  end

  test "Nibble's identity tables are its own, so Rails' authentication generator can create users and sessions" do
    assert_equal %w[nibble_users nibble_sessions], [ Nibble::User.table_name, Nibble::Session.table_name ]
  end
end
