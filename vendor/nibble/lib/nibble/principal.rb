module Nibble
  # Who a change is made by: a person, possibly through an app they connected, or Nibble itself (jobs, imports, tasks).
  class Principal < Data.define(:user, :grant)
    def self.for(actor)
      case actor
      when Principal then actor
      when Nibble::User then new(user: actor, grant: nil)
      else raise ArgumentError, "an actor is required: a user, a Nibble::Principal, or Nibble::Principal.system"
      end
    end

    def self.system = @system ||= new(user: nil, grant: nil)

    def system? = user.nil?

    def event_actor = system? ? nil : { "type" => "user", "id" => user.id }
  end
end
