module Nibble
  # Everything an app or the CLI can do to a site, declared once. The management API and the MCP server are both
  # generated from this list, and every operation checks Policy through the principal it is given.
  module Operations
    VERSION = "2026-09-27"

    Operation = Data.define(:name, :title, :description, :input, :read_only, :destructive, :needs, :handler, :consequential) do
      def initialize(consequential: false, **rest) = super(consequential:, **rest)

      def consequential?(input) = consequential.respond_to?(:call) ? consequential.call(input) : consequential

      def annotations = { "readOnlyHint" => read_only, "destructiveHint" => destructive, "idempotentHint" => read_only, "openWorldHint" => false }

      def catalogue = { "name" => name, "title" => title, "description" => description, "input" => input, "annotations" => annotations }
    end

    Caller = Data.define(:principal, :site, :ip)

    class Failure < StandardError
      attr_reader :code, :hint, :status, :details

      def initialize(code, message, hint: nil, status: :unprocessable_content, details: nil)
        @code = code
        @hint = hint
        @status = status
        @details = details
        super(message)
      end

      def to_h = { "code" => code, "message" => message, "hint" => hint, "details" => details }.compact
    end

    WRITE_INPUT = {
      "dry_run" => { "type" => "boolean", "description" => "Check and preview the change without saving anything." },
      "idempotency_key" => { "type" => "string", "maxLength" => 100,
                             "description" => "Any unique string. Sending the same one again returns the first result instead of repeating the change." },
      "approval" => { "type" => "string", "description" => "The approval id from an approval_required answer, once the person has approved it." }
    }.freeze
    GROUPS = %w[Site Entries Terms Sets Assets Forms].freeze

    module_function

    def registry = @registry ||= GROUPS.flat_map { |group| const_get(group).operations }.index_by(&:name)

    def reset! = @registry = nil

    def all = registry.values

    def find(name) = registry[name.to_s]

    def available(principal) = all.select { |operation| possible?(principal, operation.needs) }

    def possible?(principal, needs)
      return true if needs.nil?

      kind, column = needs
      AgentAccess.areas.any? do |area|
        area.key.split(".").first == kind && area.columns.include?(column) &&
          AgentAccess.concrete_abilities(area.key, column).any? { |ability| Policy.can?(principal, ability) }
      end
    end

    def call(name, input, caller:)
      operation = find(name) or raise Failure.new("unknown_operation", "there is no operation called #{name}", status: :not_found,
        hint: "operations lists what this connection can do")
      raise Failure.new("forbidden", "this connection can't #{operation.title.downcase}", status: :forbidden) unless possible?(caller.principal, operation.needs)

      input = check(operation, input.to_h.deep_stringify_keys)
      return operation.handler.call(input, caller) if operation.read_only

      key = input.delete("idempotency_key")
      dry = input.delete("dry_run") == true
      approval = input.delete("approval")
      remembered(caller, key, operation, input) do
        next rehearse { operation.handler.call(input, caller) } if dry

        approved!(operation, input, caller, approval) { rehearse { operation.handler.call(input, caller) } }
        operation.handler.call(input, caller)
      end
    end

    def approved!(operation, input, caller, approval_id)
      grant = caller.principal.grant
      return unless grant&.kind == "app" && operation.consequential?(input)

      if approval_id.present?
        approval = Approval.find_by(public_id: approval_id.to_s)
        return approval.update!(status: "used") if approval&.usable_for?(grant, operation.name, input)

        raise Failure.new("approval_not_valid", "that approval isn't approved, has expired, or was given for a different request", status: :conflict,
          hint: "An approval works once, for exactly the request it was given for. Send the request without approval to ask again.")
      end

      digest = Approval.digest(operation.name, input)
      approval = grant.approvals.where(status: "pending", digest:).where("expires_at > ?", Time.current).first
      unless approval
        approval = grant.approvals.create!(operation: operation.name, input:, digest:, preview: yield)
        Records::Notification.notify(grant.user_id, "apps.approval_requested", title: "#{grant.name}: #{operation.title}",
          approval: approval.public_id)
      end
      url = "#{caller.site}/cp/approvals/#{approval.public_id}"
      raise Failure.new("approval_required", "#{grant.user.name} has to approve this before it happens", status: :conflict,
        details: { "approval" => approval.public_id, "approval_url" => url, "expires_at" => approval.expires_at.utc.iso8601 },
        hint: "Ask the person to open #{url} and approve it, then send the same request again with approval: \"#{approval.public_id}\".")
    end

    def check(operation, input)
      schema = operation.input
      unknown = input.keys - schema["properties"].keys
      raise Failure.new("invalid_input", "unknown #{'argument'.pluralize(unknown.size)}: #{unknown.join(', ')}", hint: "Arguments: #{schema['properties'].keys.join(', ')}") if unknown.any?

      missing = Array(schema["required"]).select { |key| input[key].nil? }
      raise Failure.new("invalid_input", "missing #{missing.join(', ')}", hint: "Required: #{Array(schema['required']).join(', ')}") if missing.any?

      input.to_h { |key, value| [ key, coerce(key, value, schema["properties"][key]) ] }
    end

    def coerce(key, value, property)
      types = Array(property["type"])
      value = value.to_i if types == [ "integer" ] && value.is_a?(String) && value.match?(/\A-?\d+\z/)
      value = value == "true" if types == [ "boolean" ] && %w[true false].include?(value)
      valid = types.empty? || types.any? { |type| matches?(type, value) }
      raise Failure.new("invalid_input", "#{key} must be #{types.join(' or ')}") unless valid
      raise Failure.new("invalid_input", "#{key} must be one of #{property['enum'].join(', ')}") if property["enum"] && !property["enum"].include?(value)

      value
    end

    def matches?(type, value)
      case type
      when "string" then value.is_a?(String)
      when "integer" then value.is_a?(Integer)
      when "boolean" then value == true || value == false
      when "object" then value.is_a?(Hash)
      when "array" then value.is_a?(Array)
      else true
      end
    end

    def rehearse
      scheduled = Thread.current[:nibble_dispatch_scheduled]
      outcome = nil
      ActiveRecord::Base.transaction(requires_new: true) do
        outcome = yield
        raise ActiveRecord::Rollback
      end
      outcome = outcome.except("id", "uuid", "cp_url", "url") if outcome["result"] == "created"
      outcome.merge("result" => "would be #{outcome['result']}", "dry_run" => true, "saved" => false)
    ensure
      Thread.current[:nibble_dispatch_scheduled] = scheduled
    end

    def remembered(caller, key, operation, input)
      grant = caller.principal.grant
      return yield if key.blank? || grant.nil?

      digest = Digest::SHA256.hexdigest([ operation.name, input ].to_json)
      Records::IdempotencyKey.where(created_at: ..Records::IdempotencyKey::KEEP.ago).delete_all
      if (earlier = Records::IdempotencyKey.find_by(grant_id: grant.id, key:))
        raise Failure.new("idempotency_conflict", "this idempotency_key was used for a different request", status: :conflict) if earlier.digest != digest

        return earlier.response.merge("replayed" => true)
      end

      yield.tap do |response|
        Records::IdempotencyKey.create!(grant_id: grant.id, key:, operation: operation.name, digest:, response:, created_at: Time.current)
      end
    end

    def lifecycle!(record, action, attrs, caller)
      result = Lifecycle.call(record, action, attrs, actor: caller.principal)
      return result.record if result.ok?

      if result.forbidden?
        raise Failure.new("forbidden", result.errors["base"].to_a.first || "you can't do that", status: :forbidden,
          hint: "The person's role, the app's access, or the site's Agent access settings don't allow it. A person can do it in the Control Plane.")
      end
      if result.conflict?
        raise Failure.new("lock_conflict", "someone saved this after you read it", status: :conflict, details: { "lock_version" => record.reload.lock_version },
          hint: "Read it again, reapply your change to the current data, and send the new lock_version.")
      end
      if result.needs_confirmation?
        raise Failure.new("in_use", "other content links to this", status: :conflict,
          details: { "referrers" => result.referrers.map { |relation| { "type" => relation.source_type, "id" => relation.source_id } } },
          hint: "Remove the links first, or ask a person to trash it in the Control Plane.")
      end

      raise Failure.new("invalid", result.errors.values.flatten.first.to_s, details: { "errors" => result.errors }, hint: "Fix the fields in details.errors and try again.")
    end

    def page_input(extra = {})
      { "page" => { "type" => "integer", "minimum" => 1, "description" => "Page number, from 1" },
        "per_page" => { "type" => "integer", "minimum" => 1, "maximum" => Query::Spec::MAX_PER_PAGE, "description" => "Up to #{Query::Spec::MAX_PER_PAGE}; 20 if left out" } }.merge(extra)
    end

    def schema(properties, required = [], write: false)
      { "type" => "object", "properties" => write ? properties.merge(WRITE_INPUT) : properties, "required" => required.presence,
        "additionalProperties" => false }.compact
    end

    def locale!(code)
      code = code.presence || Nibble.config.default_locale.code
      Nibble.config.locale(code) or raise Failure.new("invalid_input", "#{code} isn't a locale of this site",
        hint: "Locales: #{Nibble.config.locales.map(&:code).join(', ')}")
      code
    end

    def require!(principal, ability, record = nil)
      return if Policy.can?(principal, ability, record)

      raise Failure.new("forbidden", "this connection can't do that (#{ability})", status: :forbidden,
        hint: "The person's role, the app's access, or the site's Agent access settings don't allow it.")
    end

    def not_found!(what)
      raise Failure.new("not_found", "no #{what}", status: :not_found, hint: "describe_site and the list_ operations show what exists.")
    end
  end
end
