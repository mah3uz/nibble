---
id: modelling-changing-schema
title: Changing the schema
description: Add, rename and remove fields and collections once content exists — what nibble:check refuses, and
  how content migrations move the data safely.
order: 11
---

# Changing the schema

Changing the shape of content that already exists is the one part of modelling to take slowly. This guide follows
Tidewater through the changes it made to its live site.

After reading this guide, you will know:

- Which schema changes are free, and which need care.
- What `nibble:check` refuses, and why a refused deploy never goes live.
- How to write, test and run a content migration.
- Every migration operation, and what each leaves alone.

## 1. The rule of thumb

**Adding a field is free. Renaming needs a migration. Removing needs a decision.**

| Change | What happens to existing content |
|---|---|
| add a field, a blueprint, a collection | nothing; the field is empty until someone fills it, even if it has a `default` — [`set_default`](#42-set_default) fills it |
| change a collection's or taxonomy's `route` | `nibble:prepare` moves every record to its new address, with a 301 from each live one |
| make a field required | existing entries are fine until next saved, when they must fill it |
| rename a field, a collection, a navigation or a global set | the old values are stranded under the old name — **migrate** |
| change a field's type | values stored as the old type may not fit — **check first** |
| remove a field, a set or a collection | the values are orphaned — **migrate them away, or accept losing them** |

## 2. What `nibble:check` protects

`nibble:check` compares the schema with the content stored under it, and refuses a change that would leave stored
content with no field to belong to:

```
✗ collections/posts: intro was removed and 14 records still hold it; add a migration in schema/migrations, or run nibble:check --allow-data-loss
nibble:check found 1 problem(s)
```

Only records that hold a value count: a field someone cleared holds nothing, so emptying a field everywhere is one
way to decide it can go.

It runs before every deploy, as part of `bin/rails nibble:prepare`. A deploy it refuses never becomes healthy, and
Kamal keeps the old release serving — a mistake here costs a failed deploy, not the site.

> [!CAUTION]
> `bin/rails nibble:check --allow-data-loss` turns those problems into warnings. Use it only when you have decided
> the data should go, because once the release is live, nothing will read it again.

## 3. A content migration

Say Tidewater's posts have a field called `intro`, and you decide it should be `summary`, to match the customer
stories. Renaming the field in the blueprint alone would strand every existing intro. A content migration moves
them.

### 3.1 Write it

```yaml
# site/schema/migrations/2026_10_01_rename_intro.yml
operations:
  - rename_field:
      collection: posts
      from: intro
      to: summary
```

A migration is a YAML file in a `migrations/` folder of the site's schema, `site/schema/migrations/`, run once, in file-name
order — so start the name with the date. Nibble reads the same folder in its own schema and in the active theme's
`schema/`, so a theme that renames a field can ship the migration that moves its content; the names of all three are
ordered together, and each is recorded under its layer, so two layers can use the same file name. Change the blueprint in
the same commit.

### 3.2 Try it

```sh
bin/rails nibble:content:migrate --dry-run
```

`--dry-run` runs every pending migration, prints what it changed, and rolls it all back.

### 3.3 Run it

```sh
bin/rails nibble:content:migrate
```

On a server there is nothing to run by hand: every deploy runs `bin/rails nibble:prepare`, which applies pending
database migrations, then pending content migrations, then `nibble:check`. Each migration is recorded, so it never
runs twice.

> [!IMPORTANT]
> Drafts waiting to be published are migrated too. Without that, publishing a draft written before the change would
> bring the old field back.

> [!NOTE]
> Migrations are idempotent: `rename_field` on content that has no `intro` left changes nothing. That is what makes
> a failed deploy safe to retry.

## 4. The operations

Each operation names a `collection` or a `taxonomy` to work on. `rename_field`, `set_default`, `move_field` and
`remove_field` also take a `global`, and change that global in every locale:

```yaml
- rename_field: { global: site, from: phone, to: telephone }
```

### 4.1 `rename_field`

```yaml
- rename_field: { collection: posts, from: intro, to: summary }
```

Moves each value from one field to another. `title` and `slug` cannot be renamed; they are not fields.

### 4.2 `set_default`

```yaml
- set_default: { collection: posts, field: reading_level, value: beginner }
```

Fills a field on every entry where it is empty, including entries where someone cleared it. Useful after adding a
field with a default, or a required one.

### 4.3 `change_blueprint`

```yaml
- change_blueprint: { collection: pages, from: page, to: landing }
```

Moves entries from one blueprint to another — when Tidewater split its pages into ordinary pages and landing
pages, for example.

### 4.4 `move_to_taxonomy`

```yaml
- move_to_taxonomy: { collection: posts, field: tags_text, taxonomy: topics, to: topics }
```

Turns free-text values into terms: each name becomes a term in the taxonomy — created if it does not exist — and the
entry points at it through the `to` field. The text field is removed.

### 4.5 `rename_collection`

```yaml
- rename_collection: { from: stories, to: customers }
```

Moves every entry to the collection's new handle. Rename the collection's file first: the operation refuses while
the old handle is still in the schema, or before the new one is. **URLs are left alone** — a rename is not a move.

Permissions move too. A role or a connected app that could edit `stories` can edit `customers`, approve its entries
if it could approve them before, and the collection keeps its row under **Agent access**. Permissions that name every
collection, such as `entries.*`, already cover the new handle and are left alone.

When the new handle already has entries — two collections merged into one — the old permissions are dropped instead,
because carried over they would reach the entries that were there first. The migration's report says so; tick what
each role should have under **Roles**.

### 4.6 `delete_collection`

```yaml
- delete_collection: { collection: webinars }
```

Deletes every entry of a collection that is no longer in the schema, with its drafts, revisions and
relationships, and takes the collection's permissions out of every role and connected app, so a collection given the
same handle later starts with nobody holding them.

> [!CAUTION]
> `delete_collection` removes entries outright — there is no trash to restore them from, because there is no
> schema left to restore them under. Take a [backup](../running/backups.md) first, and read the dry run.

### 4.7 `move_field`

```yaml
- move_field:
    from: { global: site, field: google_rating }
    to: { global: social, field: rating }
```

Moves each value to another field and removes it from the first: from one global to another, locale by locale, or
between two fields of the same collection, taxonomy or global. A locale with no `social` values yet gets them.

The field it moves to must be in the schema, and of the same type as the field it moves from — read from the
schema, or from the [last snapshot](#5-changing-a-fields-type) once that field has gone.

A record whose destination already holds a different value is left as it is, and named in the migration's report:

```
move site.google_rating to social.rating, leaving global 3 (fr) where rating already holds a value: 1
```

Its value stays where it was, so `nibble:check` keeps refusing until you decide. To replace what is there, add a
migration with `overwrite: true`:

```yaml
- move_field:
    from: { global: site, field: google_rating }
    to: { global: social, field: rating }
    overwrite: true
```

### 4.8 `remove_field`

```yaml
- remove_field: { collection: posts, field: intro }
```

Removes a field's stored values once it is no longer in the schema, so `nibble:check` passes without
`--allow-data-loss`. It refuses while the field is still in the schema.

Each record it changes gets a revision, and the one before still holds the value. A draft's value goes too, and a
draft has no revisions.

### 4.9 `rename_navigation` and `rename_global`

```yaml
- rename_navigation: { from: footer, to: site_footer }
- rename_global: { from: contact, to: company }
```

Moves a menu, or a global set, to its new handle in every locale. Rename its file first: each refuses while the old
handle is still in the schema, or before the new one is. The records keep their ids, so their revisions and drafts
come with them, and so do the permissions of roles and connected apps: whoever could edit `footer` can edit
`site_footer`.

A locale where the new handle already has a menu or values is left as it is, under the old handle, and named in the
report:

```
rename navigation footer to site_footer, leaving fr where site_footer already has one: 1
```

The permissions are dropped rather than carried in that case, as for a merged collection.

### 4.10 `delete_navigation` and `delete_global`

```yaml
- delete_navigation: { navigation: footer }
- delete_global: { global: contact }
```

Deletes a menu, or a global set, that is no longer in the schema, in every locale, with its drafts, revisions and
relationships, and takes its permissions out of every role and connected app. Each refuses while the handle is still
in the schema. Like `delete_collection`, there is no trash to restore from.

## 5. Changing a field's type

Nibble records the type of every field it has served. When a field's type changes — `text` to `integer`, say —
`nibble:check` reports the stored values that may no longer fit, before a deploy rather than after it. Record the
current types as the new baseline once you are happy:

```sh
bin/rails nibble:schema:snapshot
```

`nibble:prepare` takes the same snapshot automatically after every successful deploy.

## 6. A checklist for risky changes

1. Change the schema and write the migration in one commit.
2. `bin/rails nibble:content:migrate --dry-run` against a copy of production's data.
3. `bin/rails nibble:check` — no problems, and no `--allow-data-loss`.
4. Make sure last night's [backup](../running/backups.md) exists.
5. Deploy. If anything refuses, the old release keeps serving and the log says why.
