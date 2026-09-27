---
id: running-deploying
title: Deploying
description: Put the site on a server with Kamal — the deploy files, secrets, storage, the first deploy, seeding the
  database, and what every deploy checks before it serves.
order: 3
---

# Deploying

Nibble deploys with [Kamal](https://kamal-deploy.org): one Docker image onto one server. There is no managed
database and no separate front end — SQLite and the uploads live on the server's storage volume, and the image runs
everything. This guide takes Tidewater's site from a laptop to `https://tidewater.example`.

After reading this guide, you will know:

- Which files a deploy needs, and how to generate them.
- Where the registry password and the credentials key come from.
- How to deploy the first time, and every time after.
- How to put content into a new, empty database.
- What a container checks before it serves, and what happens when a check fails.

## 1. What runs on the server

Inside the container: Puma behind Thruster, the Node process that renders pages on the server, and Solid Queue — for
scheduled publishing, emails and background work — inside Puma. SQLite files and uploaded files live on a Docker
volume mounted at `/rails/storage`, so they survive every deploy.

You need a server you can SSH into with Docker installable, a domain pointing at it, and an account with a
container registry such as Docker Hub or GitHub's.

## 2. The deploy files

If you did not ask for them at install, generate them now:

```sh
bin/rails nibble:install --only=deploy
```

It asks the site's questions again, then the deploy's:

| Question | Tidewater's answer |
|---|---|
| Production domain | `tidewater.example` |
| Production server address | `203.0.113.10` |
| Container registry username | `tidewater` |
| SSH user on the servers | `root` |

and writes:

| File | What it is |
|---|---|
| `Dockerfile`, `.dockerignore`, `bin/docker-entrypoint` | how the image is built and started |
| `config/deploy.yml` | Kamal's configuration, with Nibble's settings merged in |
| `.kamal/secrets` | where Kamal finds each secret — Kamal's own file |
| `.kamal/hooks/` | Kamal's sample hooks |

All of them are yours: edit them freely, and commit them.

### 2.1 config/deploy.yml

The parts Nibble fills in:

```yaml
service: tidewater
image: tidewater/tidewater

servers:
  web:
    - 203.0.113.10

proxy:
  ssl: true
  hosts:
    - tidewater.example

registry:
  username: tidewater
  password:
    - KAMAL_REGISTRY_PASSWORD

env:
  secret:
    - RAILS_MASTER_KEY
  clear:
    SITE_URL: https://tidewater.example
    SMTP_ADDRESS: smtp.postmarkapp.com
    SMTP_PORT: 587
    SOLID_QUEUE_IN_PUMA: true

volumes:
  - tidewater-storage:/rails/storage

asset_path: /rails/public
```

`tidewater-storage` is a Docker volume, kept under `/var/lib/docker/volumes/` on the server. To keep it in a folder
you can see instead, see [Storage in a folder](#24-storage-in-a-folder).

Add the rest of the site's settings under `env.clear` — see
[Configuration](configuration.md#6-environment-and-credentials). Tidewater's also sets:

```yaml
    AWS_BUCKET_NAME: tidewater-uploads
    AWS_REGION: eu-west-2
    DB_SNAPSHOT_BUCKET: tidewater-backups
    DB_SNAPSHOT_REGION: eu-west-2
```

> [!TIP]
> Uploads do not need S3. Without `AWS_BUCKET_NAME`, they are stored on the server's storage volume — fine for a
> small site or a demo. Use a bucket once losing the server would mean losing images.

> [!IMPORTANT]
> A copy of the site that is public but is not the real one — a demo, a preview — should also set
> `NIBBLE_BLOCK_INDEXING: 1`, so search engines do not index it.

### 2.2 Secrets

`.kamal/secrets` tells Kamal where each secret comes from. `config/deploy.yml` asks for two — the registry password
and the credentials key — but `kamal init` writes the file with every line commented out.

> [!WARNING]
> Until you uncomment them, the first deploy fails for want of `KAMAL_REGISTRY_PASSWORD` and `RAILS_MASTER_KEY`.

Uncomment these two lines in `.kamal/secrets`:

```sh
KAMAL_REGISTRY_PASSWORD=$KAMAL_REGISTRY_PASSWORD
RAILS_MASTER_KEY=$(cat config/master.key)
```

The registry password is then read from your shell — set `KAMAL_REGISTRY_PASSWORD` to a registry access token, not
your account password — and the credentials key from `config/master.key`. The file holds no secrets itself, so it is
safe to commit. Kamal's comments in the file show how to read them from a password manager instead.

Everything else sensitive goes in the encrypted credentials:

```sh
bin/rails credentials:edit
```

```yaml
smtp:
  username: …
  password: …
aws:
  access_key_id: …
  secret_access_key: …
```

> [!CAUTION]
> `config/master.key` is not in git, and nothing else can decrypt the credentials. Keep a copy somewhere safe — a
> deploy from a new laptop needs it, and so does restoring a server.

### 2.3 A bucket for uploads, if you use one

The bucket does not need to be public: images are served through the application, which is what lets it crop and
resize them. The Control Plane uploads straight from the browser, so the bucket needs a CORS rule for the site:

```json
[
  {
    "AllowedOrigins": ["https://tidewater.example"],
    "AllowedMethods": ["PUT"],
    "AllowedHeaders": ["Content-Type", "Content-MD5", "Content-Disposition"],
    "MaxAgeSeconds": 3600
  }
]
```

### 2.4 Storage in a folder

Storage holds the SQLite databases, and uploads when there is no bucket. To keep it in a folder in the SSH user's
home — `/root` for `root` — rather than a Docker volume, start the path with `./`:

```yaml
volumes:
  - ./tidewater-storage:/rails/storage
```

Create the folder on the server before the first deploy. The application runs as user 1000, and a folder Docker
creates for you belongs to root, so the site could not write its database:

```sh
ssh root@203.0.113.10
mkdir -p ~/tidewater-storage
chown 1000:1000 ~/tidewater-storage
```

As a user other than `root`, run the `chown` with `sudo`, or skip it when `id -u` prints 1000.

To move a site that already runs on a volume, copy the volume into the folder while the application is stopped,
then deploy with the new path:

```sh
bin/kamal app stop
ssh root@203.0.113.10
mkdir -p ~/tidewater-storage
docker run --rm -v tidewater-storage:/from -v ~/tidewater-storage:/to alpine \
  sh -c 'cp -a /from/. /to/ && chown -R 1000:1000 /to'
exit
bin/kamal deploy
```

Once the site is working, `docker volume rm tidewater-storage` on the server removes the old copy.

## 3. The first deploy

```sh
bin/kamal setup
```

`setup` installs Docker on the server if it needs to, builds the image, pushes it, and starts the site behind
Kamal's proxy, which fetches a TLS certificate for the domain.

Building the image runs `bin/rails nibble:build`, so a help article with bad frontmatter fails the build on your
machine rather than the deploy on the server.

### 3.1 Seeding the new database

A new server starts with an **empty database**. The schema is there, the help centre is there — it is files — but
there are no pages, posts or people.

Create an administrator:

```sh
bin/kamal app exec -i 'bin/rails nibble:admin:create'
```

Then either write the content in the production Control Plane, or import the
[content package](content-packages.md) you keep in the repository:

```sh
bin/kamal app exec 'bin/rails nibble:content:import site/packages/default'
```

and build the search index, so the help centre is searchable:

```sh
bin/kamal app exec 'bin/rails nibble:search:rebuild'
```

> [!WARNING]
> Importing is a one-time step, not part of a deploy. Running it again later would fight whatever has been written in
> the Control Plane since. The default mode, `create`, only adds what is missing — so a second run is harmless, but
> it is never needed.

> [!NOTE]
> A content package carries each image's details, not the image itself. Upload images again, or copy the storage
> volume or the bucket, if the imported pages use any.

## 4. Every deploy after

```sh
git push
bin/kamal deploy
```

Before the new container accepts a request, `bin/docker-entrypoint` runs `bin/rails nibble:prepare`, which:

1. Refuses a theme built for a different theme API.
2. Runs database migrations, then [content migrations](../modelling/changing-schema.md).
3. Runs `nibble:check`, which refuses a schema change that would strand stored content.
4. Indexes pages written as files for search, and builds the whole index when it is empty.
5. Records the schema it is serving.

**If anything refuses, the new container never becomes healthy.** Kamal keeps the old one serving, and the container's
log says exactly why. A bad deploy is a non-event rather than an outage.

> [!IMPORTANT]
> Database migrations run before the check, as in any Rails deploy, so write them to work with the old release still
> serving.

## 5. Day to day

```sh
bin/kamal console    # a Rails console on the server
bin/kamal shell      # a shell in the container
bin/kamal logs       # follow the logs
bin/kamal dbc        # the database console
```

**Health.** `/up` answers 200 when the application has booted; Kamal's proxy uses it.

**CDNs.** A proxying CDN in front of the site works with no rules to write. Asset URLs are versioned by content and
cached for a long time; HTML is sent `Cache-Control: private`, because caching a whole page at the edge could share
one visitor's session with another. Nibble's own page cache sits inside the application, where it knows who is
asking.

**Backups.** A nightly job copies the database and, with `DB_SNAPSHOT_BUCKET` set, uploads it. See
[Backups](backups.md).
