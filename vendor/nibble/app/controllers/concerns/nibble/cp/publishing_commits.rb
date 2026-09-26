# Save / publish / schedule / unpublish buttons shared by the post and page editors (`commit` param).
module Nibble
  module Cp
    module PublishingCommits
      private

      def notice_for(record, commit)
        name = record.model_name.human
        { "publish" => "#{name} published.", "schedule" => "#{name} scheduled.", "unpublish" => "#{name} unpublished." }.fetch(commit, "#{name} saved.")
      end

      # A block field error's `path:` (BlocksValidator) becomes its own key ("blocks.0.title"), so the
      # publish form can point at the exact field; everything else keys by its plain attribute, as before.
      def error_messages(record)
        record.errors.group_by { |e| e.options[:path] ? "#{e.attribute}.#{e.options[:path]}" : e.attribute.to_s }
          .transform_values { |errors| errors.map(&:full_message).join(", ") }
      end
    end
  end
end
