require "test_helper"

class Nibble::Cp::AnalyticsPreviewTest < ActionDispatch::IntegrationTest
  def preview(card) = post("/cp/nibble/analytics/preview", as: :json, params: { card: })

  test "a card shows the tags its renderer will write, even while the card is paused" do
    sign_in_as users(:editor)
    preview("type" => "ga4", "measurement_id" => "G-ABC123", "enabled" => false)

    assert_response :success
    assert_includes response.parsed_body.dig("tags", "head").join, %(gtag('config',"G-ABC123"))
    assert_empty response.parsed_body["errors"]
  end

  test "a value in the wrong shape is explained as it's typed, and nothing is written for it" do
    sign_in_as users(:editor)
    preview("type" => "ga4", "measurement_id" => "UA-1234")

    assert_equal({ "measurement_id" => "That isn't a GA4 measurement ID; it looks like G-XXXXXXXXXX." }, response.parsed_body["errors"])
    assert_empty response.parsed_body.dig("tags", "head")
  end

  test "an empty card isn't scolded for what hasn't been typed yet" do
    sign_in_as users(:editor)
    preview("type" => "ga4")

    assert_empty response.parsed_body["errors"]
  end

  test "only people who may edit the Integrations global can preview, since it runs the renderers" do
    sign_in_as users(:author)
    preview("type" => "ga4", "measurement_id" => "G-ABC123")

    assert_response :forbidden
  end
end
