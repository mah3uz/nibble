require "aws-sdk-s3"

# A complete, self-contained daily backup of the primary database: VACUUM INTO gives a compacted,
# consistent copy in one step (no torn reads, no WAL/-shm files to worry about), gzipped and kept
# in two places — the last 7 days on local disk (storage/backups, the same persistent volume the
# databases live on) for a fast local restore, and uploaded to S3 for everything else (that bucket
# already has its own 30-day lifecycle policy, so nothing to prune there). Independent of whatever
# continuous replication may or may not be running. Cache/queue/cable databases are excluded on
# purpose: they're ephemeral, nothing worth backing up.
module DatabaseSnapshot
  mattr_accessor :s3_client
  mattr_writer :local_dir

  LOCAL_RETENTION = 7.days

  module_function

  def bucket = ENV["DB_SNAPSHOT_BUCKET"]
  def region = ENV.fetch("DB_SNAPSHOT_REGION", "ap-southeast-2")
  def local_dir = @@local_dir ||= Rails.root.join("storage", "backups")

  # Returns the local path it wrote to (also uploaded to S3 under the same date).
  def create!
    raise "DB_SNAPSHOT_BUCKET is not configured" if bucket.blank?

    FileUtils.mkdir_p(local_dir)
    date = Time.current.strftime("%Y-%m-%d")
    raw_path = local_dir.join("#{date}.sqlite3")
    gz_path = local_dir.join("#{date}.sqlite3.gz")

    ActiveRecord::Base.connection.execute("VACUUM INTO '#{raw_path}'")
    gzip(raw_path, gz_path)
    File.delete(raw_path)

    key = "cms_db_snapshots/#{Rails.env}/#{date}.sqlite3.gz"
    File.open(gz_path, "rb") { |file| client.put_object(bucket:, key:, body: file) }

    prune_local!
    gz_path
  end

  # Removes local copies older than LOCAL_RETENTION — S3 keeps its own (longer) history.
  def prune_local!
    Dir.glob(local_dir.join("*.sqlite3.gz")).each do |path|
      File.delete(path) if File.mtime(path) < LOCAL_RETENTION.ago
    end
  end

  def client
    self.s3_client ||= Aws::S3::Client.new(
      region:,
      access_key_id: Rails.application.credentials.dig(:aws, :access_key_id),
      secret_access_key: Rails.application.credentials.dig(:aws, :secret_access_key)
    )
  end

  def gzip(source_path, destination_path)
    File.open(destination_path, "wb") do |file|
      writer = Zlib::GzipWriter.new(file)
      File.open(source_path, "rb") { |input| IO.copy_stream(input, writer) }
      writer.close
    end
  end
end
