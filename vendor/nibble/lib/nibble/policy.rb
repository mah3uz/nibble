module Nibble
  # What a principal may do to a record. Lifecycle asks before every action, whichever screen, API or job called it.
  module Policy
    ENTRY = { "create" => "create", "save" => "edit", "submit" => "edit", "revert" => "edit", "discard_draft" => "edit",
              "move" => "edit", "assign_terms" => "edit", "publish" => "publish", "unpublish" => "publish",
              "trash" => "delete", "restore" => "delete" }.freeze
    TERM = { "create" => "create", "save" => "edit", "revert" => "edit", "trash" => "delete", "restore" => "delete" }.freeze
    ASSET = { "create" => "upload", "save" => "edit", "replace" => "edit", "trash" => "delete", "restore" => "delete" }.freeze
    SET = { "save" => "edit", "revert" => "edit" }.freeze

    module_function

    def ability(record, action)
      action = action.to_s
      return "assets.edit" if action == "replace_asset"

      case record.record_type
      when "entry"
        return "workflow.approve.#{record.collection}" if %w[approve reject].include?(action)

        ENTRY[action]&.then { |suffix| "entries.#{record.collection}.#{suffix}" }
      when "term" then TERM[action]&.then { |suffix| "terms.#{record.taxonomy}.#{suffix}" }
      when "global" then SET[action]&.then { |suffix| "globals.#{record.handle}.#{suffix}" }
      when "navigation" then SET[action]&.then { |suffix| "navigation.#{record.handle}.#{suffix}" }
      when "asset" then ASSET[action]&.then { |suffix| "assets.#{suffix}" }
      end
    end

    PUBLIC = /\A(globals|navigation)\.[^.]+\.view\z/

    def denial(principal, record, action)
      return if principal.system?

      ability = ability(record, action) or return "Only Nibble itself can #{action.to_s.humanize(capitalize: false)} this."
      return "#{record.collection.humanize} is written in files. Change it there and deploy." if file_backed?(record)

      "You don't have permission to do that." unless can?(principal, ability, record)
    end

    def can?(principal, ability, record = nil)
      return true if principal.system?
      return false unless ability.to_s.match?(PUBLIC) || Access.can?(principal.user, ability, record)

      grant = principal.grant or return true
      grant.active? && grant.covers?(ability) && AgentAccess.allows?(ability) && Access.can?(principal.user, "apps.connect")
    end

    def file_backed?(record)
      record.record_type == "entry" && Nibble.schema.collection(record.collection)&.[]("files").present?
    end
  end
end
