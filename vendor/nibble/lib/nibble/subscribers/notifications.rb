module Nibble
  module Subscribers
    module Notifications
      APPROVE_ABILITY = "workflow.approve"

      def self.call(name, payload)
        return unless name == "workflow.transitioned"

        record = subject(payload) or return
        actor_id = payload.dig("actor", "id")
        case payload["to"]
        when "in_review" then notify_approvers(record, actor_id, payload)
        when "approved", "draft" then notify_requester(record, actor_id, payload)
        end
      end

      def self.notify_approvers(record, actor_id, payload)
        approvers(record).each do |user|
          next if user.id == actor_id

          Records::Notification.notify(user.id, "workflow.review_requested", subject: record,
                                       title: record.try(:title), comment: payload["comment"], by: actor_id)
        end
      end

      def self.notify_requester(record, actor_id, payload)
        requester = last_submitter(record) or return
        return if requester == actor_id

        kind = payload["to"] == "approved" ? "workflow.approved" : "workflow.rejected"
        Records::Notification.notify(requester, kind, subject: record, title: record.try(:title),
                                     comment: payload["comment"], by: actor_id)
      end

      def self.approvers(record)
        ability = "#{APPROVE_ABILITY}.#{record.try(:collection) || record.try(:taxonomy)}"
        Nibble::User.all.select { |user| Access.can?(user, ability) }
      end

      def self.last_submitter(record)
        Records::WorkflowTransition.where(record:, to: "in_review").order(:created_at).last&.actor_id
      end

      def self.subject(payload)
        klass = payload["type"] == "entry" ? Records::Entry : (payload["type"] == "term" ? Records::Term : nil)
        klass&.find_by(id: payload["id"])
      end
    end
  end
end
