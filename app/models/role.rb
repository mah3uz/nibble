class Role < ApplicationRecord
  DEFAULTS = [
    { handle: "admin", title: "Administrator", superuser: true, abilities: [] },
    { handle: "editor", title: "Editor", abilities: %w[
      entries.* terms.* globals.* navigation.* assets.* forms.*
      redirects.manage trash.view search.rebuild utilities.view workflow.approve.*
    ] },
    { handle: "author", title: "Author", abilities: %w[
      entries.*.view entries.*.create entries.*.edit_own terms.*.view
      assets.view assets.upload
    ] },
    { handle: "contributor", title: "Contributor", abilities: %w[
      entries.*.view entries.*.create entries.*.edit_own terms.*.view assets.view
    ] },
    { handle: "viewer", title: "Viewer", abilities: %w[entries.*.view terms.*.view assets.view] }
  ].freeze

  has_many :user_roles, dependent: :delete_all
  has_many :users, through: :user_roles

  normalizes :handle, with: ->(handle) { handle.to_s.strip.downcase }

  validates :handle, presence: true, uniqueness: true, format: { with: /\A[a-z0-9_-]+\z/ }
  validates :title, presence: true
  validate :abilities_are_grantable
  validate :a_superuser_role_remains, on: :update
  before_destroy :a_superuser_role_remains_on_destroy

  before_validation { self.handle = title.to_s.parameterize(separator: "_") if handle.blank? }

  def self.seed_defaults!
    DEFAULTS.each do |attributes|
      find_or_create_by!(handle: attributes[:handle]) { |role| role.assign_attributes(attributes) }
    end
  end

  def grants = superuser? ? %w[*] : abilities

  private

  def abilities_are_grantable
    return if superuser?

    unknown = Array(abilities).select { |ability| ability.to_s.split(".").first == "*" }
    errors.add(:abilities, "can't include '*': full access is the toggle above") if unknown.any?
  end

  def last_superuser? = Role.where(superuser: true).where.not(id: id).none?

  def a_superuser_role_remains
    return unless superuser_changed?(from: true) && last_superuser?

    errors.add(:superuser, "can't be turned off: this is the only role with full access")
  end

  def a_superuser_role_remains_on_destroy
    return unless superuser? && last_superuser?

    errors.add(:base, "The only role with full access can't be deleted")
    throw :abort
  end
end
