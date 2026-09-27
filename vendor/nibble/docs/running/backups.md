---
id: running-backups
title: Backups
description: What is backed up, when and where, how to restore on a live server or a new one, and what to check
  afterwards.
order: 4
---

# Backups

Every night at 3am the whole database is copied, compressed and kept in two places. This guide covers what that
protects, and how Tidewater would get back after a bad day.

After reading this guide, you will know:

- What is backed up, and what is not.
- Where backups are kept, and how to turn on the offsite copy.
- How to restore on a server that is still running, and on a new one.
- What to check after a restore.

## 1. What is backed up

**The database** — every page, post, term, global, menu, asset record, user, form submission and redirect. It is
one SQLite file, so a backup really is a complete copy of the content.

| Not backed up | Why |
|---|---|
| Uploaded files | they live in S3, which keeps its own copies — or on the storage volume, see below |
| The cache, job queue and cable databases | they rebuild themselves |
| Help articles and other files in `site/content/` | they are in git, with the rest of the code |
| Your code | git |

> [!WARNING]
> If uploads are stored on the server's volume rather than in S3, the nightly backup does **not** include them.
> Losing the server loses the images. Move uploads to S3 once the images matter.

## 2. How and where

The nightly job compacts the database into a clean, self-contained copy, gzips it, and keeps it:

- **On the server**, in `storage/backups/`, for 7 days. The fastest way back after a bad migration or a mistake.
- **In S3**, in the bucket named by `DB_SNAPSHOT_BUCKET`, under `cms_db_snapshots/<environment>/`. This is what saves
  you if the server itself is gone.

Set `DB_SNAPSHOT_BUCKET` and `DB_SNAPSHOT_REGION` in the deploy to turn the offsite copy on — see
[Deploying](deploying.md#21-configdeployyml). Give the bucket a lifecycle rule, such as 30 days, so old copies expire.

> [!IMPORTANT]
> Without `DB_SNAPSHOT_BUCKET`, every boot warns that nothing is copied offsite. Take the warning seriously before
> there is anything in the site you would mind losing.

**Upgrades take their own snapshot too**, before they change anything, and print the command that restores it. See
[Upgrading](upgrading.md).

## 3. Restoring on a running server

Unpack the backup you want onto the storage volume, and look before you leap:

```sh
bin/kamal app exec 'gunzip -c storage/backups/2026-10-14.sqlite3.gz > storage/restored.sqlite3'
bin/kamal app exec 'sqlite3 storage/restored.sqlite3 "SELECT COUNT(*) FROM entries;"'
```

If the count looks right, stop the site, swap the files, and start it again:

```sh
bin/kamal app stop
bin/kamal app exec 'mv storage/restored.sqlite3 storage/production.sqlite3 && rm -f storage/production.sqlite3-wal storage/production.sqlite3-shm'
bin/kamal app boot
```

`bin/kamal app exec` starts a fresh container on the same volume, which is why it works while the site is stopped.

> [!CAUTION]
> Remove the `-wal` and `-shm` files along with the old database. They belong to the file you replaced, and SQLite
> would try to apply them to the restored one.

## 4. Restoring on a new server

Fetch the backup from S3 on your own machine, using the AWS keys in the credentials:

```sh
AWS_ACCESS_KEY_ID=$(bin/rails runner 'print Rails.application.credentials.dig(:aws, :access_key_id)') \
AWS_SECRET_ACCESS_KEY=$(bin/rails runner 'print Rails.application.credentials.dig(:aws, :secret_access_key)') \
  aws s3 cp "s3://tidewater-backups/cms_db_snapshots/production/2026-10-14.sqlite3.gz" - --region eu-west-2 \
  | gunzip > /tmp/restored.sqlite3

sqlite3 /tmp/restored.sqlite3 "SELECT COUNT(*) FROM entries;"
```

Deploy to the new server with `bin/kamal setup`, then stop the app, copy the file onto the server, move it into the
storage volume as `storage/production.sqlite3` as above, and `bin/kamal app boot`.

## 5. When it starts again

Starting the application runs `bin/rails nibble:prepare` first. It applies any migrations newer than the backup and
checks the restored content against the schema of the running release. If it refuses, the message says why — a site
serving content it cannot understand is worse than a site that will not start.

### 5.1 Uploads and the database can disagree

The database is restored to last night; the files in S3 are from right now.

- **Uploaded after the backup:** the files are in the bucket but the database has no record of them, so
  `bin/rails nibble:assets:purge_unused` would list them as unused. **Do not run it with `--confirm`** until you have
  decided whether they need adding back.
- **Deleted after the backup:** the database points at files that are gone, so those images are broken. They can only
  come back if the bucket keeps old versions — turn versioning on before you need it.

## 6. Practise it

A backup nobody has restored is a hope, not a plan. Restore one onto a spare server on a quiet afternoon. You will
learn how long it takes, which is the number you will want on the day it matters.
