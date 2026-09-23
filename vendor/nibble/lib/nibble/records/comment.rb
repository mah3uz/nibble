module Nibble
  module Records
    class Comment < ::ApplicationRecord
      MENTION = /@([a-z0-9._%+-]+(?:@[a-z0-9.-]+\.[a-z]{2,})?)/i

      belongs_to :parent, class_name: "Nibble::Records::Comment", optional: true
      has_many :replies, class_name: "Nibble::Records::Comment", foreign_key: :parent_id, dependent: :destroy,
               inverse_of: :parent

      validates :body, presence: true, length: { maximum: 5_000 }

      def author = ::User.find_by(id: author_id)

      def self.mentioned_users(body)
        handles = body.to_s.scan(MENTION).flatten.map(&:downcase).uniq
        return ::User.none if handles.empty?

        ::User.where("LOWER(email_address) IN (:handles) OR LOWER(REPLACE(name, ' ', '')) IN (:handles)", handles:)
      end
    end
  end
end
