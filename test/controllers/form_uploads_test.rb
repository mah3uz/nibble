require "test_helper"

class FormUploadsTest < ActionDispatch::IntegrationTest
  include NibbleRecordsHelper
  include ActiveJob::TestHelper

  PDF = "%PDF-1.4\n1 0 obj << >> endobj\ntrailer << >>\n%%EOF\n".freeze
  EXE = ("MZ\x90\x00".b + ("\x00".b * 60)).freeze

  setup do
    @rate_limit_store = Nibble::Forms::Submit.rate_limit_store
    Nibble::Forms::Submit.rate_limit_store = -> { ActiveSupport::Cache::MemoryStore.new }
  end

  teardown { Nibble::Forms::Submit.rate_limit_store = @rate_limit_store }

  def upload(name, content, type = "application/octet-stream")
    file = Tempfile.new([ "upload", File.extname(name) ]).tap { |io| io.binmode.write(content) && io.rewind }
    Rack::Test::UploadedFile.new(file.path, type, true, original_filename: name)
  end

  def apply(*files, **extra) = post("/forms/application", params: { name: "Ada", cv: files, **extra }, headers: { "Accept" => "application/json" })
  def submission = Nibble::Records::FormSubmission.sole

  test "an accepted file is kept on the submission, with only safe metadata in its data" do
    apply upload("../../My CV.pdf", PDF, "text/html")

    assert_response :created
    file = submission.data["cv"].sole
    assert_equal [ "My CV.pdf", "application/pdf", PDF.bytesize ], file.values_at("filename", "content_type", "size"),
      "the path is stripped and the type comes from the content, not the browser"
    assert_equal [ file["id"] ], submission.files.blobs.ids
  end

  test "a file whose content doesn't match its extension is refused, and nothing is uploaded" do
    [ upload("cv.pdf", EXE), upload("cv.pdf", "just some bytes"), upload("cv.png", PDF),
      upload("data.csv", "a,b\n\x00\x01".b), upload("empty.pdf", "") ].each do |file|
      assert_no_difference -> { ActiveStorage::Blob.count } do
        apply file
        assert_response :unprocessable_entity, file.original_filename
      end
    end
    assert_empty Nibble::Records::FormSubmission.all
  end

  test "types the form doesn't allow, dangerous types, too many files and oversized files are refused" do
    apply upload("cv.txt", "hello")
    assert_response :unprocessable_entity
    apply upload("cv.html", "<script>alert(1)</script>")
    assert_response :unprocessable_entity
    apply upload("a.pdf", PDF), upload("b.pdf", PDF), upload("c.pdf", PDF)
    assert_match "not have more than 2", response.parsed_body.dig("errors", "cv").join
    apply upload("big.pdf", PDF + ("x" * 1.megabyte))
    assert_match "larger than 1 MB", response.parsed_body.dig("errors", "cv").join
    assert_equal 0, ActiveStorage::Blob.count
  end

  test "a request larger than the form could ever accept, or of unknown size, is refused before it is read" do
    post "/forms/application", params: { name: "x" * 4.megabytes }, headers: { "Accept" => "application/json" }
    assert_response :content_too_large
    post "/forms/contact", params: { name: "x" * 2.megabytes }
    assert_response :content_too_large, "a form without file fields accepts 1 MB at most"

    status, = FormRequestLimitMiddleware.new(->(_env) { [ 200, {}, [] ] })
      .call(Rack::MockRequest.env_for("/forms/application", method: "POST", input: "name=x").except("CONTENT_LENGTH"))
    assert_equal 411, status
  end

  test "a submitted value can't point at a file that is already stored" do
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(PDF), filename: "secret.pdf")
    post "/forms/application", params: { cv: [ { id: blob.id, filename: "secret.pdf" } ] }, as: :json

    assert_response :unprocessable_entity
    assert_empty ActiveStorage::Attachment.where(blob:)
  end

  test "spam never reaches storage" do
    apply upload("cv.pdf", PDF), _nibble_hp: "bot"
    assert_response :created
    assert_equal [ "spam", 0 ], [ submission.status, ActiveStorage::Blob.count ]
  end

  test "only people who can see submissions get a short-lived download link, which always downloads" do
    apply upload("cv.pdf", PDF)
    path = "/admin/forms/application/submissions/#{submission.id}/files/#{submission.files.blobs.sole.id}"

    get path
    assert_redirected_to "/admin/session/new"
    sign_in_as users(:author)
    get path
    assert_response :forbidden

    sign_in_as users(:editor)
    get path
    link = URI(response.location).request_uri
    assert_match %r{\A/rails/active_storage/disk/}, link

    get link
    assert_response :ok
    assert_equal PDF, response.body
    assert_match(/\Aattachment;/, response.headers["Content-Disposition"], "the file downloads instead of rendering in the admin's browser")
    travel 6.minutes do
      get link
      assert_response :not_found, "the link has expired"
    end
  end

  test "deleting a submission deletes its files" do
    apply upload("cv.pdf", PDF)
    perform_enqueued_jobs { submission.destroy! }
    assert_equal 0, ActiveStorage::Blob.count
  end
end
