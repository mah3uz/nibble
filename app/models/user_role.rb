class UserRole < ApplicationRecord
  belongs_to :user
  belongs_to :role

  before_destroy :an_administrator_remains

  private

  def an_administrator_remains
    return if destroyed_by_association
    return unless role.superuser? && UserRole.joins(:role).where(roles: { superuser: true }).where.not(id: id).none?

    errors.add(:base, "The only administrator's role can't be removed")
    throw :abort
  end
end
