module Nibble
  module Cp
    class CommentsController < BaseController
      before_action :load_entry

      def index
        render json: { comments: thread }
      end

      def create
        body = params.require(:comment).permit(:body, :parent_id)
        mentioned = Nibble::Records::Comment.mentioned_users(body[:body]).to_a
        comment = Nibble::Records::Comment.create!(
          subject_type: @entry.class.name, subject_id: @entry.id, author_id: Nibble::Current.user.id,
          body: body[:body], parent_id: body[:parent_id].presence, mentions: mentioned.map(&:id)
        )
        notify(mentioned, comment)
        render json: { comments: thread }, status: :created
      end

      def destroy
        comment = comments.find(params[:id])
        return head :forbidden unless comment.author_id == Nibble::Current.user.id

        comment.destroy!
        render json: { comments: thread }
      end

      private

      def load_entry
        collection = Nibble.schema.collection(params[:handle]) or raise ActiveRecord::RecordNotFound
        authorize!("entries.#{collection.handle}.view")
        @entry = Nibble::Records::Entry.kept.where(collection: collection.handle).find(params[:entry_id])
      end

      def comments = Nibble::Records::Comment.where(subject_type: @entry.class.name, subject_id: @entry.id)

      def thread
        rows = comments.order(:created_at).to_a
        authors = Nibble::User.where(id: rows.map(&:author_id)).index_by(&:id)
        roots, replies = rows.partition { |row| row.parent_id.nil? }
        roots.map { |root| serialize(root, authors).merge("replies" => replies.select { |reply| reply.parent_id == root.id }.map { |reply| serialize(reply, authors) }) }
      end

      def serialize(comment, authors)
        { "id" => comment.id, "body" => comment.body, "at" => comment.created_at.utc.iso8601,
          "author" => authors[comment.author_id]&.name, "mine" => comment.author_id == Nibble::Current.user.id }
      end

      def notify(mentioned, comment)
        mentioned.each do |user|
          next if user.id == Nibble::Current.user.id

          Nibble::Records::Notification.notify(user.id, "comment.mentioned", subject: @entry, title: @entry.title,
                                               comment_id: comment.id, by: Nibble::Current.user.id)
        end
      end
    end
  end
end
