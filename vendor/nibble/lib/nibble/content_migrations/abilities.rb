module Nibble
  module ContentMigrations
    # Roles and app grants name schema handles, so a handle a migration renames or deletes takes its permissions with it.
    module Abilities
      PREFIXES = { "entry" => %w[entries workflow.approve], "navigation" => %w[navigation], "global" => %w[globals] }.freeze
      TYPES = { "collection" => "entry", "navigation" => "navigation", "global" => "global" }.freeze

      module_function

      def rewrite(abilities, type, from, to)
        Array(abilities).filter_map do |ability|
          prefix = PREFIXES.fetch(type).find { |start| ability == "#{start}.#{from}" || ability.start_with?("#{start}.#{from}.") }
          next ability unless prefix

          to && ability.sub("#{prefix}.#{from}", "#{prefix}.#{to}")
        end.uniq
      end

      # A nil `to` drops them. Returns how many roles and grants changed.
      def carry!(type, from, to)
        changed = [ Nibble::Role, Nibble::Grant ].sum do |model|
          model.find_each.count do |record|
            abilities = rewrite(record.abilities, type, from, to)
            abilities != record.abilities && record.update_columns(abilities:, updated_at: Time.current)
          end
        end
        carry_agent_access(from, to) if type == "entry"
        changed
      end

      def after(abilities, migrations)
        migrations.flat_map(&:operations).reduce(Array(abilities)) do |held, operation|
          name, args = operation.first
          verb, noun = name.to_s.split("_", 2)
          type = TYPES[noun] or next held
          args = args.to_h.stringify_keys
          case verb
          when "rename" then rewrite(held, type, args["from"], args["to"])
          when "delete" then rewrite(held, type, args[noun], nil)
          else held
          end
        end
      end

      # Each collection has its own row in the site's Agent access settings; left behind, the new handle falls back to
      # the defaults, which can allow what an administrator had turned off.
      def carry_agent_access(from, to)
        settings = AgentAccess.settings
        areas = settings["areas"].to_h
        return unless areas.key?("entries.#{from}")

        moved = areas.delete("entries.#{from}")
        areas["entries.#{to}"] = moved if to
        Records::Setting.write(AgentAccess::KEY, settings.merge("areas" => areas))
      end
    end
  end
end
