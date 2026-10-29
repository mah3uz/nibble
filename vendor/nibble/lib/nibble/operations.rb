module Nibble
  # Everything an app or the CLI can do to a site, declared once. The management API and the MCP server are both
  # generated from this list, and every operation checks Policy through the principal it is given.
  module Operations
    Operation = Data.define(:name, :title, :description, :input, :read_only, :destructive, :needs, :handler, :consequential, :held) do
      def initialize(consequential: false, held: nil, **rest) = super(consequential:, held:, **rest)

      def consequential?(input) = consequential.respond_to?(:call) ? consequential.call(input) : consequential

      # What an approval keeps in place of the input it was asked with; the digest stays the asked input's.
      def held_input(input, caller) = held ? held.call(input, caller) : input

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
        if approval.present? || (caller.principal.grant&.asks_approval? && operation.consequential?(input))
          next approval!(operation, input, caller, approval, key) { |held| rehearse { operation.handler.call(held, caller) } }
        end

        operation.handler.call(input, caller)
      end
    end

    def approval!(operation, input, caller, approval_id, key)
      grant = caller.principal.grant
      if approval_id.present?
        approval = grant&.approvals&.find_by(public_id: approval_id.to_s)
        unless approval&.for?(operation.name, input)
          raise Failure.new("approval_mismatch", "that approval was given to another connection or for a different request", status: :conflict,
            hint: "An approval is for exactly the request it was given for. Send this request without approval to ask for it.")
        end

        return answer(approval, caller, asked: true)
      end
      if key.present? && (approval = grant.approvals.find_by(idempotency_key: key))
        raise Failure.new("idempotency_conflict", "this idempotency_key was used for a different request", status: :conflict) unless approval.for?(operation.name, input)

        return answer(approval, caller)
      end

      digest = Approval.digest(operation.name, input)
      in_flight = lambda do
        grant.approvals.where(operation: operation.name, digest:, status: Approval::IN_FLIGHT).where("expires_at > ?", Time.current)
          .order(id: :desc).find { |approval| !approval.interrupted? }
      end
      approval = in_flight.call
      unless approval
        held = operation.held_input(input, caller)
        preview = yield(held)
        approval = Approval.transaction do
          in_flight.call || grant.approvals.create!(operation: operation.name, input: held, digest:, preview:, idempotency_key: key.presence)
        end
        if approval.previously_new_record?
          Records::Notification.notify(grant.user_id, "apps.approval_requested", title: "#{grant.name}: #{operation.title}", approval: approval.public_id)
        end
      end
      answer(approval, caller)
    end

    def answer(approval, caller, asked: false)
      name = approval.grant.user.name
      case approval.state
      when "done" then approval.result
      when "failed"
        error = approval.failure.to_h
        raise Failure.new(error["code"], error["message"], hint: error["hint"], details: error["details"], status: error["status"] || :unprocessable_content)
      when "denied"
        raise Failure.new("approval_denied", "#{name} declined this request", status: :conflict, details: { "approval" => approval.public_id },
          hint: "Nothing was changed. Don't ask again unless #{name} wants you to.")
      when "expired"
        raise Failure.new("approval_expired", "nobody approved this request in time", status: :conflict, details: { "approval" => approval.public_id },
          hint: "Nothing was changed. Send the request again without approval to ask again.")
      else
        url = "#{caller.site}/cp/approvals/#{approval.public_id}"
        code, message = asked ? [ "approval_pending", "#{name} hasn't approved this yet" ] : [ "approval_required", "#{name} has to approve this before it happens" ]
        raise Failure.new(code, message, status: :conflict,
          details: { "approval" => approval.public_id, "approval_url" => url, "expires_at" => approval.expires_at.utc.iso8601 },
          hint: "Ask #{name} to open #{url}. Nothing more to send: when #{name} approves, Nibble makes the change. get_approval says how it went.")
      end
    end

    def carry_out(approval, site:, ip:)
      claimed = Approval.where(id: approval.id, status: "pending").where("expires_at > ?", Time.current)
        .update_all(status: "approved", decided_at: Time.current, updated_at: Time.current) == 1
      return approval.reload unless claimed

      approval.reload
      grant = approval.grant
      caller = Caller.new(principal: Principal.new(user: grant.user, grant:), site:, ip:)
      begin
        approval.update!(status: "done", result: carried_out(approval, caller))
      rescue Failure => failure
        approval.update!(status: "failed", error: failure.to_h.merge("status" => Rack::Utils.status_code(failure.status)))
      rescue StandardError => error
        Rails.error.report(error)
        approval.update!(status: "failed", error: { "code" => "error", "message" => "something went wrong making this change", "status" => 500 })
      end
      if approval.status == "failed"
        Records::Notification.notify(grant.user_id, "apps.approval_failed", title: "#{grant.name}: #{find(approval.operation)&.title}",
          approval: approval.public_id)
      end
      approval
    end

    def carried_out(approval, caller)
      grant = caller.principal.grant
      unless grant.active? && AgentAccess.enabled?
        raise Failure.new("connection_ended", "the app was disconnected, or its connection ended, before this was approved", status: :forbidden)
      end

      operation = find(approval.operation)
      unless operation && possible?(caller.principal, operation.needs)
        raise Failure.new("forbidden", "this connection can no longer #{operation&.title&.downcase || 'do that'}", status: :forbidden,
          hint: "The person's role, the app's access, or the site's Agent access settings changed since it was asked.")
      end

      operation.handler.call(check(operation, approval.input), caller)
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
      warnings = Thread.current[:nibble_warnings] = []
      outcome = nil
      ActiveRecord::Base.transaction(requires_new: true) do
        outcome = yield
        raise ActiveRecord::Rollback
      end
      outcome = outcome.except("id", "uuid", "cp_url", "preview_url", "url") if outcome["result"] == "created"
      outcome.merge("result" => "would be #{outcome['result']}", "dry_run" => true, "saved" => false, "warnings" => warnings.uniq)
    ensure
      Thread.current[:nibble_warnings] = nil
      Thread.current[:nibble_dispatch_scheduled] = scheduled
    end

    def remembered(caller, key, operation, input)
      grant = caller.principal.grant
      return yield if key.blank? || grant.nil?

      digest = Digest::SHA256.hexdigest([ operation.name, input ].to_json)
      Records::IdempotencyKey.where(created_at: ..Records::IdempotencyKey::KEEP.ago).delete_all
      begin
        reserved = Records::IdempotencyKey.create!(grant_id: grant.id, key:, operation: operation.name, digest:, response: { "pending" => true },
          created_at: Time.current)
      rescue ActiveRecord::RecordNotUnique
        earlier = Records::IdempotencyKey.find_by!(grant_id: grant.id, key:)
        raise Failure.new("idempotency_conflict", "this idempotency_key was used for a different request", status: :conflict) if earlier.digest != digest
        raise Failure.new("in_progress", "the first request with this idempotency_key is still running", status: :conflict, hint: "Try again in a moment.") if earlier.response["pending"]

        return earlier.response.merge("replayed" => true)
      end

      begin
        yield.tap { |response| reserved.update!(response:) }
      rescue StandardError
        reserved.destroy
        raise
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
