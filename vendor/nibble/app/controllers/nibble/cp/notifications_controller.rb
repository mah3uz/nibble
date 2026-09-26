module Nibble
  module Cp
    class NotificationsController < BaseController
      def index
        render json: { notifications: rows, unread: scope.unread.count }
      end

      def update
        params[:id] ? scope.find(params[:id]).update!(read_at: Time.current) : scope.unread.update_all(read_at: Time.current)
        render json: { notifications: rows, unread: scope.unread.count }
      end

      def destroy
        params[:id] ? scope.find(params[:id]).destroy! : scope.delete_all
        render json: { notifications: rows, unread: scope.unread.count }
      end

      private

      def scope = Nibble::Records::Notification.where(user_id: Nibble::Current.user.id)

      def rows
        scope.order(created_at: :desc).limit(25).map do |item|
          { id: item.id, kind: item.kind, at: item.created_at.utc.iso8601, read: item.read_at.present?,
            title: item.data["title"], comment: item.data["comment"], url: url_for_subject(item) }
        end
      end

      def url_for_subject(item)
        return "/cp/forms/#{item.data['form']}/submissions/#{item.subject_id}" if item.kind == "form.submitted" && item.subject_id
        return "/cp/webhooks/#{item.subject_id}/edit" if item.kind == "webhook.disabled"
        return nil unless item.subject_type == "Nibble::Records::Entry"

        entry = Nibble::Records::Entry.find_by(id: item.subject_id) or return nil
        "/cp/collections/#{entry.collection}/entries/#{entry.id}/edit"
      end
    end
  end
end
