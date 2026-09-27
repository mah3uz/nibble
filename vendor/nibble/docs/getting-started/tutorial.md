---
id: getting-started-tutorial
title: Getting Started with Nibble
description: Build Tidewater's marketing site from an empty directory — landing pages, a blog, a help centre written
  as files and a demo form — and get it ready to deploy.
order: 1
---

# Getting Started with Nibble

This guide builds the whole Tidewater site in one sitting. Each step is covered in depth by a guide of its own;
here the aim is to see every part working together once.

After reading this guide, you will know:

- How to install Nibble and sign in to a new site.
- How to give the site a theme of its own.
- How landing pages are built from blocks, and how to add a block of your own.
- How to run a blog with an Atom feed.
- How to serve a folder of Markdown as a help centre.
- How to declare a form and put it on a page.
- What to check before the first deploy.

## 1. Guide assumptions

In this guide you are Tidewater's developer, setting up the site from nothing. It assumes you can use a terminal and
git, and can read a Vue component. It does not assume you know Rails.

You will build this:

| URL | What it is | Where it comes from |
|---|---|---|
| `/` | the home page | a page in the Control Plane, built from blocks |
| `/pricing` | three plans side by side | a page with a block you add yourself |
| `/blog`, `/blog/<slug>` | the blog, with an Atom feed | the `posts` collection |
| `/help`, `/help/<slug>` | the help centre | Markdown files in `site/content/help/` |
| `/demo` | a "book a demo" form | a form declared in YAML |

## 2. Creating the site

### 2.1 Installing

From the directory where you keep projects:

```sh
curl -fsSL nibble.ink/install.sh | bash
```

The installer checks your machine and asks for the site's name — answer **tidewater**, and it becomes the folder. It
then downloads the latest release into `tidewater/vendor/nibble`, installs dependencies, and asks a handful of
questions. Answer them like this:

```
Application name (containers, image and volume are named after it) [tidewater]: tidewater
Public site URL [http://localhost:3100]: https://tidewater.example
Theme handle [crumbs]: crumbs
```

Say **no** to deploying with Kamal for now — you can add it later — create an administrator for yourself, and
say **no** to the example content: Tidewater's site starts empty, and this guide fills it.

> [!NOTE]
> Every question, every file the installer writes, and what to do when a tool is missing are covered in
> [Installing Nibble](installing.md).

### 2.2 Starting it

```sh
cd tidewater
bin/dev
```

`bin/dev` starts Rails, the Vite asset build and server-side rendering together. Open:

- `http://localhost:3100` for the public site
- `http://localhost:3100/cp` for the Control Plane

Sign in with the administrator you just created. The public site answers "Page not found" for now — there is no
content yet — and it is drawn by `crumbs`, the theme Nibble ships.

> [!TIP]
> Keep `bin/dev` running for the rest of this guide. Schema files, content files and edits to existing views and
> styles reload as you save them.

### 2.3 What is in the directory

A Nibble site is one repository, and the line through it is simple:

```
tidewater/
├── vendor/nibble/       Nibble's — replaced whole by each release, starter theme crumbs included
├── site/schema/         yours: collections, blueprints, forms…
├── site/content/        yours: content kept as files
├── site/themes/         yours: your own theme
├── site/cp/             yours: Control Plane overrides
├── config/nibble.yml    yours: how the site behaves
├── app/, test/          yours: your own Rails code and tests, if you ever need any
└── Gemfile, config/…    yours: the application around Nibble
```

> [!IMPORTANT]
> **Everything under `vendor/nibble/` is Nibble's; everything else is yours.** Keep to that and an upgrade never has
> anything to refuse. [Upgrading](../running/upgrading.md) explains why.

## 3. A theme of its own

`crumbs` belongs to Nibble, and an upgrade replaces it. Tidewater needs a theme it owns:

```sh
bin/rails nibble:generate:theme tidewater
```

This copies `crumbs` into `site/themes/tidewater`, renames its npm package to `@nibble-theme/tidewater` and registers it
with npm, and changes `theme:` in `config/nibble.yml` to `tidewater`. Commit `package-lock.json` along with the
theme — it now knows about the new package.

From now on every view, style and component you change lives in `site/themes/tidewater/`. Restart `bin/dev` so
Vite picks up the new theme, and change something in `site/themes/tidewater/styles/theme.css` to watch it arrive.

> [!WARNING]
> Never edit `vendor/nibble/themes/crumbs/` to style your site. It is replaced on upgrade, and an upgrade refuses to
> go ahead while it is changed.

## 4. Landing pages

### 4.1 The home page

Pages are a **collection** — a kind of content — that Nibble ships ready to use. A page's fields come from its
**blueprint**, and the one in your theme gives a page a title, an intro and a list of **blocks**: text, quotes,
calls to action, images and galleries, in any order.

In the Control Plane, open **Pages** and choose **New page**:

1. Title: **Invoicing that gets you paid**.
2. Slug: **home**. The top-level page whose slug is `home` answers at `/`.
3. Under **Page blocks**, add a **Text** block with two sentences about Tidewater, then a **Call to action**
   with the heading "Try it free for 30 days", the button label "Start free trial" and a link.
4. Choose **Publish**.

Open `http://localhost:3100/` and the page is there. Nothing was written in code: the collection, the blueprint and
the views already existed. Your marketing team can build every landing page Tidewater needs the same way, without
you.

### 4.2 A block of your own: pricing

A pricing table is not one of the blocks `crumbs` ships, so you add one. A block is two things: a **set** in the
blueprint — the fields an editor fills in — and a **view** that draws it.

Open `site/themes/tidewater/schema/blueprints/collections/pages/page.yml`. Its `blocks` field points at Nibble's
standard list of blocks:

```yaml
- handle: blocks
  field: nibble::page_fields.blocks
```

Replace that line with a copy of the `blocks` field from `vendor/nibble/core_schema/fieldsets/page_fields.yml`, and add
a `pricing` set to its `content` group:

```yaml
- handle: blocks
  field:
    type: replicator
    display: Page blocks
    button_label: Add block
    sets:
      content:
        display: Content
        sets:
          # rich_text, quote and cta, exactly as you copied them
          pricing:
            display: Pricing
            icon: layout-grid
            fields:
              - handle: plans
                field:
                  type: grid
                  add_row: Add plan
                  fields:
                    - handle: name
                      field: { type: text, required: true }
                    - handle: price
                      field: { type: text, required: true, instructions: "Per month, e.g. $19" }
                    - handle: features
                      field: { type: list }
      # media, exactly as you copied it
```

> [!WARNING]
> Keep every set you copied. Pages already use them — the example content does — and a set that disappears from
> the blueprint strands the blocks written with it. `nibble:check` refuses that, and says which pages it would
> affect.

Then draw it. Each set renders through `views/sets/<set handle>.vue`, receiving the set's fields as props:

```vue
<!-- site/themes/tidewater/views/sets/pricing.vue -->
<script setup lang="ts">
defineProps<{ plans: { name: string; price: string; features: string[] | null }[] }>()
</script>

<template>
  <section class="grid gap-6 sm:grid-cols-3">
    <div v-for="plan in plans" :key="plan.name" class="rounded-lg border p-6">
      <h3 class="text-xl font-semibold">{{ plan.name }}</h3>
      <p class="mt-2 text-3xl">{{ plan.price }}<span class="text-base"> / month</span></p>
      <ul class="mt-4 space-y-1">
        <li v-for="feature in plan.features ?? []" :key="feature">{{ feature }}</li>
      </ul>
    </div>
  </section>
</template>
```

Regenerate the theme's TypeScript types, which now include the pricing block, and check the schema:

```sh
bin/rails nibble:schema:types
bin/rails nibble:check
```

Restart `bin/dev`, since `pricing.vue` is a new file. Now create a page titled **Pricing** with the slug `pricing`,
add a **Pricing** block with three plans, and publish it. It answers at `/pricing`.

> [!TIP]
> Blocks are how a startup's site stays flexible. Marketing rearranges pages and writes new ones on its own; a
> developer is only needed when a new *kind* of block is. See [Blueprints and fields](../modelling/blueprints.md).

## 5. The blog

The `posts` collection is also ready: posts live at `/blog/<slug>`, carry a publish date, and your theme gives them
authors and topics.

In the Control Plane, add an author under **Authors** and a topic or two under **Topics** — both are in the sidebar,
under Content. Then open **Posts** and choose **New post**, pick its author and topics, and publish it. It answers at
`/blog/<its slug>`.

Tidewater also wants `/blog` itself to list every post, an Atom feed, and the collection called "Blog" in the
Control Plane. A collection's settings are a file, and to
change Nibble's you write your own version of it in `site/schema/`. Create `site/schema/collections/posts.yml`:

```yaml
schema: 1
title: Blog
route: /blog/{slug}
index_route: /blog
index_template: posts/index
dated: true
blueprints: [post]
template: posts/show
sort: published_at:desc
feed:
  title: The Tidewater blog
```

> [!IMPORTANT]
> A file in `site/schema/` **replaces** the file of the same name from Nibble or your theme — it does not merge into
> it. That is why this one repeats the route and template. See [Modelling content](../modelling/index.md).

`/blog` now renders the theme's `posts/index` view, which lists posts twelve to a page, and the sidebar says
**Blog** — its button to write one now reads **New blog**, since the label is made from the title. The feed is at
`/feed-posts.xml`, and `/feed.xml` combines every collection that has one.

## 6. The help centre, as files

Tidewater's help articles are written in the product's own repository, reviewed in the same pull requests as the
features they describe. Those articles should not live in a database at all: Nibble can serve a folder of
Markdown as a collection.

### 6.1 Declare the collection

```yaml
# site/schema/collections/help.yml
schema: 1
title: Help centre
route: /help/{slug}
structure:
  max_depth: 3
blueprints: [article]
template: help/show
sort: position:asc
files: help
```

```yaml
# site/schema/blueprints/collections/help/article.yml
schema: 1
title: Article
tabs:
  main:
    sections:
      - fields:
          - handle: title
            field: { type: text, required: true }
          - handle: description
            field: { type: textarea }
          - handle: body
            field: { type: markdown }
```

```yaml
# site/schema/navigation/help.yml
schema: 1
title: Help centre
max_depth: 3
```

`files: help` points the collection at `site/content/help/`. The navigation shares its handle, so its tree is built from
the folders — that is the help centre's sidebar.

### 6.2 Write the files

```
site/content/help/
├── index.md                 /help
├── getting-paid/
│   ├── index.md             /help/getting-paid
│   └── reminders.md         /help/getting-paid/reminders
└── importing-clients.md     /help/importing-clients
```

Every page starts with frontmatter. `id` is required and never changes — it is what links and search hold on to:

```markdown
---
id: payment-reminders
title: Payment reminders
description: Send reminders automatically when an invoice is overdue.
order: 2
---

Tidewater can chase overdue invoices for you. Turn reminders on under **Settings → Reminders**, and see
[Getting paid](index.md) for how payments are matched.
```

A link to another `.md` file becomes a link to that page, wherever it ends up.

### 6.3 A view for it

```sh
bin/rails nibble:generate:view help/show --collection=help
```

This writes `site/themes/tidewater/views/help/show.vue` and `show.yml`, a query sidecar asking for a list of articles.
An article page needs nothing but itself, so delete `show.yml`, and fill the view in:

```vue
<script setup lang="ts">
import { RichText, useNavigation } from '@nibble'
import type { ViewProps, HelpArticle } from '@site/types'

defineProps<ViewProps['help/show'] & { page: HelpArticle }>()
const sidebar = useNavigation('help')
</script>

<template>
  <div class="grid gap-10 md:grid-cols-[14rem_1fr]">
    <nav>
      <ul>
        <li v-for="link in sidebar" :key="link.url">
          <a :href="link.url">{{ link.title }}</a>
          <ul v-if="link.children.length">
            <li v-for="child in link.children" :key="child.url"><a :href="child.url">{{ child.title }}</a></li>
          </ul>
        </li>
      </ul>
    </nav>
    <article>
      <h1>{{ page.title }}</h1>
      <RichText :value="page.body" />
    </article>
  </div>
</template>
```

### 6.4 Build and look

Deleting the sidecar changed what the view receives, so regenerate the theme's types, then build:

```sh
bin/rails nibble:schema:types
bin/rails nibble:build
```

`nibble:build` checks every file against its blueprint and refuses a page with no `id`, bad frontmatter, a field the
blueprint does not have, or a folder with no `index.md`. It prints `content: 4 page(s) in 1 collection(s)`.

Restart `bin/dev` — the view is a new file — and open `/help/getting-paid/reminders`. The sidebar shows the folders,
and the link to `index.md` has become a link to `/help/getting-paid`.

### 6.5 Make it searchable

A collection joins a search index with its own `search:` key. Pages and posts are in the `site` index; add one line
to the help centre's collection file to put it there too:

```yaml
# site/schema/collections/help.yml
search: site
```

`search.yml` chooses what an index searches. Tidewater's, in `site/schema/`, adds the fields its blueprints use:

```yaml
# site/schema/search.yml
schema: 1
indexes:
  site:
    fields: [title, intro, excerpt, description, body, blocks]
```

```sh
bin/rails nibble:search:rebuild
```

Search keeps itself current from now on: an entry is indexed when it is published, and a help article on every
deploy and, in development, as soon as its file changes.

> [!NOTE]
> There is no import step. The folder *is* the collection: the site reads it when it boots and, in development,
> whenever a file changes. In the Control Plane the help centre is listed and each article opens read-only, naming
> its file. See [Content as files](../modelling/content-as-files.md).

## 7. The demo form

### 7.1 Declare it

```yaml
# site/schema/forms/demo.yml
title: Book a demo
fields:
  - handle: name
    field: { type: text, display: Your name, required: true }
  - handle: email
    field: { type: text, input_type: email, display: Work email, required: true }
  - handle: team_size
    field:
      type: select
      display: Team size
      options: { solo: Just me, small: 2–10, large: More than 10 }
notify:
  - to: sales@tidewater.example
    reply_to: email
success:
  message: Thanks — we'll be in touch within a working day.
```

Submissions are stored, emailed to sales with replies going to the person who asked, and listed under **Forms**
in the Control Plane.

### 7.2 Put it on a page

A view asks for a form in its query sidecar. Create a view for the demo page:

```yaml
# site/themes/tidewater/views/demo.yml
form:
  from: form:demo
```

```vue
<!-- site/themes/tidewater/views/demo.vue -->
<script setup lang="ts">
import type { NibbleForm } from '@nibble'
import ContactForm from '../components/ContactForm.vue'

defineProps<{ page: { title: string }; form: NibbleForm }>()
</script>

<template>
  <h1>{{ page.title }}</h1>
  <ContactForm :form="form" />
</template>
```

`ContactForm` came with the theme you copied; it renders any form's fields, handles errors and shows the success
message. Its button says "Send message" — change that in `site/themes/tidewater/components/ContactForm.vue` if you like.

Restart `bin/dev` for the new view, then create a page titled **Book a demo** with the slug `demo`, set its
**Template** to `demo` in the sidebar, and publish. Fill the form in at `/demo`: the success message appears, the
submission is listed under **Forms → Book a demo**, and sales gets an email titled "New submission: Book a demo".

> [!WARNING]
> Before this form is public, turn on spam protection. Every form is rate-limited and has a hidden honeypot field,
> but a CAPTCHA is what stops a determined bot. See [Forms](../modelling/forms.md#4-spam).

## 8. Before the first deploy

Run the checks that a deploy would run:

```sh
bin/rails nibble:check    # the schema, theme, roles and settings are sound
bin/rails nibble:build    # every file in site/content/ is valid
```

Then commit everything — `site/`, `config/nibble.yml` and `vendor/nibble` all belong in git.

Deploying is `bin/rails nibble:install --only=deploy` to add the deploy files, then `bin/kamal setup`. The
[Deploying](../running/deploying.md) guide walks through it, including credentials, the storage bucket and what the
container checks before it serves.

> [!CAUTION]
> A new server starts with an empty database. The pages and posts you wrote locally are not in the image: either
> write them again in the production Control Plane, or export them as a
> [content package](../running/content-packages.md) and import it once. Only the help centre, which is files,
> arrives with the code.

## 9. What's next

- [Modelling content](../modelling/index.md) — everything a collection, blueprint or form can declare.
- [Building a theme](../theming/index.md) — views, queries and components in depth.
- [Editing content](../editing/index.md) — hand this to your marketing team.
- [Running a site](../running/index.md) — configuration, people, backups and upgrades.
