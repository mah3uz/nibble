---
id: running-check-messages
title: Check messages
description: Every kind of message bin/rails nibble:check can print, what it means and how to make it go away.
order: 13
---

# Check messages

`bin/rails nibble:check` reads the schema, the theme, the settings and the database, and prints what it finds. This
page is for the moment it prints something you do not recognise: find the message below, read what it means, and do
what the last column says. The same findings appear under **Utilities → Schema** in the Control Plane.

Each line starts with where the problem is, then what is wrong:

```text
! site/schema/forms/contact.yml: spam.honeypot 'email' looks like a field browsers and password managers fill in …
✗ blueprints/collections/posts/post.yml: field 'hero' uses unknown validation rule 'maxx'
```

- **`✗` is an error.** The check fails, and a deploy or an upgrade stops.
- **`!` is a warning.** The site works, but something is probably not what you meant.

Messages that name a file are about that file, and its path is relative to the site. Where a message says a field,
`field 'a.b'` is the path through grids and replicators.

`--allow-data-loss` reports the "still hold it" messages in [section 4](#4-stored-content-and-the-schema) as
warnings instead of errors; use it only when you mean to drop that data. `--support` adds a summary of the install to
paste into an issue.

## 1. The schema files

Nibble reads every file under `site/schema/`, the theme's `schema/` and its own. An error in one of them stops the
rest of the check, since nothing else can be judged until it is fixed.

| Message | Meaning | Fix |
|---|---|---|
| `must be a YAML mapping`, `invalid YAML: …` | the file is empty, a list, or not valid YAML | fix the syntax; the message names the line |
| `unknown key (allowed: …)` | a key the schema does not read, often a typo | use one of the listed keys; the [modelling guides](../modelling/index.md) say what each means |
| `is required` | a key that file must have is missing | add it |
| `has an invalid value: …` | the key is there but the wrong shape | compare with the guide for that kind of file |
| `format … isn't supported` | the file's `schema:` number is not the one this release reads | set it to the number the message gives |
| `unknown schema folder '…'`, `files can't be nested in folders`, `blueprints live at …` | a file is somewhere the schema does not look | move it to the folder the message names |
| `belongs to …, which isn't defined` | a blueprint for a collection or taxonomy that does not exist | create the collection, or move or delete the blueprint |
| `no blueprint at …`, `no taxonomy '…'` | a collection or field names something that is not there | create it, or correct the handle |
| `… doesn't exist in the schema`, `… is core-owned and can't be disabled` | `disable:` in `config/nibble.yml` names something missing or something Nibble needs | remove that line |
| `handles can't contain '::'` | `::` is reserved for Nibble's own fieldsets | rename it |

## 2. Fields

Run for every blueprint, fieldset, global and form.

| Message | Meaning | Fix |
|---|---|---|
| `field '…' uses unknown validation rule '…'` | a `validate:` rule that does not exist | correct the name, or register the rule |
| `field '…' <reason>` (for example `earliest … is after latest …`, `has allow_any: false but no swatches to choose from`, `default … isn't a colour written as #rrggbb`) | the fieldtype rejects its own settings | change the setting the message names |
| `field '…' has a message for '…', which it has no rule for` | a custom `messages:` entry for a rule the field does not use | remove it, or add the rule |
| `field '…' has a '…' message for locale '…', which the site doesn't have` | a translated message for a language not in `locales` | remove it or add the locale |
| `field '…' has a required condition that …` | a conditional `required` that is not exactly one of the condition forms, or names a field that is not beside it | rewrite it as the message says |
| `field '…' is a note, which only displays text …` | a note field with `required`, `hidden`, `encrypt` or a default | remove those settings |
| `field '…' is a calculation, which only a form can have` | the calculation fieldtype is used outside a form | use it in a form, or use another fieldtype |
| `field '…' has computed default '…', which isn't registered` | `default: computed:name` with no such default | register it, or use a plain default |
| `field handle '…' is reserved for the entry itself` | the handle is one the entry already uses (`slug`, `status`, `uri`, `template` and the like) | rename the field |
| `field '…' is a …, which apps can't be told how to write: give the fieldtype a json_schema` (warning) | a custom fieldtype that agents and the management API cannot describe | add a `json_schema` to the fieldtype |

## 3. Forms and tasks

A form's messages begin with its file. The common ones:

| Message | Meaning | Fix |
|---|---|---|
| `field '…' uses '…', which can't be used on a public form` | a fieldtype that is not safe to show visitors | use a public fieldtype |
| `field handle '…' clashes with the honeypot` | the honeypot field name is also a real field | rename one |
| `spam.honeypot '…' looks like a field browsers and password managers fill in` (warning) | real visitors may be caught as spam | choose an odd name |
| `field '…' has prefill but isn't hidden: true`, `… has value but isn't hidden: true` | a preset value the visitor would see and change | add `hidden: true` or drop it |
| `… needs the form to store submissions` | uploads, limits or resume depend on stored submissions | set the form to store them |
| `limits.…`, `spam.…`, `resume…`, `notify.N.…`, `retention_days …` | a setting with a wrong shape; the message says what it should be | see [Forms](../modelling/forms.md) |
| `api.N …` | a delivery with neither `use` nor `url`, an unknown API connection, a bad `method`, `format` or `mode` | see [Forms](../modelling/forms.md) |
| `… has a formula …` | a calculation field that does not parse, or names a field that is missing or not numeric | fix the formula |
| `success needs a message or a redirect`, `handler '…' isn't registered` | a form with no success outcome, or a handler name that does not exist | add one, or register the handler |
| `… has captcha: true but Integrations has no CAPTCHA keys, so every submission is refused` (warning) | the form needs a CAPTCHA and none is configured | add the keys under **Integrations**, or turn captcha off |
| `form '…' has N stored submissions but isn't in the schema …` (warning) | a form was removed while its submissions remain; the daily purge will delete them | restore the form, or export the submissions first |

Scheduled tasks print: `needs exactly one of fetch, request or handler`; `schedule '…' runs more often than once a
minute`; `fetch.… isn't a key a task reads`; `… needs either use or url`; `… calls HOST, which isn't in
outbound.allowed_hosts`; `fetch.into …` and `fetch.into.map names '…', which … doesn't have`; and `collection '…' uses
the review workflow, so a task can't publish into it`. Each says what to change; the keys are in
[Scheduled tasks](../modelling/scheduled-tasks.md).

## 4. Stored content and the schema

These run against the database, so a build with no database does not show them.

| Message | Meaning | Fix |
|---|---|---|
| `not set up, or has migrations to run: run bin/rails db:prepare` | the database is behind the code | run it (a deploy does) |
| `<scope>: <field> was removed and N records still hold it` | you took a field out of a blueprint while entries still store a value for it | add a [content migration](../modelling/changing-schema.md) to move or delete the value, or put the field back; `--allow-data-loss` accepts losing it |
| `<scope>: <field> changed from A to B and N records hold a value` | the field's type changed under stored values | write a migration to convert them |
| `blueprint '…' was removed and N records still use it` | as above, for a whole blueprint | add a `change_blueprint` migration |
| `collection '…' was removed and N records still belong to it` | a collection left the schema with entries in it | restore it, or add a `rename_collection` or `delete_collection` migration |
| `global set '…' was removed and N records still belong to it` | a global set left the schema with values saved in it | restore it, or add a `rename_global` or `delete_global` migration |
| `navigation '…' has a menu saved in N locales but isn't in the schema …` (warning) | a navigation left the schema with its menus still stored; nothing shows them | restore it, or add a `rename_navigation` or `delete_navigation` migration |
| `site/schema/migrations: …` | a pending content migration is invalid | fix the migration file named |
| `role '…': ability '…' doesn't match anything in this site's schema` | a custom role grants an ability on a collection or form that no longer exists | edit the role under **Roles**; a pending migration that renames or deletes the handle answers it |
| `collection '…' has N entries not at the address the route gives; bin/rails nibble:prepare moves them` (warning) | a route changed and the saved addresses are stale | run `nibble:prepare` (a deploy does) |
| `N entries have the required toggle '…' switched off, so they can't be published until …` (warning) | a toggle marked required is off on existing records | switch it on or make the field optional |
| `N entries (…) have a value in the email field '…' that fails its format check …` (warning) | stored values that no longer pass the field's format | correct them in the entries named |

## 5. Settings and the theme

| Message | Meaning | Fix |
|---|---|---|
| `outbound.allow_private_networks is set in production, where it is ignored` | a development setting left in `config/nibble.yml` | remove it |
| `collection '…' doesn't exist`, `taxonomy '…' doesn't exist` (navigation) | a menu offers something that is gone | edit the navigation file |
| `icon '…' isn't one of the Control Plane icons` | an unknown `icon:` on a collection or taxonomy | use one of the named icons |
| `index '…' uses missing collection '…'`, `… searches field '…', which no blueprint of its collections defines` | search settings name something that is not there | correct `search.yml` |
| `index '…' lists collections, which are no longer read: give each one search: …` | the old way of assigning a collection to an index | put `search: <index>` in the collection's own file |
| `query '…' …` | a view's or layout's `.yml` sidecar has an invalid query | the message says which part |
| `page.<key> isn't a page key (use include)` | a `page:` entry in a sidecar with a key other than `include` | use `include` |
| `page.include '…' isn't a relationship field in any blueprint`, `page.include 'children' needs a structured collection` | `page: { include: … }` names something that can't be expanded | name an `entries` or `terms` field, or `children` once a collection is structured |
| `query '…' is named like the … prop every page is given` | a layout's query is called `page`, `layout`, `site`, `seo` or `preview` | rename it |
| `query '…' is also a view's query, so one would hide the other` | a layout and a view use the same query name | rename one |
| `query '…' hides the … prop every view is given; rename the query` (warning) | a view's query is called `page`, `layout`, `site`, `seo` or `preview` | rename it |
| `theme.yml: '…' is required`, `… isn't a manifest key`, `handle … must match the folder name`, `nibble … isn't compatible with theme API …` | the theme's manifest | fix `theme.yml` |
| `required view '….vue' is missing`, `required layout 'default.vue' is missing`, `set '…' has no view sets/….vue` | the theme lacks a view the site needs | add the view |
| `index_route needs the view … .vue, which … doesn't have` | a collection with an index page and a theme with no view for it | add the view or set `index_template` |
| `generated types are out of date: run bin/rails nibble:schema:types` | `site/types.d.ts` no longer matches the schema | run it (`nibble:build` does too) |
| `… has changed since you took this copy on …` (warning) | a file you ejected, where Nibble's own has since changed | compare, and merge by hand |
| `changed here rather than ejected, so the next upgrade will refuse until it is put back` (warning) | you edited a file under `vendor/nibble/` | put it back, or `nibble:eject` it |

## 6. The server

Only checked where the site is deployed (`production`); a laptop does not see these.

| Message | Meaning | Fix |
|---|---|---|
| `SITE_URL is not set …`, `… is not a valid URL`, `… points at localhost …`, `… is not https` | the public address is missing or wrong, so canonical links and mail would be wrong | set `SITE_URL` to the `https` address |
| `RAILS_MASTER_KEY is missing or wrong …`, `cannot decrypt the credentials` | the encrypted credentials cannot be read | provide the key in `config/master.key` or the environment |
| `storage: AWS_BUCKET_NAME, AWS_REGION, aws.access_key_id unset, so uploads and image transforms will fail` | S3 is in use, and part of its settings are missing | set what is listed; see [Configuration](configuration.md#6-environment-and-credentials) |
| `theme: no theme is set …` (warning) | only the Control Plane serves | name a theme |
| `theme: '…' has no folder …`, `asks for a different Nibble than this one` | the theme named is not installed or not for this release | install it, or choose another |
| `mail: no SMTP credentials …` (warning) | password resets and notifications will not send | add `smtp.username` and `smtp.password` to the credentials |
| `passkeys: config/initializers/webauthn.rb doesn't allow …` (warning) | passkeys will not work at this address | add the address to the initializer's allowed origins |
| `backups: DB_SNAPSHOT_BUCKET unset, so nothing is copied offsite` (warning) | the nightly copy stays on the server | set the bucket; see [Backups](backups.md) |
| `schedule: config/recurring.yml doesn't schedule …, so that work never runs` (warning) | a job Nibble ships has been removed from the schedule | restore it from [Utilities → Jobs](utilities.md#3-jobs) |

The errors here also stop the site starting, which is deliberate: serving with a wrong address or no credentials
publishes broken links or drops uploads. A console, a migration and `nibble:check` itself still run, so you can fix
it.
