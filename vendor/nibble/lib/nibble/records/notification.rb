module Nibble
  module Records
    class Notification < Nibble::ApplicationRecord
      scope :unread, -> { where(read_at: nil) }

      def self.notify(user_id, kind, subject: nil, **data)
        return if user_id.nil?

        notification = create!(user_id:, kind:, subject_type: subject&.class&.name, subject_id: subject&.id,
                               data: data.stringify_keys)
        deliver(notification)
        notification
      end

      def self.deliver(notification)
        user = Nibble::User.find_by(id: notification.user_id) or return
        return unless Nibble::UserPreferences.get(user, "notifications.email")

        Nibble::NotificationsMailer.notify(notification).deliver_later
      end
    end
  end
end
