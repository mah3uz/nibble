require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "a new user holds no role, so nobody gains rights by merely having an account" do
    user = User.create!(email_address: "new@example.com", name: "New", password: "Test-Password-1")
    assert_empty user.abilities
    assert_not user.admin?
  end

  test "the only administrator can't be deleted, so the control panel can't be locked" do
    assert_not users(:admin).destroy
    assert_includes users(:admin).errors[:base], "The only administrator can't be deleted"
  end

  test "email addresses are unique regardless of case, so one person can't hold two accounts" do
    duplicate = User.new(email_address: users(:admin).email_address.upcase, name: "Dup", password: "Test-Password-1")
    assert_not duplicate.valid?
  end

  test "a password shorter than the minimum is refused wherever it is set" do
    user = User.new(name: "Short", email_address: "short@example.com", password: "Aa1!" * 2)

    assert_not user.valid?
    assert_match(/too short/, user.errors[:password].to_sentence)
  end

  test "a long password still has to mix character kinds, so one word repeated is not enough" do
    problems = {
      "alllowercaseletters" => "an uppercase letter",
      "ALLUPPERCASELETTERS" => "a lowercase letter",
      "NoDigitsInThisOne!!" => "a number",
      "NoSymbolsInThisOne1" => "a symbol"
    }

    problems.each do |password, expected|
      user = User.new(name: "Weak", email_address: "weak@example.com", password:)

      assert_not user.valid?, "#{password} should be refused"
      assert_match expected, user.errors[:password].to_sentence
    end
  end

  test "a password meeting every rule is accepted" do
    user = User.new(name: "Fine", email_address: "fine@example.com", password: "Test-Password-1")

    assert_empty User.password_problems(user.password)
    assert user.valid?
  end

  test "the password Nibble generates for an invited user meets its own rules" do
    10.times { assert_empty User.password_problems(User.generate_password) }
  end

  test "an existing user can be edited without resupplying their password" do
    user = users(:admin)
    user.name = "Renamed"

    assert user.valid?, "validating an unchanged password would block every other edit"
  end
end
