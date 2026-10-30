module Nibble
  module Forms
    class Person
      attr_reader :email

      def initialize(email) = @email = email.to_s.strip.downcase

      def present? = email.include?("@")

      def submissions = matching(Records::FormSubmission)
      def partials = matching(Records::FormPartial)

      def digest = Records::FormSubmission.hash_ip(email)

      def self.csv(submissions, partials = [])
        CSV.generate do |csv|
          csv << %w[form id created_at status field value]
          (submissions.to_a + partials.to_a).each do |submission|
            rows(submission).each { |field, value| csv << Cp::CsvCells.row([ submission.form, submission.id, submission.created_at.utc.iso8601, submission.status, field, value ]) }
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

      def self.json(submissions, partials = [])
        (submissions.to_a + partials.to_a).map do |submission|
          { form: submission.form, id: submission.id, created_at: submission.created_at.utc.iso8601, status: submission.status,
            values: submission.data, labels: (submission.labels if submission.respond_to?(:labels)).presence }.compact
        end
      end

      private

      def matching(model)
        return model.none unless present?

        text = Arel::Nodes::NamedFunction.new("CAST", [ model.arel_table[:data].as("TEXT") ])
        like = Arel::Nodes::NamedFunction.new("LOWER", [ text ]).matches("%#{model.sanitize_sql_like(email)}%", nil, true)
        scope = model.where(like).or(model.where.not(encrypted_data: nil))
        scope.order(:created_at, :id).select { |record| mentions?(record.data) }
      end

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
