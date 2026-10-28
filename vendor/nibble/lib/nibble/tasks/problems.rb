module Nibble
  module Tasks
    module Problems
      METHODS = %w[get post put patch delete].freeze
      CALL_KEYS = %w[use url path method headers body].freeze
      GLOBAL_KEYS = %w[global locale map].freeze
      COLLECTION_KEYS = %w[collection blueprint items key map unpublish_missing].freeze

      module_function

      def for(task, schema:)
        problems = schedule_problems(task)
        actions = ACTIONS.select { |key| task.item.data.key?(key) }
        return problems << "needs exactly one of fetch, request or handler" unless actions.one?

        case actions.first
        when "fetch"
          problems.concat(call_problems("fetch", task.fetch, schema, CALL_KEYS + %w[into]))
          problems.concat(into_problems(task.fetch["into"], schema))
        when "request" then problems.concat(call_problems("request", task.request, schema, CALL_KEYS))
        when "handler" then problems << "handler '#{task.handler}' isn't registered" unless Tasks.handlers.key?(task.handler)
        end
        problems
      end

      def schedule_problems(task)
        cron = task.cron
        cron.seconds == [ 0 ] ? [] : [ "schedule '#{task.schedule}' runs more often than once a minute, and tasks are checked once a minute" ]
      rescue Error => error
        [ error.message ]
      end

      def call_problems(name, spec, schema, allowed)
        problems = (spec.keys - allowed).map { |key| "#{name}.#{key} isn't a key a task reads (allowed: #{allowed.join(', ')})" }
        if spec["use"].present? == spec["url"].present?
          problems << "#{name} needs either `use` (an API connection) or `url`"
        elsif spec["use"].present?
          connection = Outbound::Connection.find(spec["use"], schema:)
          return problems << "#{name} uses the API connection '#{spec['use']}', which isn't in the schema" unless connection

          problems.concat(host_problems(name, connection.base_url))
        elsif !spec["url"].to_s.match?(%r{\Ahttps?://})
          problems << "#{name}.url must be an absolute http(s) URL"
        else
          problems.concat(host_problems(name, spec["url"]))
        end
        problems << "#{name}.method must be one of #{METHODS.join(', ')}" unless spec["method"].nil? || METHODS.include?(spec["method"].to_s)
        problems << "#{name}.headers must be a mapping" unless spec["headers"].nil? || spec["headers"].is_a?(Hash)
        problems
      end

      def host_problems(name, url)
        host = URI.parse(url.to_s).host.to_s.downcase
        return [] if host.empty? || host.include?("{") || Outbound::Guard.allowed_host?(host)

        [ "#{name} calls #{host}, which isn't in outbound.allowed_hosts" ]
      rescue URI::InvalidURIError
        []
      end

      def into_problems(into, schema)
        return [ "fetch.into must be a mapping naming a global or a collection" ] unless into.is_a?(Hash)
        return [ "fetch.into needs exactly one of global or collection" ] unless into.key?("global") ^ into.key?("collection")

        into.key?("global") ? global_problems(into, schema) : collection_problems(into, schema)
      end

      def global_problems(into, schema)
        problems = unknown_keys(into, GLOBAL_KEYS)
        item = schema.find(:globals, into["global"]) or return problems << "fetch.into.global '#{into['global']}' isn't in the schema"

        problems << "fetch.into.locale '#{into['locale']}' isn't configured" if into["locale"] && !Nibble.config.locale(into["locale"])
        inline = Schema::Item.new(kind: "blueprints", handle: item.handle, parent: item.key, path: item.path, layer: item.layer, data: item["blueprint"])
        problems.concat(map_problems(into, Blueprint.new(inline, schema:).fields.handles, "global #{item.handle}"))
      end

      def collection_problems(into, schema)
        problems = unknown_keys(into, COLLECTION_KEYS)
        collection = schema.collection(into["collection"]) or return problems << "fetch.into.collection '#{into['collection']}' isn't in the schema"

        problems << "collection '#{collection.handle}' uses the review workflow, so a task can't publish into it" if collection["workflow"] == "review"
        handle = into["blueprint"] || Array(collection["blueprints"]).first
        blueprint = schema.blueprint(collection, handle) or return problems << "fetch.into.blueprint '#{handle}' isn't a blueprint of #{collection.handle}"

        fields = Blueprint.new(blueprint, schema:).fields.handles + %w[slug]
        problems << "fetch.into.items must name the list, such as \"{response.data}\"" unless into["items"].is_a?(String) && into["items"].present?
        problems << "fetch.into.key must be one of the mapped fields" unless into["key"].is_a?(String) && into["map"].to_h.key?(into["key"])
        problems << "fetch.into.unpublish_missing must be true or false" unless [ nil, true, false ].include?(into["unpublish_missing"])
        problems.concat(map_problems(into, fields, "#{collection.handle}/#{handle}"))
      end

      def map_problems(into, fields, target)
        return [ "fetch.into.map must map fields to values" ] unless into["map"].is_a?(Hash) && into["map"].any?

        (into["map"].keys.map(&:to_s) - fields).map { |field| "fetch.into.map names '#{field}', which #{target} doesn't have" }
      end

      def unknown_keys(into, allowed) = (into.keys - allowed).map { |key| "fetch.into.#{key} isn't a key a task reads (allowed: #{allowed.join(', ')})" }
    end
  end
end
