module Nibble
  module Access
    OWNABLE = { "edit" => "edit_own", "delete" => "delete_own" }.freeze

    class << self
      def abilities(user) = user ? user.abilities : []

      def can?(user, ability, record = nil)
        return false unless user

        ability = ability.to_s
        return true if matches?(abilities(user), ability)

        own = own_ability(ability) or return false
        matches?(abilities(user), own) && owns?(user, record)
      end

      def any?(user, abilities) = Array(abilities).any? { |ability| can?(user, ability) }

      def matches?(patterns, ability)
        parts = ability.split(".")
        patterns.any? do |pattern|
          segments = pattern.split(".")
          trailing = segments.last == "*"
          next false unless trailing ? segments.size <= parts.size : segments.size == parts.size

          segments.each_with_index.all? { |segment, index| segment == "*" || segment == parts[index] }
        end
      end

      private

      def own_ability(ability)
        parts = ability.split(".")
        suffix = OWNABLE[parts.last] or return nil

        [ *parts[0..-2], suffix ].join(".")
      end

      def owns?(user, record)
        return false unless record.respond_to?(:author_id) || record.respond_to?(:created_by_id)

        [ record.try(:author_id), record.try(:created_by_id) ].compact.include?(user.id)
      end
    end
  end
end
