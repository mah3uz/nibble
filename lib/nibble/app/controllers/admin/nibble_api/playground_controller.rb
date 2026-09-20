module Admin
  module NibbleApi
    class PlaygroundController < BaseController
      before_action { ::Nibble::Playground.register_demo_resolvers }

      def show
        blueprints = ::Nibble::Playground.blueprints
        key = blueprints.key?(params[:blueprint]) ? params[:blueprint] : blueprints.keys.first
        blueprint = ::Nibble::Blueprint.new(blueprints.fetch(key).last, schema: ::Nibble.schema)
        stored = {}
        render inertia: "admin/nibble/Playground", props: {
          blueprints: blueprints.map { |handle, (title, _)| { key: handle, title: } },
          current: key,
          blueprint: blueprint.to_publish_h,
          values: blueprint.fields.add_values(stored).pre_process.values,
          meta: blueprint.fields.add_values(stored).meta
        }
      end

      # POST JSON { values } → validation errors, or the stored and public shapes of a valid submission.
      def validate
        blueprint = ::Nibble::Blueprint.new(::Nibble::Playground.blueprints.fetch(params[:blueprint]).last, schema: ::Nibble.schema)
        result = ::Nibble::Validator.new(blueprint.fields).validate(params.fetch(:values, {}).to_unsafe_h)
        return render json: { errors: result.errors } unless result.valid?

        processed = blueprint.fields.add_values(params.fetch(:values, {}).to_unsafe_h).process.values
        render json: { errors: {}, processed:, augmented: blueprint.fields.add_values(processed).augment.values }
      end
    end
  end
end
