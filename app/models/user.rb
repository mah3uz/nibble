class User < ApplicationRecord
  include TwoFactor

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :user_roles, dependent: :destroy
  has_many :user_credentials, dependent: :delete_all
  has_many :roles, through: :user_roles

  scope :administrators, -> { joins(:roles).where(roles: { superuser: true }).distinct }

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  INVITATION_EXPIRES_IN = 7.days
  MINIMUM_PASSWORD_LENGTH = 12
  PASSWORD_RULES = {
    "a lowercase letter" => /[a-z]/,
    "an uppercase letter" => /[A-Z]/,
    "a number" => /\d/,
    "a symbol" => /[^a-zA-Z0-9]/
  }.freeze

  # Set-password link for invited users. The password salt is part of the token, so the link
  # stops working once a password is set; the 15-minute reset token would be too short for an invite.
  generates_token_for :invitation, expires_in: INVITATION_EXPIRES_IN do
    password_salt.last(10)
  end

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: true
  validates :password, length: { minimum: MINIMUM_PASSWORD_LENGTH }, allow_nil: true
  validate :password_uses_enough_kinds_of_character
  before_destroy :an_administrator_remains, prepend: true

  # Invited users get one of these until they choose their own; it must satisfy the same rules.
  def self.generate_password = "#{SecureRandom.alphanumeric(24)}#{SecureRandom.random_number(10)}aA!"

  # Shared with the installer so a password is judged the same way wherever it is set.
  def self.password_problems(password)
    return [ "is too short (minimum is #{MINIMUM_PASSWORD_LENGTH} characters)" ] if password.to_s.length < MINIMUM_PASSWORD_LENGTH

    missing = PASSWORD_RULES.reject { |_, pattern| password.match?(pattern) }.keys
    missing.any? ? [ "needs #{missing.to_sentence}" ] : []
  end

  def admin? = roles.any?(&:superuser?)

  def abilities = roles.flat_map(&:grants).uniq

  private

  def password_uses_enough_kinds_of_character
    return if password.blank? || password.length < MINIMUM_PASSWORD_LENGTH

    self.class.password_problems(password).each { |problem| errors.add(:password, problem) }
  end

  def an_administrator_remains
    return unless admin? && User.administrators.where.not(id: id).none?

    errors.add(:base, "The only administrator can't be deleted")
    throw :abort
  end
end
