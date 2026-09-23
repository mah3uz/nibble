Rails.application.configure do
  # Uploads go to S3 once a bucket is named, and to storage/ on the server until then, so a site can run
  # before it has object storage. The volume in config/deploy.yml is what keeps them (see config/storage.yml).
  config.active_storage.service = ENV["AWS_BUCKET_NAME"].present? ? :amazon : :local

  config.cache_store = :solid_cache_store
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  config.action_mailer.default_url_options = { host: URI(ENV.fetch("SITE_URL", "https://example.com")).host, protocol: "https" }

  # Outgoing mail (password resets, user invitations). Add smtp credentials with
  # bin/rails credentials:edit
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: ENV.fetch("SMTP_ADDRESS", "smtp.postmarkapp.com"),
    port: ENV.fetch("SMTP_PORT", 587).to_i,
    user_name: Rails.application.credentials.dig(:smtp, :username),
    password: Rails.application.credentials.dig(:smtp, :password),
    authentication: :plain,
    enable_starttls: true
  }
end
