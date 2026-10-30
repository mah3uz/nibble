---
id: theming-forms
title: Forms in your theme
description: Draw a form from an empty theme to a working, accessible one, field by field, then look up every key of the
  form definition, every field setting and everything useNibbleForm returns.
order: 5
---

# Forms in your theme

Tidewater's "Book a demo" form is declared in YAML, as [Forms](../modelling/forms.md) describes. This guide is the
theme's half: how the form reaches a view, how each field is drawn, and how the composable `useNibbleForm` does the
rest — values, conditions, posting, errors, the honeypot, the CAPTCHA, steps and the success message.

After reading this guide, you will know:

- How to get a form into a view and draw a first working form.
- How to draw every public field type, and what each one's settings mean.
- How to wire the honeypot, the CAPTCHA, conditions, hidden fields, files, steps, Save and finish later and
  calculations.
- How to translate a form, type its values, and check that it is accessible.
- Every key of the form definition and of a field, and every member `useNibbleForm` returns (sections 16 to 18).
- What a complete, small stepped form component looks like (section 19).

The working example is `themes/crumbs/components/ContactForm.vue`. It draws every public field type and uses every
feature below, so it serves any form as it is: copy it into your theme, or read it beside this guide and start from
it rather than from scratch. Section 19 is a smaller component you can write from this guide alone.

## 1. Getting the form into a view

A view asks for a form in its query sidecar, and receives its definition as a prop:

```yaml
# site/themes/tidewater/views/demo.yml
form:
  from: form:demo
```

```vue
<!-- site/themes/tidewater/views/demo.vue -->
<script setup lang="ts">
import type { NibbleForm } from '@nibble'
import DemoForm from '@theme/components/DemoForm.vue'

defineProps<{ form: NibbleForm }>()
</script>

<template>
  <DemoForm :form="form" />
</template>
```

The view only renders once a page uses it. In the Control Plane, create a page, choose the view as its **Template**
and publish; [the tutorial](../getting-started/tutorial.md#72-put-it-on-a-page) walks through it. A collection whose
entries should all use the view names it as `template:` in its schema instead.

`form` is the definition the server builds for the visitor's request: the fields with their settings resolved, the
action to post to, the honeypot, the CAPTCHA, the success message and more. Section 16 lists every key. A page showing a
form that is scheduled, limited, has a `min_seconds` or is opened from a resume link is rendered for each visit rather
than kept in the page cache.

## 2. A first working form

`useNibbleForm(form)` takes the definition and returns what a component needs. This is the smallest form that
works, drawing every field as a text input:

```vue
<!-- site/themes/tidewater/components/DemoForm.vue -->
<script setup lang="ts">
import { useNibbleForm, type NibbleForm } from '@nibble'

const props = defineProps<{ form: NibbleForm }>()
const demo = useNibbleForm(props.form)
</script>

<template>
  <p v-if="demo.sent.value" :ref="(el) => (demo.messageEl.value = el as HTMLElement)" role="status" tabindex="-1">
    {{ demo.message.value }}
  </p>
  <form v-else :action="form.action" method="post" novalidate @submit="demo.submit">
    <template v-for="field in form.fields" :key="field.handle">
      <div>
        <label :for="demo.inputId(field)">{{ field.display }}</label>
        <input :id="demo.inputId(field)" v-model="demo.values[field.handle] as string" :name="demo.fieldName(field)" />
      </div>
    </template>
    <button type="submit" :disabled="demo.processing.value">Book my demo</button>
  </form>
</template>
```

- `:action="form.action"` and `method="post"` make the form work without JavaScript: the browser posts it, and a
  failed post returns to the page with `form.result` filled in (section 3).
- `@submit="demo.submit"` takes over once the page is running. It posts the values with `fetch`, shows errors without
  leaving the page, and on success sets `sent` and `message`. If the form's `success` has a `redirect`, it goes there
  instead: an on-site path as a visit, anything else as a page load.
- `novalidate` turns the browser's own validation bubbles off, so the server's messages, which are translated and
  consistent, are what the visitor reads. `isRequired(field)` still lets you mark fields `required` for assistive
  technology.
- `fieldName(field)` is the input `name` Nibble expects: the handle, or `handle[]` for checkboxes, files and a multiple
  select.
- `values` is a reactive map of field handle to value, already filled from `default`, from a failed post, or from a
  resume link.
- `submit_label` is the form's own text for the send button; use `form.submit_label || 'Send'`.

## 3. Fields, help and errors

Give every field a label, its help text and its error, and link them with the ids `useNibbleForm` makes (unique to the
form, so two forms on a page don't clash):

```vue
<div>
  <label :for="demo.inputId(field)">{{ field.display }}</label>
  <input
    :id="demo.inputId(field)"
    v-model="demo.values[field.handle] as string"
    :name="demo.fieldName(field)"
    :required="demo.isRequired(field)"
    :aria-describedby="demo.describedBy(field)"
    :aria-invalid="demo.errors.value[field.handle] ? 'true' : undefined"
  />
  <p v-if="field.instructions" :id="demo.helpId(field)">{{ field.instructions }}</p>
  <p v-if="demo.errors.value[field.handle]" :id="demo.errorId(field)">{{ demo.errors.value[field.handle] }}</p>
</div>
```

`describedBy(field)` returns the help id when the field has instructions or file limits, and the error id when it has
an error, or `undefined`. Draw the help element whenever `field.instructions` is set (or, for a `files` field, when
`fileLimits(field)` is).

A failed submission puts messages in `errors`, by field handle, with `base` for an error about the form as a whole (a
rate limit, a CAPTCHA, a network failure). For a summary at the top, use `errorList`, the field errors in form order
with a `label`, `message` and an `href` to the input, and give the container to `summaryEl`:

```vue
<div v-if="Object.keys(demo.errors.value).length" :ref="(el) => (demo.summaryEl.value = el as HTMLElement)" tabindex="-1">
  <p>{{ demo.errors.value.base ?? 'Please check these answers:' }}</p>
  <ul>
    <li v-for="error in demo.errorList.value" :key="error.handle">
      <a :href="error.href" @click="f.goToField(error.handle, $event)">{{ error.label }}: {{ error.message }}</a>
    </li>
  </ul>
</div>
```

`summaryEl` and `messageEl` are focused when they appear, so give each `tabindex="-1"`. A visitor who submits with a
keyboard lands on the list of what to fix, and each link jumps to its input.

After a failed post without JavaScript, `form.result` is `{ status: 'invalid', errors, values }`, where `values` are the
plain values the visitor typed, by field handle. `errors` and `values` start from them, so the page redraws with the
messages and the answers in place. Files are never kept: the visitor attaches them again.

`sections` is `null` for a form with one list of fields. For a sectioned form it is a list of
`{ display, instructions, fields }`, where `fields` are handles. Draw each as a `fieldset` with a `legend`:

```ts
const byHandle = new Map(props.form.fields.map((field) => [field.handle, field]))
const groups = props.form.sections?.map((section) => ({
  ...section,
  fields: section.fields.flatMap((handle) => byHandle.get(handle) ?? []),
}))
```

## 4. The honeypot and the CAPTCHA

Every form has a honeypot, a hidden text input people never fill in and bots usually do. `form.honeypot` is its name
(`null` when the form turned it off). Bind it to `trap`:

```vue
<input
  v-if="form.honeypot"
  v-model="demo.trap.value"
  :name="form.honeypot"
  type="text"
  tabindex="-1"
  autocomplete="off"
  aria-hidden="true"
  class="absolute -left-[9999px] h-px w-px overflow-hidden"
/>
```

Hide it visually, never with `display: none` or `hidden`, which some bots skip. `tabindex="-1"`, `autocomplete="off"`
and `aria-hidden="true"` keep keyboards, screen readers and autofill away from it.

`form.captcha` is `null` unless the form asks for one. With `captcha: true` in the form's `spam`, it is
`{ provider, site_key }`, where `provider` is `'turnstile'` or `'recaptcha'`, and a `null` provider means the site
hasn't set a CAPTCHA up, so the form refuses everyone. `unavailable` from `useNibbleForm` is true then: show
`form.messages.unavailable` (the text the server refuses with) above the form and disable the submit button, so a visitor
isn't left to type a message that can't be sent. Give the composable an empty element to draw into:

```vue
<div :ref="(el) => (demo.captchaEl.value = el as HTMLElement | null)" />
```

`useNibbleForm` loads the provider's script once the component mounts, draws Turnstile's widget into `captchaEl`, or
runs reCAPTCHA v3 invisibly when the form is sent, and posts the token as `_captcha`. It resets the widget after every
post. Do not load the script yourself.

A form with `min_seconds` has a signed `form.timestamp`, which `useNibbleForm` posts as `_nibble_t`. A form posted
without JavaScript needs it as a hidden input of that name:

```vue
<input v-if="form.timestamp" type="hidden" name="_nibble_t" :value="form.timestamp" />
```

See [Spam](../modelling/form-spam-and-privacy.md#1-spam) for the checks themselves.

## 5. Conditions and conditional required

A field with a condition carries `conditions`, the rules for when to draw it:

```json
{ "show": true, "match": "all", "rules": [{ "field": "kind", "operator": "equals", "value": "business" }] }
```

`isVisible(field)` evaluates them over the current values as the server does; wrap the field in
`v-if="demo.isVisible(field)"`. `submit` leaves a field its conditions hide out of what it posts, and the server applies
them again to what arrives. A `custom` rule runs only on the server, so `isVisible` draws its field. The operators are
listed in [Forms](../modelling/forms.md#1-declaring-a-form).

A field's `required` is `true`, `false`, or, when the schema gave it a condition, an object in the shape of
`conditions`. `isRequired(field)` answers for the current values, so use it for the `*` marker and the `required`
attribute and don't read `field.required` directly. A `custom` rule can't run in the browser, so `isRequired` treats that
field as optional and the server decides.

```vue
<label :for="demo.inputId(field)">
  {{ field.display }}<span v-if="demo.isRequired(field)" aria-hidden="true"> *</span>
  <span v-if="demo.isRequired(field)" class="sr-only"> (required)</span>
</label>
```

Say once, near the top, what `*` means ("Fields marked * are required."), and show that line only when some visible
field is required. The `required_note` and `required` entries of `messages` are that line and the screen-reader text
(section 13).

## 6. Hidden and prefilled fields

A field with `hidden: true` is not for the visitor. It carries the `value` resolved for the current request (its
`default` is the same): the schema's fixed `value`, or a value read from a query parameter the field names with
`prefill`. `form.action` already carries the prefilled query, so a form posted without JavaScript records it too.
Draw a hidden input and nothing else, with no label:

```vue
<input v-if="field.hidden" :id="demo.inputId(field)" type="hidden" :name="demo.fieldName(field)" :value="demo.values[field.handle]" />
```

`submit` posts a hidden field like any other that is visible. A `files` field can't be hidden.

## 7. Drawing each field type

Every field has a `handle`, a `type`, a `display` (its label), `instructions` and `required`. `NibbleFormField` is a
union on `type`, so `field.type === 'select'` narrows to `field.options` without a cast. Section 17 lists every setting.
Branch on `field.type` and draw each with the control below. Always label it with `inputId(field)` (or a `fieldset` and
`legend` for a group of inputs), link help and errors with `describedBy` and `aria-invalid`, and set `required` from
`isRequired(field)`.

`width` (`25`, `33`, `50`, `66`, `75` or `100`) is how much of a row a field asks for. crumbs lays each section out
on twelve columns from the `sm` breakpoint up, so two `width: 50` fields sit side by side, and keeps one column on a
phone:

```vue
<div class="grid grid-cols-[minmax(0,1fr)] gap-8 sm:grid-cols-12">
  <div v-for="field in fields" :key="field.handle" :class="span(field)">…</div>
</div>
```

where `span` maps `50` to `sm:col-span-6`, `33` to `sm:col-span-4` and so on, and a field with no `width` to
`sm:col-span-full`. Write the class names out in full, so Tailwind finds them.

**Text.** An `<input>` with `type` from `input_type` (`text` by default, and `email`, `url`, `tel`, `number`, `date`,
`month`, `week`, `time`, `color` and `password` are the other types a text field may name; see [the
fieldtypes](../modelling/blueprints.md#3-the-fieldtypes)). The server checks `email`, `url` and `tel` values, so draw
them as that type, which gives phones the right keyboard. Bind `placeholder`, `character_limit` as `maxlength`,
`autocomplete`, and draw `prepend` and `append` beside the input.

```vue
<span v-if="field.prepend">{{ field.prepend }}</span>
<input
  :id="demo.inputId(field)"
  v-model="demo.values[field.handle] as string"
  :type="field.input_type ?? 'text'"
  :name="demo.fieldName(field)"
  :maxlength="field.character_limit"
  :placeholder="field.placeholder"
  :autocomplete="field.autocomplete"
/>
<span v-if="field.append">{{ field.append }}</span>
```

**Textarea.** `<textarea>` with `rows` (default to 6 or so), `placeholder` and `character_limit` as `maxlength`.

**Integer.** `<input type="number" inputmode="numeric">` with `min`, `max` and `step`, and `prepend` and `append`.
The server refuses a value off the step, counted from `min` (or 0).

**Decimal.** `<input type="number" inputmode="decimal">` with `min`, `max`, and `step` set to the field's `step`, or
`10 ** -decimals` (`decimals` is 0 to 10, default 2) when it has none, so the browser accepts the places the server
keeps.

**Range.** `<input type="range">` with `min` (default 0), `max` (default 100) and `step` (default 1), and an `<output>`
beside it showing the value. Without a `default` the value starts at `min`, so a range always posts a number.

```vue
<input :id="demo.inputId(field)" v-model="demo.values[field.handle]" type="range" :name="demo.fieldName(field)"
  :min="field.min ?? 0" :max="field.max ?? 100" :step="field.step ?? 1" />
<output :for="demo.inputId(field)">{{ demo.values[field.handle] }}</output>
```

**Rating.** A `fieldset` with a `legend` holding one radio input for each number from 1 to `max` (2 to 10, default 5),
each with a label a screen reader hears as "3 of 5". Style the labels as stars. Choosing none leaves it unrated.

```vue
<fieldset :aria-describedby="demo.describedBy(field)">
  <legend>{{ field.display }}</legend>
  <label v-for="n in field.max ?? 5" :key="n">
    <input v-model="demo.values[field.handle]" type="radio" :name="demo.fieldName(field)" :value="n" />
    <span aria-hidden="true">&#9733;</span>
    <span class="sr-only">{{ n }} of {{ field.max ?? 5 }}</span>
  </label>
</fieldset>
```

**Toggle.** A single checkbox with `value="true"`; its value in `values` is a `boolean`. `inline_label` is the text
beside it (plain text); draw `field.display` above it as a heading when `inline_label` is set, and the label text is
`inline_label` or, without one, `display`. A consent box is a required toggle. When the label has links, the server
sends `inline_label_html` as well, holding only links with `href`, `target="_blank"` and `rel="noopener noreferrer"` (they open in a new tab, so the visitor keeps their answers); draw it inside the checkbox's
`<label>` instead of `inline_label`:

```vue
<input :id="demo.inputId(field)" v-model="demo.values[field.handle]" type="checkbox" :name="demo.fieldName(field)" value="true" />
<label :for="demo.inputId(field)">
  <span v-if="field.inline_label_html" v-html="field.inline_label_html" />
  <template v-else>{{ field.inline_label || field.display }}</template>
</label>
```

`inline_label_html` is sanitized by the server, which is why it is safe for `v-html`.

**Select.** A `<select>` over `options` (each `{ value, label }`). Without `multiple`, draw an empty first option
(`placeholder`, or "Choose one…" from `messages.choose`), disabled when the field is required. With `multiple`, the
value is an array, `max_items` limits how many, and the name is `handle[]`. `clearable` says the visitor may unchoose.

**Radio.** A `fieldset` and `legend`, and one radio per option. `inline` asks for the options in a row.

**Options narrowed by another choice.** A choice field with a [`parent`](../modelling/forms.md#15-choices-from-content)
names the field it follows, and each of its options (a `NibbleFormOption`) carries `parents`. Draw `demo.options(field)` instead of
`field.options` for every choice field: it is the options that fit the parent's current answers, and every option
until the page has JavaScript, so a visitor without it can still choose and the server checks the pairing. When the
parent's answer changes, `useNibbleForm` clears a child answer that no longer fits. `optionsFor(field, values)` from
`@nibble` gives the same list for any values.

**Button group.** The same values as a radio (it is typed as one); draw the options as joined buttons, each a radio
input hidden visually, with a visible label that shows the checked state.

**Checkboxes.** A `fieldset` and `legend`, and one checkbox per option, named `handle[]`; the value is an array of the
checked option values. `inline` asks for a row.

**Date.** `<input type="date">`, or `datetime-local` when `time_enabled`. Bind `earliest_date` and `latest_date` as
`min` and `max` (as `YYYY-MM-DD`, or `YYYY-MM-DDT00:00` and `T23:59` for a date-time). When `time_zone` is set (an IANA
name such as `Australia/Sydney`), the server reads the time typed in that zone and a page receives a stored value in it,
with its offset; say so beside the label, such as "Time (Australia/Sydney)", so the visitor knows whose clock it is.

**Time.** `<input type="time">`, with `step="1"` when `seconds` is true, and `earliest` and `latest` as `min` and `max`
(as `"09:00"`).

**Colour.** `<input type="color">`, with its `swatches` (lowercase `#rrggbb`) offered through a `<datalist>`. When
`allow_any` is `false`, only the swatches are allowed: draw them as swatch radios instead, with the colour shown and its
value as the label.

**Files.** An `<input type="file">`; see section 8.

**Calculation.** Read-only output, not an input; see section 11.

**Note.** `text_html` is the note's Markdown, rendered and sanitized by the server. Draw it as a block of text, not an
input. It has no value in `values` and posts nothing.

```vue
<div v-else-if="field.type === 'note'" v-html="field.text_html" />
```

`default` is already resolved, so a computed default is a date, not a name, and `values` starts from it.

## 8. Files

A `files` field takes `max_files`, `max_file_size` (in MB) and `extensions` (lower case, without the dot). Draw an
`<input type="file">`, bind `accept(field)` for the extensions, `multiple` when `max_files` is above 1, and hand the
chosen files to the composable with `setFiles`, which keeps them in `values` as a `File[]`:

```vue
<input
  :id="demo.inputId(field)"
  type="file"
  :name="demo.fieldName(field)"
  :accept="demo.accept(field)"
  :multiple="(field.max_files ?? 1) > 1"
  :aria-describedby="demo.describedBy(field)"
  @change="demo.setFiles(field.handle, $event)"
/>
<p v-if="demo.fileLimits(field)" :id="demo.helpId(field)">{{ demo.fileLimits(field) }}</p>
```

`fileLimits(field)` describes what is allowed, such as "PDF or JPG, up to 5 MB each, at most 3 files.", and
`describedBy` includes the help id for it. Show it so the visitor knows the limits before choosing. The form needs
`enctype="multipart/form-data"` to post files without JavaScript. A request too large to send shows `messages.too_large`
as the `base` error. An error on one file comes back as `handle.0`, and `errorList` links it to the field.

## 9. Steps

A form with `steps: true` has `form.steps` true, and each of its `sections` is a step. Until the component mounts,
`stepping` is false and `isCurrentStep` is true for every section, so the server draws every step and a visitor without
JavaScript fills in one long form. Once mounted, draw only the section where `isCurrentStep(index)` holds, with
`v-show` so a file a visitor chose stays chosen, and a heading on `stepEl` such as "Step 2 of 4":

```vue
<div v-if="demo.stepping.value">
  <p :ref="(el) => (demo.stepEl.value = el as HTMLElement | null)" tabindex="-1">
    Step {{ demo.step.value + 1 }} of {{ demo.steps.value.length }}
  </p>
  <progress :value="demo.progress.value" max="1" />
</div>

<fieldset v-for="(section, index) in groups" v-show="demo.isCurrentStep(index)" :key="index"> ... </fieldset>

<button v-if="demo.stepping.value && demo.step.value > 0" type="button" @click="demo.back">Back</button>
<button type="submit" :disabled="demo.processing.value">{{ demo.isLastStep.value ? 'Send' : 'Next' }}</button>
```

`steps` lists the sections that are drawn (each with its `index`), leaving out any whose fields are all hidden by
conditions. `submit` before the last step calls `next`, so one submit button reads Next until then. `next` posts the
current step to the server for checking: it moves on, or stays and shows that step's errors. `back` goes back without a
check. When a refused send has errors in another step, the form opens the step with the first error.

## 10. Save and finish later

A form with `resume: true` has `form.resume`, `{ email, days, token }`: the handle of the field that takes the visitor's
address, how many days the link works, and the token when the page was opened from a resume link. Draw a button that
calls `saveForLater`, and a status element for `saved` that is on the page before it fills, so a screen reader
announces it. Give that element to `savedEl` with `tabindex="-1"`: it takes focus once the save is done:

```vue
<button v-if="form.resume" type="button" :disabled="demo.processing.value" @click="demo.saveForLater">
  Save and finish later
</button>
<p role="status">{{ demo.saved.value }}</p>
```

Opened from a link (`?resume=<token>`), `form.result` is `{ status: 'resumed', values }`, and `values` starts from
them, so show `form.messages.resumed` as a status line to say they came back (files are never saved); when the link no longer works it is `{ status: 'expired', message }`, which you should show. `submit` sends the
token as `_nibble_resume`, so the save is deleted once the form is sent; a form posted without JavaScript needs the
token as a hidden input:

```vue
<input v-if="form.resume?.token" type="hidden" name="_nibble_resume" :value="form.resume.token" />
```

## 11. Calculations

A `calculation` field carries its `formula`, and its `decimals`, `prepend` and `append` when it has them.
`calculated(field)` runs the formula in the browser with the same rules as the server, over the current `values`, so it
changes as the visitor types; a field `isVisible` hides counts as 0. It is a number, or `null` while it can't be worked
out. `calculatedText(field)` is the figure as text in the site's locale with its `decimals`, `prepend` and `append`,
such as "$1,350.00", or `""` while blank. Draw it as read-only output, and let screen readers hear it change:

```vue
<output :id="demo.inputId(field)" aria-live="polite">{{ demo.calculatedText(field) }}</output>
```

The form posts nothing for it: the server calculates the stored value itself. See
[Calculations](../modelling/forms.md#11-calculations).

## 12. A closed form

`form.closed` is true when the form is outside its `opens_at` and `closes_at`, or has reached `max_submissions`, and
`form.closed_message` is the text to show. Draw the message instead of the form; the server refuses a post to a closed
form anyway.

```vue
<p v-if="form.closed" role="status">{{ form.closed_message }}</p>
<form v-else ...>
```

## 13. Translating a form, and `messages`

On a multilingual site, the definition arrives already in the page's locale: `title`, `display`, `instructions`,
`placeholder`, `inline_label`, option labels, section text, the success message and `submit_label` are text for that
locale (the default's where one is missing). You draw them as they are. See
[Translating a form](../modelling/form-translation.md).

The wording a theme draws that isn't in the schema comes from `form.messages`, which the site can translate under
`nibble.forms.client.*`. `useNibbleForm` uses `too_large`, `generic` and `network` itself. A theme draws the others:

| Key | Default | For |
|---|---|---|
| `choose` | Choose one… | the empty first option of a select |
| `send`, `sending` | Send message, Sending… | the submit button, and while it works |
| `next`, `checking` | Next, Checking… | the button before the last step, and while it checks |
| `back` | Back | going back a step |
| `save_later` | Save and finish later | the save button |
| `step` | Step %{step} of %{total} | the step heading |
| `check_answers` | Please check these answers: | the line above a list of errors |
| `required_note` | Fields marked * are required. | the note about `*` (the first `*` is the marker) |
| `required` | (required) | what a screen reader hears for a required field |
| `resumed` | We've brought back what you saved. Attach any files again. | the status line when `form.result.status` is `resumed`, after a visitor opens their resume link |
| `not_chosen` | Not chosen | beside a colour input that has no value yet, since a colour input shows black until one is picked |
| `unavailable` | This form can't take submissions right now. Please try again later. | the line above a form whose CAPTCHA isn't set up (`unavailable` is true) |

Read them with a fallback, since `messages` is optional in the type:

```ts
const t = (key: NibbleFormMessageKey) => props.form.messages?.[key] ?? FALLBACK[key]
```

## 14. Typed values

A component written for one form can have its values typed. The generated `@site/types` has a type for each form,
named from its handle, with a field for each of its handles, and a view's `form:` query is typed with it, so
`useNibbleForm` knows the values without being told:

```vue
<script setup lang="ts">
import { useNibbleForm } from '@nibble'
import type { ViewProps } from '@site/types'

const props = defineProps<{ form: ViewProps['pages/contact']['contact'] }>()
const contact = useNibbleForm(props.form)
// contact.values.topic is 'sales' | 'support' | ''
</script>
```

Name the type yourself where the form comes from somewhere else: `useNibbleForm<ContactFormValues>(form)`, with
`ContactFormValues` from `@site/types`. `FormValues['contact']` is the same type by form handle. A select or radio field
is its option values, and `''` until something is chosen; checkboxes and a multiple select are arrays of them; a button
group is typed as a radio; a toggle is a `boolean`; a `files` field is `File[]`; and an `integer`, `decimal`, `range`,
`rating` or `calculation` field is a string, a number or `null`. A component that handles any form, taking a plain
`NibbleForm`, gets values of `string`, `number`, `boolean`, arrays or `null` and narrows them as before.

## 15. An accessibility checklist

- Every input has a visible `<label for>` made with `inputId(field)`. A group of inputs (radio, checkboxes, button
  group, rating, swatches) is a `fieldset` with a `legend`.
- Required is shown in text a screen reader hears, not only by a coloured or `aria-hidden` `*`; say what `*` means once.
- Help and errors are linked with `aria-describedby="demo.describedBy(field)"` and the input has `aria-invalid` while it
  has an error.
- The error summary has `tabindex="-1"` on `summaryEl` and no `role="alert"`: it takes focus when it appears, so a role
  would have it read twice. It links to each input with `errorList`, and each link calls `goToField(handle, $event)`, which
  opens the step that holds the field and focuses it.
- The success message is on `messageEl` with `role="status"` and `tabindex="-1"`, and `saved` and calculations are
  live regions (`role="status"`, `aria-live="polite"`) that are on the page before they fill.
- The honeypot is hidden from keyboards, screen readers and autofill (`tabindex="-1"`, `aria-hidden="true"`,
  `autocomplete="off"`), and moved off the page, not removed from it.
- Use the right input type and `autocomplete` for text fields, so phones show the right keyboard and browsers fill
  correctly.
- With a stepped form, the heading on `stepEl` says which step it is, and moving between steps moves focus there.
- Buttons are real `<button>`s, disabled with `processing` while a post is in flight; Back is `type="button"`.
- A form works without JavaScript: keep `:action`, `method="post"`, `enctype` for files, hidden inputs for `_nibble_t`
  and `_nibble_resume`, and draw every step until `stepping` is true.
- Don't rely on colour alone for the checked state of stars, joined buttons and swatches.

## 16. The form definition

Every key of `form`:

| Key | Holds |
|---|---|
| `handle` | the form's handle |
| `title` | its title, or `null` |
| `action` | where to post, `/forms/<handle>`, with the prefilled query of its hidden fields |
| `honeypot` | the honeypot input's name, or `null` when it is off |
| `captcha` | `null` for a form with no CAPTCHA, else `{ provider, site_key }`; the provider is `'turnstile'`, `'recaptcha'`, or `null` when the site hasn't set one up |
| `fields` | every field, flat and in order, whether or not the form has sections (section 17) |
| `sections` | `null` for one list, else `{ display, instructions, fields }` for each, where `fields` are handles |
| `steps` | true when each section is a step |
| `resume` | `null`, or `{ email, days, token }` for Save and finish later |
| `success` | `{ message, redirect }`, either of which may be missing |
| `messages` | the client wording by key: `too_large`, `generic`, `network`, `choose`, `send`, `sending`, `next`, `checking`, `back`, `save_later`, `step`, `check_answers`, `required_note` and `required` |
| `submit_label` | the send button's text, or `null` |
| `closed` | true while the form is outside its schedule or full |
| `closed_message` | what to show instead of a closed form, else `null` |
| `timestamp` | a signed value to post as `_nibble_t`, for a form with `min_seconds`, else `null` |
| `result` | `null`, or the outcome of the last post or resume: `{ handle, status, message, errors, values }` where `status` is `'sent'`, `'invalid'`, `'resumed'` or `'expired'` |

A section is `{ display, instructions, fields }`. A result's `errors` are messages by field handle, and its `values`
are the plain values typed or restored, by field handle.

## 17. Every field key

Every field has these:

| Key | Holds |
|---|---|
| `handle`, `type` | the field's handle, and its type |
| `display` | its label, in the page's locale |
| `instructions` | its help text, or `null` |
| `required` | `true` or `false`, or a condition object when required depends on other answers; use `isRequired(field)` |
| `conditions` | when to draw it, `{ show, match, rules }`; absent for an unconditional field |
| `default` | its starting value, resolved; absent when it has none |
| `width` | how much of a row it takes (`25`, `33`, `50`, `66`, `75` or `100`) as a hint for layout |
| `hidden`, `value` | a hidden field, and its resolved value; see section 6 |

The rest depend on the type, and are absent unless the schema set them:

| Type | Keys |
|---|---|
| `text` | `placeholder`, `input_type`, `character_limit`, `autocomplete`, `prepend`, `append` |
| `textarea` | `placeholder`, `character_limit`, `rows` |
| `integer` | `placeholder`, `min`, `max`, `step`, `prepend`, `append` |
| `decimal` | `placeholder`, `decimals`, `min`, `max`, `step`, `prepend`, `append` |
| `range` | `min`, `max`, `step`, `prepend`, `append` |
| `rating` | `max` |
| `toggle` | `inline_label`, `inline_label_html` (only when the label has links) |
| `select` | `placeholder`, `options`, `parent`, `multiple`, `max_items`, `clearable` |
| `radio`, `checkboxes` | `options`, `parent`, `inline` |
| `button_group` | `options`, `parent` |
| `date` | `inline`, `time_enabled`, `earliest_date`, `latest_date`, `time_zone` |
| `time` | `placeholder`, `seconds`, `earliest`, `latest` |
| `color` | `swatches`, `allow_any` |
| `files` | `max_files`, `max_file_size`, `extensions` |
| `calculation` | `formula`, `decimals`, `prepend`, `append` |
| `note` | `text_html` |

`options` is a list of `{ value, label }`. `inline` asks for a row of options, and `width` is a layout hint that only a theme can honour.

## 18. What `useNibbleForm` returns

`useNibbleForm(form)` returns these members. Read a ref as `.value`, such as `demo.errors.value`.

**State**

| Member | Holds |
|---|---|
| `values` | a reactive map of field handle to value |
| `errors` | messages by field handle, and `base` for the form as a whole |
| `errorList` | the field errors in form order, each with `handle`, `label`, `message` and an `href` to its input |
| `processing` | true while a submission, step check or save is in flight |
| `unavailable` | true when the form needs a CAPTCHA the site hasn't set up, so nothing it takes can be sent |
| `sent`, `message` | whether the submission succeeded, and the success message |
| `submit`, `reset` | send it; clear it |
| `enhanced` | true once the component has mounted in the browser, so a control that needs JavaScript can wait for it |

**Fields**

| Member | Holds |
|---|---|
| `fieldName(field)` | the input `name` Nibble expects |
| `isVisible(field)` | whether the field's conditions hold for the current values |
| `isRequired(field)` | whether the field is required for the current values |
| `trap` | a ref for the honeypot input's value |
| `captchaEl` | a ref for the element the CAPTCHA draws into |

**Ids and focus**

| Member | Holds |
|---|---|
| `inputId(field)`, `helpId(field)`, `errorId(field)` | the ids for a field's input, its help and its error, unique to the form |
| `describedBy(field)` | the `aria-describedby` for its input |
| `goToField(handle, event)` | for an error link's click: opens the step holding the field and focuses its input |
| `summaryEl`, `messageEl`, `savedEl` | refs for the error summary, the success message and the saved-for-later message; each is focused when it appears, so give it `tabindex="-1"` |

**Steps**

| Member | Holds |
|---|---|
| `stepping` | whether the form is showing one step at a time (a stepped form, mounted, with more than one step to draw) |
| `steps` | the steps, sections with their `index`, leaving out any whose fields are all hidden |
| `step` | the position of the current step |
| `isCurrentStep(index)` | whether section `index` is the one to draw |
| `isLastStep` | whether the current step is the last |
| `progress` | how far along the visitor is, from 0 to 1 |
| `next`, `back` | check the current step with the server and move on, or stay with its errors; go back without a check |
| `stepEl` | a ref for the step heading, focused when the step changes, so give it `tabindex="-1"` |

**Resume**

| Member | Holds |
|---|---|
| `saveForLater` | saves what was entered and emails the visitor a link, for a form with `resume` |
| `saved` | the message to show once it has, else `null` |

**Calculations**

| Member | Holds |
|---|---|
| `calculated(field)` | the current figure, or `null` while it's blank |
| `calculatedText(field)` | the figure as text in the site's locale, with its `decimals`, `prepend` and `append` (`""` while blank) |

**Files**

| Member | Holds |
|---|---|
| `setFiles(handle, event)` | keeps the files chosen in a file input |
| `accept(field)` | the `accept` attribute for a `files` field |
| `fileLimits(field)` | the allowed types, size and count as a sentence, or `null` for other fields |

## 19. A complete stepped form

This component draws any form made of text, textarea, select and toggle fields, with notes and hidden fields. It
has everything sections 2 to 15 teach: an error summary that takes focus, ids linking help and errors to inputs, a
required note, the honeypot, the hidden resume token and timestamp, the CAPTCHA element, steps with a focused heading,
a closed form, and Save and finish later. Add a branch for each other field type you use (section 7).

```vue
<!-- site/themes/tidewater/components/StepForm.vue -->
<script setup lang="ts">
import { computed } from 'vue'
import { useNibbleForm, type NibbleForm, type NibbleFormField } from '@nibble'

const props = defineProps<{ form: NibbleForm }>()
const f = useNibbleForm(props.form)
const { errors, errorList, sent, message, saved, processing, stepping, step, steps, isLastStep, progress, trap } = f

const sections = computed(() => {
  const byHandle = new Map(props.form.fields.map((field) => [field.handle, field]))
  const list = props.form.sections ?? [{ display: null, instructions: null, fields: [...byHandle.keys()] }]
  return list.map((s) => ({ ...s, fields: s.fields.flatMap((handle) => byHandle.get(handle) ?? []) }))
})
const hasRequired = computed(() => props.form.fields.some((field) => f.isVisible(field) && f.isRequired(field)))

const attrs = (field: NibbleFormField) => ({
  id: f.inputId(field),
  name: f.fieldName(field),
  required: f.isRequired(field),
  'aria-describedby': f.describedBy(field),
  'aria-invalid': errors.value[field.handle] ? ('true' as const) : undefined,
})
</script>

<template>
  <p v-if="form.closed" role="status">{{ form.closed_message }}</p>
  <p v-else-if="sent" :ref="(el) => (f.messageEl.value = el as HTMLElement)" role="status" tabindex="-1">
    {{ message }}
  </p>
  <form v-else :action="form.action" method="post" novalidate @submit="f.submit">
    <p v-if="form.result?.status === 'expired'" role="status">{{ form.result.message }}</p>

    <div
      v-if="Object.keys(errors).length"
      :ref="(el) => (f.summaryEl.value = el as HTMLElement)"
      tabindex="-1"
    >
      <p>{{ errors.base ?? form.messages?.check_answers ?? 'Please check these answers:' }}</p>
      <ul>
        <li v-for="error in errorList" :key="error.handle">
          <a :href="error.href">{{ error.label }}: {{ error.message }}</a>
        </li>
      </ul>
    </div>

    <p v-if="hasRequired">{{ form.messages?.required_note ?? 'Fields marked * are required.' }}</p>
    <template v-if="stepping">
      <p :ref="(el) => (f.stepEl.value = el as HTMLElement)" tabindex="-1">
        Step {{ step + 1 }} of {{ steps.length }}
      </p>
      <progress :value="progress" max="1" />
    </template>
    <fieldset v-for="(section, index) in sections" v-show="f.isCurrentStep(index)" :key="index">
      <legend v-if="section.display">{{ section.display }}</legend>
      <p v-if="section.instructions">{{ section.instructions }}</p>
      <template v-for="field in section.fields" :key="field.handle">
        <input v-if="field.hidden" type="hidden" :name="f.fieldName(field)" :value="f.values[field.handle] as string" />
        <div v-else-if="f.isVisible(field)">
          <div v-if="field.type === 'note'" v-html="field.text_html" />
          <template v-else>
            <label :for="f.inputId(field)">
              {{ field.display }}
              <template v-if="f.isRequired(field)">
                <span aria-hidden="true"> *</span><span class="sr-only"> (required)</span>
              </template>
            </label>
            <select v-if="field.type === 'select'" v-bind="attrs(field)" v-model="f.values[field.handle] as string">
              <option value="">{{ field.placeholder || form.messages?.choose || 'Choose one…' }}</option>
              <option v-for="o in field.options" :key="o.value" :value="o.value">{{ o.label }}</option>
            </select>
            <textarea
              v-else-if="field.type === 'textarea'"
              v-bind="attrs(field)"
              v-model="f.values[field.handle] as string"
            />
            <input
              v-else-if="field.type === 'toggle'"
              v-bind="attrs(field)"
              v-model="f.values[field.handle] as boolean"
              type="checkbox"
              value="true"
            />
            <input
              v-else
              v-bind="attrs(field)"
              v-model="f.values[field.handle] as string"
              :type="field.input_type ?? 'text'"
              :autocomplete="field.autocomplete"
            />
          </template>
          <p v-if="field.instructions" :id="f.helpId(field)">{{ field.instructions }}</p>
          <p v-if="errors[field.handle]" :id="f.errorId(field)">{{ errors[field.handle] }}</p>
        </div>
      </template>
    </fieldset>
    <input
      v-if="form.honeypot"
      v-model="trap"
      :name="form.honeypot"
      tabindex="-1"
      autocomplete="off"
      aria-hidden="true"
      style="position: absolute; left: -9999px"
    />
    <input v-if="form.timestamp" type="hidden" name="_nibble_t" :value="form.timestamp" />
    <input v-if="form.resume?.token" type="hidden" name="_nibble_resume" :value="form.resume.token" />
    <div :ref="(el) => (f.captchaEl.value = el as HTMLElement)" />

    <button v-if="stepping && step > 0" type="button" @click="f.back">Back</button>
    <button type="submit" :disabled="processing">{{ isLastStep ? form.submit_label || 'Send' : 'Next' }}</button>
    <button v-if="form.resume" type="button" :disabled="processing" @click="f.saveForLater">
      Save and finish later
    </button>
    <p role="status">{{ saved }}</p>
  </form>
</template>
```

`attrs(field)` collects what every input shares, so each branch states only what differs. A form without `steps` has
`stepping` false, so the same component draws one page and the Next, Back and progress controls never appear.
