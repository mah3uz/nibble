# Restoring the database from a nightly backup

`DatabaseSnapshotJob` runs nightly (`config/recurring.yml`, 3am) and calls `DatabaseSnapshot.create!`
(`app/services/database_snapshot.rb`), which `VACUUM INTO`s the primary database into a compacted,
self-contained copy, gzips it, and keeps it in two places:

- **Locally**, on the server's persistent volume, under `storage/backups/` — the last 7 days.
  Fastest option if something goes wrong on the box itself (a bad migration, corrupted data).
- **In S3**, the bucket in `DB_SNAPSHOT_BUCKET` under `cms_db_snapshots/<environment>/`, which already
  has its own 30-day retention policy on that bucket. Use this if the server itself is lost.

Cache/queue/cable databases aren't included — they're ephemeral, nothing worth backing up.

## Restoring from the local copy (server still alive)

```sh
# On the server (e.g. via `kamal app exec -i bash`):
cd /rails
gunzip -k storage/backups/2026-09-14.sqlite3.gz -c > /tmp/restored.sqlite3
sqlite3 /tmp/restored.sqlite3 "SELECT COUNT(*) FROM entries;"   # sanity check before swapping in
```

Stop the app, replace `storage/production.sqlite3` (or `staging.sqlite3`) with the restored file,
then restart.

## Restoring from S3 (server lost, or the local copy isn't good enough)

Needs the AWS credentials from Rails credentials, and the `aws` CLI (or any S3 client):

```sh
export RAILS_MASTER_KEY=$(cat config/credentials/production.key)   # or staging.key
ACCESS_KEY_ID=$(RAILS_ENV=production bin/rails runner 'print Rails.application.credentials.dig(:aws, :access_key_id)')
SECRET_ACCESS_KEY=$(RAILS_ENV=production bin/rails runner 'print Rails.application.credentials.dig(:aws, :secret_access_key)')

AWS_ACCESS_KEY_ID="$ACCESS_KEY_ID" AWS_SECRET_ACCESS_KEY="$SECRET_ACCESS_KEY" \
  aws s3 cp "s3://$DB_SNAPSHOT_BUCKET/cms_db_snapshots/production/2026-09-14.sqlite3.gz" - --region ap-southeast-2 \
  | gunzip > /tmp/restored.sqlite3

sqlite3 /tmp/restored.sqlite3 "SELECT COUNT(*) FROM entries;"
```

Then swap it in the same way as the local-restore path above.

## After swapping it in

Restarting the app runs `bin/rails nibble:upgrade` before the server starts (`bin/docker-entrypoint`). It applies
any database and content migrations newer than the backup, then checks the restored content against the schema the
running release expects. If it refuses to start, the message says why; `bin/rails nibble:check` shows the same
problems on demand.

Asset files are not in this backup: they live in the Active Storage bucket (`AWS_BUCKET_NAME` unless
`AWS_BUCKET_NAME` says otherwise). A restore can leave the two out of step:

- **Uploaded after the backup:** the files are still in the bucket, but the restored database has no asset for
  them, so `bin/rails nibble:assets:purge_unused` lists them as stray. Don't run it with `--confirm` until you've
  decided whether those uploads need re-adding.
- **Deleted after the backup:** the restored database points at files that were already removed, so those images
  break. They can only come back if versioning is on for the bucket; check that before relying on it.

A full restore drill (actually doing this against a wiped staging volume, not just reading a file
back) is still pending.
