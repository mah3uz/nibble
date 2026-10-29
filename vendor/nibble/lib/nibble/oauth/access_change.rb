module Nibble
  module Oauth
    # Changes what a connected app may do. Whoever edits it, the owner's roles and the site's settings cap it.
    class AccessChange
      Refused = Class.new(StandardError) do
        attr_reader :field

        def initialize(field, message)
          @field = field
          super(message)
        end
      end

      APPROVALS = { "ask" => "Ask before live changes", "off" => "Make changes without asking" }.freeze

      def self.consent(grant) = Consent.new(grant.user, device: grant.via == "device" || grant.kind == "ci")

      def self.props(grant)
        consent = consent(grant)
        { name: grant.name, preset: grant.preset, areas: selection(grant), approval_mode: grant.approval_mode, asks_approval: grant.asks_approval?,
          via: grant.via, last_used_at: grant.last_used_at&.utc&.iso8601, last_used_ip: grant.last_used_ip, expires_at: grant.expires_at.utc.iso8601,
          options: { presets: consent.presets, areas: consent.areas, approvals_choosable: consent.approvals_choosable? } }
      end

      def self.selection(grant)
        AgentAccess.areas.each_with_object({}) do |area, chosen|
          columns = area.columns.select do |column|
            abilities = AgentAccess.abilities_for(area.key, column)
            abilities.any? && abilities.all? { |ability| grant.covers?(ability) }
          end
          chosen[area.key] = columns if columns.any?
        end
      end

      def initialize(grant, by:, ip: nil)
        @grant = grant
        @editor = by
        @ip = ip
      end

      def call(name: nil, preset: nil, areas: nil, approval_mode: nil)
        raise Refused.new(:preset, "this connection has ended") unless @grant.active?

        consent = self.class.consent(@grant)
        attrs = {}
        attrs[:name] = name.to_s.strip.first(100) unless name.nil?
        attrs.merge!(preset: preset.to_s, abilities: refusing(:preset) { consent.abilities(preset, areas) }) unless preset.nil?
        attrs[:approval_mode] = refusing(:approval_mode) { consent.approval_mode(approval_mode.to_s) } unless approval_mode.nil?

        before = snapshot
        raise Refused.new(:name, @grant.errors.full_messages.to_sentence) unless @grant.update(attrs)

        changes = snapshot.to_h { |key, value| [ key, [ before[key], value ] ] }.reject { |_, (from, to)| from == to }
        record(changes) if changes.any?
        changes
      end

      private

      def refusing(field)
        yield
      rescue Error => error
        raise Refused.new(field, error.message)
      end

      def snapshot = { "name" => @grant.name, "preset" => @grant.preset, "abilities" => @grant.abilities.to_a.sort, "approval_mode" => @grant.approval_mode }

      def record(changes)
        Records::AuditEntry.create!(action: "auth.app_access_changed", actor_type: "user", actor_id: @editor.id, subject_type: "grant",
          subject_id: @grant.id, changeset: changes.merge("owner" => @grant.user_id), ip: @ip, created_at: Time.current)
        return if @editor.id == @grant.user_id

        Records::Notification.notify(@grant.user_id, "apps.access_changed", title: @grant.name, comment: summary(changes))
      end

      def summary(changes)
        parts = []
        parts << "name #{changes['name'].join(' → ')}" if changes["name"]
        if changes["preset"]
          parts << "access #{changes['preset'].map { |preset| Consent::PRESETS.dig(preset, 0) }.join(' → ')}"
        elsif changes["abilities"]
          parts << "the areas it may use"
        end
        parts << "approvals #{changes['approval_mode'].map { |mode| APPROVALS[mode] }.join(' → ')}" if changes["approval_mode"]
        "#{@editor.name.presence || @editor.email_address} changed #{parts.to_sentence}."
      end
    end
  end
end
