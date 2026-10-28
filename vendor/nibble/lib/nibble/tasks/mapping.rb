module Nibble
  module Tasks
    # Only {response.…} and {item.…}: what an API sends back is never read for {secret.…}, so it can't pull one into content.
    module Mapping
      PATTERN = /\{(response|item)((?:\.[A-Za-z0-9_-]+)*)\}/
      WHOLE = /\A#{PATTERN}\z/
      MISSING = Object.new.freeze

      module_function

      def values(map, scope)
        map.to_h.each_with_object({}) do |(field, template), found|
          value = render(template, scope)
          found[field.to_s] = value unless value.equal?(MISSING)
        end
      end

      def render(template, scope)
        return template unless template.is_a?(String)

        if (match = template.match(WHOLE))
          return lookup(scope, match[1], match[2])
        end

        missing = false
        rendered = template.gsub(PATTERN) do
          value = lookup(scope, Regexp.last_match(1), Regexp.last_match(2))
          missing ||= value.equal?(MISSING)
          value.to_s
        end
        missing ? MISSING : rendered
      end

      def lookup(scope, root, path)
        return MISSING unless scope.key?(root)

        path.delete_prefix(".").split(".").reduce(scope[root]) do |current, key|
          case current
          when Hash then current.key?(key) ? current[key] : (return MISSING)
          when Array then key.match?(/\A\d+\z/) && key.to_i < current.size ? current[key.to_i] : (return MISSING)
          else return MISSING
          end
        end
      end
    end
  end
end
