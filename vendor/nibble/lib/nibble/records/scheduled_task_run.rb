module Nibble
  module Records
    class ScheduledTaskRun < Nibble::ApplicationRecord
      self.table_name = "scheduled_task_runs"

      STATUSES = %w[queued running succeeded failed skipped].freeze

      def self.record_type = "task_run"
      def self.polymorphic_name = record_type

      has_many :outbound_requests, as: :owner, dependent: :delete_all

      validates :status, inclusion: { in: STATUSES }

      scope :recent, -> { order(scheduled_for: :desc, id: :desc) }

      def record_type = self.class.record_type
      def finished? = finished_at.present?
    end
  end
end
