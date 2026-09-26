module Nibble
  module Records
    class Redirect < Nibble::ApplicationRecord
      self.table_name = "redirects"

      STATUSES = [ 301, 302, 307, 308 ].freeze
      SOURCES = %w[manual auto import].freeze
      TARGET = %r{\A(?:/\S*|https?://\S+)\z}

      validates :from, presence: true, uniqueness: true, format: { with: %r{\A/\S*\z} }
      validates :to, presence: true, format: { with: TARGET }
      validates :status, inclusion: { in: STATUSES }
      validates :source, inclusion: { in: SOURCES }
      validate :no_loop

      before_save :follow_existing_target
      after_save :repoint_chains

      def self.lookup(*paths)
        table = Rails.cache.fetch([ "nibble/redirects", version ]) do
          rules = pluck(:id, :from, :to, :status)
          { "exact" => rules.reject { |rule| rule[1].end_with?("/*") }.to_h { |id, from, to, status| [ from, [ id, to, status ] ] },
            "wildcard" => rules.select { |rule| rule[1].end_with?("/*") }.sort_by { |rule| -rule[1].length } }
        end
        paths.uniq.each do |path|
          match = match(table, path)
          return match if match
        end
        nil
      end

      def self.match(table, path)
        if (id, to, status = table["exact"][path])
          return [ id, to, status ]
        end

        table["wildcard"].each do |id, from, to, status|
          prefix = from.delete_suffix("*")
          next unless path.start_with?(prefix) || path == prefix.chomp("/")

          rest = path.delete_prefix(prefix).delete_prefix(prefix.chomp("/"))
          return [ id, to.end_with?("/*") ? Nibble::Uris.normalize("#{to.delete_suffix('*')}#{rest}") : to, status ]
        end
        nil
      end
      private_class_method :match

      def self.version = pick(Arel.sql("COUNT(*)"), Arel.sql("MAX(updated_at)")).join("-")

      def self.hit!(id, now: Time.current) = where(id:).update_all([ "hits = hits + 1, last_hit_at = ?", now ])

      def self.record_move(from, to)
        return if from.blank? || to.blank? || from == to

        where(from: to).delete_all
        redirect = find_or_initialize_by(from:)
        redirect.update!(to:, status: 301, source: "auto")
      end

      private

      def resolved_target
        return to if from.to_s.end_with?("/*")

        self.class.where(from: to).where.not(id:).pick(:to) || to
      end

      def no_loop
        errors.add(:to, "creates a redirect loop") if from.present? && resolved_target == from
      end

      def follow_existing_target = self.to = resolved_target

      def repoint_chains = self.class.where(to: from).where.not(id:).update_all(to:, updated_at: Time.current)
    end
  end
end
