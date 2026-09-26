module Nibble
  module Cp
    class DirectUploadsController < ActiveStorage::DirectUploadsController
      include Nibble::Authentication

      before_action { head(:forbidden) unless Nibble::Access.can?(Nibble::Current.user, "assets.upload") }

      def create
        blob = params.expect(blob: [ :filename, :byte_size ])
        message = Nibble::Assets::Upload.refusal(blob[:filename], blob[:byte_size])
        return render(json: { error: message }, status: :unprocessable_entity) if message

        super
      end

      private

      def request_authentication = head(:unauthorized)
    end
  end
end
