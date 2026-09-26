module Nibble
  class UserRole < Nibble::ApplicationRecord
    self.table_name = "nibble_user_roles"

    belongs_to :user
    belongs_to :role

    before_destroy :an_administrator_remains

    private

    def an_administrator_remains
      return if destroyed_by_association
      return unless role.superuser? && Nibble::UserRole.joins(:role).where(role: { superuser: true }).where.not(id: id).none?

      errors.add(:base, "The only administrator's role can't be removed")
      throw :abort
    end
  end
end
