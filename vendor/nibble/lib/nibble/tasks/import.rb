module Nibble
  module Tasks
    # Creates and updates entries by key. It only ever changes entries it created itself, found through
    # Records::ScheduledTaskEntry, so an entry made by hand is never updated or unpublished, even when its key matches.
    class Import
      def initialize(task, into, data)
        @task = task
        @into = into
        @data = data
        @collection = into["collection"]
        @counts = Hash.new(0)
        @errors = []
        @skipped = []
      end

      def call
        items = Mapping.render(@into["items"], "response" => @data)
        raise Error, "#{@into['items']} isn't a list in the response" unless items.is_a?(Array)

        seen = Set.new
        items.each_with_index do |item, index|
          values = Mapping.values(@into["map"], "response" => @data, "item" => item)
          key = values[@into["key"]].to_s.strip
          next @counts["skipped"] += 1 if key.empty? || !seen.add?(key)

          @counts[ActiveRecord::Base.transaction { upsert(key, values) }] += 1
        rescue Error => error
          @counts["failed"] += 1
          @errors << "item #{index}: #{error.message}"
        end
        # An empty feed is far likelier to be a fault at the other end than every item withdrawn at once.
        unpublish_missing(seen) if @into["unpublish_missing"] == true && seen.any?

        finish(items.size)
      end

      private

      def upsert(key, values)
        link = Records::ScheduledTaskEntry.find_by(handle: @task.handle, collection: @collection, key:)
        entry = link && Records::Entry.find_by(id: link.entry_id)
        return create(link, key, values) unless entry
        return "skipped" if entry.trashed?

        update(entry, link, values, key)
      end

      def create(link, key, values)
        entry = Records::Entry.new(collection: @collection, locale: Nibble.config.default_locale.code, blueprint: @into["blueprint"])
        entry = succeed!(Lifecycle.call(entry, :create, values, actor: Principal.system))
        succeed!(Lifecycle.call(entry.reload, :publish, {}, actor: Principal.system))
        if link
          link.update!(entry_id: entry.id, missing_since: nil)
        else
          Records::ScheduledTaskEntry.create!(handle: @task.handle, collection: @collection, key:, entry_id: entry.id)
        end
        "created"
      end

      # Republishes only what this task unpublished; an entry someone unpublished by hand stays unpublished.
      def update(entry, link, values, key)
        republish = link.missing_since.present? && entry.status == "unpublished"
        link.update!(missing_since: nil) if link.missing_since
        changed = !Tasks.unchanged?(entry, values.except("slug")) || (values.key?("slug") && values["slug"].to_s != entry.slug.to_s)
        return "unchanged" unless changed || republish
        return skip_draft(key) if entry.draft

        live = entry.live?
        succeed!(Lifecycle.call(entry, :save, values, actor: Principal.system)) if changed
        succeed!(Lifecycle.call(entry.reload, :publish, {}, actor: Principal.system)) if live || republish
        republish ? "republished" : "updated"
      end

      def unpublish_missing(seen)
        Records::ScheduledTaskEntry.where(handle: @task.handle, collection: @collection, missing_since: nil).find_each do |link|
          next if seen.include?(link.key)

          entry = Records::Entry.find_by(id: link.entry_id)
          next unless entry&.live?
          next @counts[skip_draft(link.key)] += 1 if entry.draft

          ActiveRecord::Base.transaction do
            succeed!(Lifecycle.call(entry, :unpublish, {}, actor: Principal.system))
            link.update!(missing_since: Time.current)
          end
          @counts["unpublished"] += 1
        rescue Error => error
          @counts["failed"] += 1
          @errors << "#{link.key}: #{error.message}"
        end
      end

      # Saving or unpublishing a live entry folds its pending draft in, and publishing would then put an editor's
      # unfinished work live, so an entry with a draft waits until the editor publishes or discards it.
      def skip_draft(key)
        @skipped << "#{key}: has unpublished edits"
        "skipped"
      end

      def finish(total)
        details = @counts.merge("items" => total, "errors" => @errors.first(10), "skipped_reasons" => @skipped.first(10))
        counts = @counts.except("failed").map { |name, count| "#{count} #{name}" }.join(", ").presence || "nothing to do"
        return Runner::Outcome.new(status: "succeeded", message: counts, details:) if @errors.empty?

        Runner::Outcome.new(status: "failed", message: "#{@errors.size} of #{total} failed (#{@errors.first}); #{counts}", details:)
      end

      def succeed!(result)
        return result.record if result.ok?

        raise Error, Tasks.describe(result.errors)
      end
    end
  end
end
