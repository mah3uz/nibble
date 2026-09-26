module Nibble
  module Environment
    Finding = Data.define(:source, :message, :level)

    DEPLOYED = %w[production].freeze

    class Unfit < Error; end

    class << self
      def findings(config: Nibble.config, env: Rails.env, credentials: Rails.application.credentials, root: Rails.root)
        return [] unless DEPLOYED.include?(env.to_s)

        [ *url(config), *secrets(credentials), *storage(credentials), *theme(config), *mail(credentials), *passkeys(config), *backups,
          *schedule(root.join("config/recurring.yml"), env.to_s) ]
      end

      def deployed?(env = Rails.env) = DEPLOYED.include?(env.to_s)

      # Serving with a bad setting publishes wrong links or drops uploads; a console with one can still fix it.
      def boot!(serving:, found: findings, out: $stderr)
        return if found.empty?

        errors, warnings = found.partition { |finding| finding.level == :error }
        warnings.each { |finding| out.puts "! #{finding.source}: #{finding.message}" }
        errors.each { |finding| out.puts "\u2717 #{finding.source}: #{finding.message}" }
        return if errors.empty?

        raise Unfit, "#{errors.size} setting(s) would break this site: #{errors.map(&:source).join(', ')}" if serving

        out.puts "! not serving, so carrying on — fix these before the next deploy"
      end

      private

      def error(source, message) = Finding.new(source:, message:, level: :error)
      def warning(source, message) = Finding.new(source:, message:, level: :warning)

      def url(config)
        value = config.url.to_s
        return [ error("SITE_URL", "is not set: every canonical, sitemap entry and mail link would be wrong") ] if value.blank?

        uri = begin
          URI.parse(value)
        rescue URI::InvalidURIError
          nil
        end
        return [ error("SITE_URL", "#{value.inspect} is not a valid URL") ] unless uri&.host
        return [ error("SITE_URL", "#{value.inspect} points at localhost, so published links would not resolve") ] if uri.host.match?(/\A(localhost|127\.|0\.0\.0\.0)/)
        return [ error("SITE_URL", "#{value.inspect} is not https") ] unless uri.scheme == "https"

        []
      end

      def secrets(credentials)
        return [] if credentials.secret_key_base.present?

        [ error("RAILS_MASTER_KEY", "is missing or wrong, so secret fields and signed cookies cannot be read") ]
      rescue StandardError
        [ error("RAILS_MASTER_KEY", "cannot decrypt the credentials for this environment") ]
      end

      def storage(credentials)
        return [] unless ActiveStorage::Blob.service.is_a?(ActiveStorage::Service::S3Service)

        missing = []
        missing << "AWS_BUCKET_NAME" if ENV["AWS_BUCKET_NAME"].blank?
        missing << "AWS_REGION" if ENV["AWS_REGION"].blank?
        missing << "aws.access_key_id" if credentials.dig(:aws, :access_key_id).blank?
        return [] if missing.empty?

        [ error("storage", "#{missing.join(', ')} unset, so uploads and image transforms will fail") ]
      rescue StandardError
        []
      end

      def theme(config)
        return [ warning("theme", "no theme is set, so only the control panel will serve") ] if config.theme.blank?
        return [ error("theme", "'#{config.theme}' has no folder in site/themes/ or vendor/nibble/themes/") ] unless config.theme_path&.directory?

        config.active_theme.compatible_with_core? ? [] : [ error("theme", "'#{config.theme}' asks for a different Nibble than this one") ]
      rescue Error => e
        [ error("theme", e.message) ]
      end

      def mail(credentials)
        return [] if credentials.dig(:smtp, :username).present?

        [ warning("mail", "no SMTP credentials, so password resets and notifications will not send") ]
      rescue StandardError
        []
      end

      def passkeys(config)
        return [] if Array(WebAuthn.configuration.allowed_origins).include?(config.url)

        [ warning("passkeys", "config/initializers/webauthn.rb doesn't allow #{config.url}, so passkeys can't sign in to the Control Plane") ]
      end

      # The site owns its schedule and may move or drop a job; only a job Nibble ships that is gone is worth saying.
      def schedule(path, env)
        missing = scheduled(Install.templates_path.join("config/recurring.yml"), "production") - scheduled(path, env)
        return [] if missing.empty?

        [ warning("schedule", "config/recurring.yml doesn't schedule #{missing.to_sentence}, so that work never runs") ]
      end

      def scheduled(path, env)
        return [] unless path.file?

        tasks = YAML.safe_load(ERB.new(path.read).result, aliases: true).to_h
        tasks.fetch(env, tasks).values.filter_map { |task| task["class"] if task.is_a?(Hash) }
      end

      def backups
        return [] if ENV["DB_SNAPSHOT_BUCKET"].present?

        [ warning("backups", "DB_SNAPSHOT_BUCKET unset, so nothing is copied offsite") ]
      end
    end
  end
end
