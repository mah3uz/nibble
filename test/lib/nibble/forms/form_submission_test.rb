require "test_helper"

class Nibble::Forms::FormSubmissionTest < ActiveSupport::TestCase
  Submission = Nibble::Records::FormSubmission

  def submission(deliveries)
    Submission.create!(form: "contact", data: { "email" => "a@example.test" }, deliveries:)
  end

  test "a submission's status follows its deliveries, so the CP shows what still needs attention" do
    record = submission([ { "key" => "api.0", "status" => "pending" }, { "key" => "api.1", "status" => "pending" } ])

    record.update_delivery!("api.0", status: "delivered")
    assert_equal "received", record.status, "one delivery is still pending"
    record.update_delivery!("api.1", status: "failed", error: "timeout")
    assert_equal "failed", record.status
    record.update_delivery!("api.1", status: "rejected")
    assert_equal "rejected", record.status, "a rejection by the remote system outranks a retryable failure"
    record.update_delivery!("api.1", status: "delivered")
    assert_equal [ "delivered", "delivered" ], [ record.status, record.delivery("api.1")["status"] ]
  end

  test "spam stays spam whatever its deliveries do, and IPs are stored only as a keyed hash" do
    record = Submission.create!(form: "contact", status: "spam", deliveries: [ { "key" => "api.0", "status" => "pending" } ])
    record.update_delivery!("api.0", status: "delivered")

    assert_equal "spam", record.status
    hashed = Submission.hash_ip("203.0.113.9")
    assert_equal 32, hashed.size
    assert_not_includes hashed, "203"
    assert_equal hashed, Submission.hash_ip("203.0.113.9")
  end
end
