module Nibble
  module Forms
    class Person
      attr_reader :email

      def initialize(email) = @email = email.to_s.strip.downcase

      def present? = email.include?("@")

      def submissions
        return Records::FormSubmission.none unless present?

        text = Arel::Nodes::NamedFunction.new("CAST", [ Records::FormSubmission.arel_table[:data].as("TEXT") ])
        like = Arel::Nodes::NamedFunction.new("LOWER", [ text ]).matches("%#{Records::FormSubmission.sanitize_sql_like(email)}%", nil, true)
        Records::FormSubmission.where(like).order(:created_at, :id).select { |submission| mentions?(submission.data) }
      end

      def digest = Records::FormSubmission.hash_ip(email)

      def self.csv(submissions)
        CSV.generate do |csv|
          csv << %w[form id created_at status field value]
          submissions.each do |submission|
            rows(submission).each { |field, value| csv << [ submission.form, submission.id, submission.created_at.utc.iso8601, submission.status, field, value ] }
          end
        end
      end

      def self.rows(submission)
        submission.data.map { |field, value| [ field, flatten(value) ] }
      end

      def self.flatten(value)
        case value
        when Array then value.map { |item| flatten(item) }.join(", ")
        when Hash then value["filename"] || value.values.map { |item| flatten(item) }.join(", ")
        else value.to_s
        end
      end

      def self.json(submissions)
        submissions.map do |submission|
          { form: submission.form, id: submission.id, created_at: submission.created_at.utc.iso8601, status: submission.status,
            values: submission.data }
        end
      end

      private

      def mentions?(value)
        case value
        when String then value.downcase.match?(/(?<![\w.+-])#{Regexp.escape(email)}(?![\w-])/)
        when Array then value.any? { |item| mentions?(item) }
        when Hash then value.values.any? { |item| mentions?(item) }
        else false
        end
      end
    end
  end
end
