<script setup lang="ts">
import { computed } from 'vue'
import { useNibbleForm, type NibbleForm, type NibbleFormField, type NibbleFormMessageKey } from '@nibble'

const props = defineProps<{ form: NibbleForm }>()

const FALLBACK: Record<NibbleFormMessageKey, string> = {
  choose: 'Choose one…',
  send: 'Send message',
  sending: 'Sending…',
  next: 'Next',
  checking: 'Checking…',
  back: 'Back',
  save_later: 'Save and finish later',
  step: 'Step %{step} of %{total}',
  check_answers: 'Please check these answers:',
  required_note: 'Fields marked * are required.',
  required: '(required)',
  resumed: "We've brought back what you saved. Attach any files again.",
  not_chosen: 'Not chosen',
  unavailable: "This form can't take submissions right now. Please try again later.",
}
const t = (key: NibbleFormMessageKey) => props.form.messages?.[key] ?? FALLBACK[key]
const requiredNote = computed(() => t('required_note').split('*'))
const contact = useNibbleForm(props.form)

const groups = computed(() => {
  const byHandle = new Map(props.form.fields.map((field) => [field.handle, field]))
  if (!props.form.sections) return [{ display: null, instructions: null, fields: props.form.fields }]
  return props.form.sections.map((section) => ({
    ...section,
    fields: section.fields.flatMap((handle) => byHandle.get(handle) ?? []),
  }))
})

const hasRequired = computed(() =>
  props.form.fields.some((field) => contact.isRequired(field) && !field.hidden && contact.isVisible(field)),
)
const hasErrors = computed(() => Object.keys(contact.errors.value).length > 0)
const submitLabel = computed(() => {
  if (!contact.isLastStep.value) return t(contact.processing.value ? 'checking' : 'next')
  return contact.processing.value ? t('sending') : props.form.submit_label || t('send')
})

function sectionNumber(index: number) {
  const shown = (group: (typeof groups.value)[number]) =>
    group.fields.some((field) => !field.hidden && contact.isVisible(field))
  return groups.value.slice(0, index).filter(shown).length + 1
}

const rangeText = (field: NibbleFormField) =>
  field.prepend || field.append
    ? `${field.prepend ?? ''}${contact.values[field.handle]}${field.append ? ` ${field.append}` : ''}`
    : undefined
const help = (field: NibbleFormField) => [field.instructions, contact.fileLimits(field)].filter(Boolean).join(' ')
const invalid = (field: NibbleFormField) => (contact.errors.value[field.handle] ? 'true' : undefined)
const optionId = (field: NibbleFormField, index: number) =>
  index === 0 ? contact.inputId(field) : `${contact.inputId(field)}-${index}`

function chosen(field: NibbleFormField, value: string) {
  const current = contact.values[field.handle]
  return Array.isArray(current) ? (current as string[]).includes(value) : current === value
}

const swatchesOnly = (field: NibbleFormField) => field.type === 'color' && field.allow_any === false
const joined = (field: NibbleFormField) => field.type === 'button_group' || swatchesOnly(field)
const choices = (field: NibbleFormField) =>
  swatchesOnly(field)
    ? (field.swatches ?? []).map((swatch) => ({ value: swatch, label: swatch }))
    : (field.options ?? [])

function bound(field: NibbleFormField, date: string | undefined, time: string) {
  if (!date || !/^\d{4}-\d{2}-\d{2}$/.test(date)) return undefined
  return field.time_enabled ? `${date}T${time}` : date
}
</script>

<template>
  <p v-if="form.closed" role="status">{{ form.closed_message }}</p>
  <p
    v-else-if="contact.sent.value"
    :ref="(el) => (contact.messageEl.value = el as HTMLElement | null)"
    role="status"
    tabindex="-1"
    class="max-w-2xl border-l-2 border-accent pl-4 text-lg"
  >
    {{ contact.message.value }}
  </p>
  <form
    v-else
    :action="form.action"
    method="post"
    enctype="multipart/form-data"
    class="grid max-w-2xl grid-cols-[minmax(0,1fr)] gap-8"
    novalidate
    @submit="contact.submit"
  >
    <p v-if="contact.unavailable" role="status" class="border-l-2 border-red-600 pl-4 text-red-700 dark:text-red-400">
      {{ t('unavailable') }}
    </p>
    <p v-if="form.result?.status === 'resumed'" role="status" class="border-l-2 border-current/40 pl-4">
      {{ t('resumed') }}
    </p>
    <div
      v-if="hasErrors"
      :ref="(el) => (contact.summaryEl.value = el as HTMLElement | null)"
      tabindex="-1"
      class="border-l-2 border-red-600 pl-4 text-red-700 dark:text-red-400"
    >
      <p>{{ contact.errors.value.base ?? t('check_answers') }}</p>
      <ul v-if="contact.errorList.value.length" class="mt-2 grid gap-1 text-sm">
        <li v-for="error in contact.errorList.value" :key="error.handle">
          <a
            :href="error.href"
            class="underline underline-offset-4 hover:text-accent"
            @click="contact.goToField(error.handle, $event)"
            >{{ error.label }}: {{ error.message }}</a
          >
        </li>
      </ul>
    </div>
    <p v-if="form.result?.status === 'expired'" role="status" class="border-l-2 border-current/40 pl-4">
      {{ form.result.message }}
    </p>
    <p v-if="hasRequired" class="-mb-4 text-sm text-gray-600 dark:text-gray-300">
      {{ requiredNote[0] }}<span v-if="requiredNote.length > 1" class="text-accent">*</span
      >{{ requiredNote.slice(1).join('*') }}
    </p>
    <div v-if="contact.stepping.value" class="grid gap-2">
      <p
        :ref="(el) => (contact.stepEl.value = el as HTMLElement | null)"
        tabindex="-1"
        class="text-sm text-gray-600 dark:text-gray-300"
      >
        {{
          t('step')
            .replace('%{step}', String(contact.step.value + 1))
            .replace('%{total}', String(contact.steps.value.length))
        }}
      </p>
      <div class="h-1 bg-current/15" aria-hidden="true">
        <div class="h-1 bg-accent" :style="{ width: `${contact.progress.value * 100}%` }" />
      </div>
    </div>

    <component
      :is="form.sections ? 'fieldset' : 'div'"
      v-for="(group, index) in groups"
      v-show="contact.isCurrentStep(index)"
      :key="index"
      class="grid grid-cols-[minmax(0,1fr)] gap-8"
    >
      <template v-if="form.sections">
        <legend class="mb-2 text-xl">{{ sectionNumber(index) }}. {{ group.display }}</legend>
        <p v-if="group.instructions" class="mt-2 text-sm text-gray-600 dark:text-gray-300">{{ group.instructions }}</p>
      </template>
      <template v-for="field in group.fields" :key="field.handle">
        <input
          v-if="field.hidden"
          :id="contact.inputId(field)"
          type="hidden"
          :name="contact.fieldName(field)"
          :value="contact.values[field.handle]"
        />
        <div v-else-if="contact.isVisible(field)">
          <fieldset
            v-if="field.type === 'radio' || field.type === 'checkboxes' || joined(field)"
            :aria-describedby="contact.describedBy(field)"
          >
            <legend class="mb-3">
              {{ field.display
              }}<template v-if="contact.isRequired(field)"
                ><span class="text-accent" aria-hidden="true"> *</span
                ><span class="sr-only">{{ ` ${t('required')}` }}</span></template
              >
            </legend>
            <div v-if="joined(field)" class="flex flex-wrap">
              <label v-for="(option, optionIndex) in choices(field)" :key="option.value" class="-ml-px first:ml-0">
                <input
                  :id="optionId(field, optionIndex)"
                  v-model="contact.values[field.handle]"
                  type="radio"
                  :name="contact.fieldName(field)"
                  :value="option.value"
                  :aria-invalid="invalid(field)"
                  class="peer sr-only"
                />
                <span
                  class="peer-checked:bg-ink peer-checked:text-paper dark:peer-checked:bg-paper dark:peer-checked:text-ink flex min-h-12 cursor-pointer items-center gap-2 border border-current px-4 py-2 peer-focus-visible:outline-2 peer-focus-visible:outline-offset-2 peer-focus-visible:outline-accent"
                >
                  <span
                    v-if="swatchesOnly(field)"
                    class="size-6 border border-current/40"
                    :style="{ backgroundColor: option.value }"
                    aria-hidden="true"
                  />
                  <span :class="{ 'font-mono text-sm': swatchesOnly(field) }">{{ option.label }}</span>
                </span>
              </label>
            </div>
            <div v-else :class="field.inline ? 'flex flex-wrap gap-x-6 gap-y-3' : 'grid gap-3'">
              <label v-for="(option, optionIndex) in field.options" :key="option.value" class="flex items-center gap-3">
                <input
                  :id="optionId(field, optionIndex)"
                  v-model="contact.values[field.handle]"
                  :type="field.type === 'radio' ? 'radio' : 'checkbox'"
                  :name="contact.fieldName(field)"
                  :value="option.value"
                  :aria-invalid="invalid(field)"
                  class="size-5 shrink-0 accent-accent"
                />
                {{ option.label }}
              </label>
            </div>
          </fieldset>
          <fieldset v-else-if="field.type === 'rating'" :aria-describedby="contact.describedBy(field)">
            <legend class="mb-3">
              {{ field.display
              }}<template v-if="contact.isRequired(field)"
                ><span class="text-accent" aria-hidden="true"> *</span
                ><span class="sr-only">{{ ` ${t('required')}` }}</span></template
              >
            </legend>
            <div class="flex gap-1">
              <label
                v-for="n in field.max ?? 5"
                :key="n"
                class="relative cursor-pointer text-3xl leading-none has-focus-visible:outline-2 has-focus-visible:outline-offset-2 has-focus-visible:outline-accent"
                :class="n <= Number(contact.values[field.handle]) ? 'text-accent' : 'text-current/30'"
              >
                <input
                  :id="optionId(field, n - 1)"
                  v-model="contact.values[field.handle]"
                  type="radio"
                  :name="contact.fieldName(field)"
                  :value="n"
                  :required="contact.isRequired(field)"
                  :aria-invalid="invalid(field)"
                  class="absolute inset-0 size-full cursor-pointer opacity-0"
                />
                <span aria-hidden="true">&#9733;</span>
                <span class="sr-only">{{ n }} of {{ field.max ?? 5 }}</span>
              </label>
            </div>
          </fieldset>
          <div v-else-if="field.type === 'toggle'">
            <p v-if="field.inline_label" :id="`${contact.inputId(field)}-display`" class="mb-3">{{ field.display }}</p>
            <div class="flex items-start gap-3">
              <input
                :id="contact.inputId(field)"
                v-model="contact.values[field.handle]"
                type="checkbox"
                :name="contact.fieldName(field)"
                value="true"
                :required="contact.isRequired(field)"
                :aria-labelledby="
                  field.inline_label ? `${contact.inputId(field)}-display ${contact.inputId(field)}-label` : undefined
                "
                :aria-describedby="contact.describedBy(field)"
                :aria-invalid="invalid(field)"
                class="mt-1 size-5 shrink-0 accent-accent"
              />
              <!-- eslint-disable vue/no-v-html -->
              <label :id="`${contact.inputId(field)}-label`" :for="contact.inputId(field)">
                <span
                  v-if="field.inline_label_html"
                  class="[&_a]:underline"
                  v-html="field.inline_label_html"
                /><template v-else>{{ field.inline_label || field.display }}</template
                ><span v-if="contact.isRequired(field)" class="text-accent" aria-hidden="true"> *</span>
              </label>
              <!-- eslint-enable vue/no-v-html -->
            </div>
          </div>
          <!-- eslint-disable vue/no-v-html -->
          <div
            v-else-if="field.type === 'note'"
            class="[&_a]:underline [&_ul]:list-disc [&_ul]:pl-6"
            v-html="field.text_html"
          />
          <!-- eslint-enable vue/no-v-html -->
          <template v-else>
            <label :for="contact.inputId(field)" class="mb-3 block">
              {{ field.display }}<span v-if="contact.isRequired(field)" class="text-accent" aria-hidden="true"> *</span
              ><span v-if="field.time_zone" class="text-sm text-gray-600 dark:text-gray-300">
                ({{ field.time_zone }})</span
              >
            </label>
            <textarea
              v-if="field.type === 'textarea'"
              :id="contact.inputId(field)"
              v-model="contact.values[field.handle] as string"
              :name="contact.fieldName(field)"
              :maxlength="field.character_limit"
              :placeholder="field.placeholder"
              :rows="field.rows ?? 6"
              :required="contact.isRequired(field)"
              :aria-describedby="contact.describedBy(field)"
              :aria-invalid="invalid(field)"
              class="w-full border border-current/40 bg-transparent p-3"
            />
            <select
              v-else-if="field.type === 'select'"
              :id="contact.inputId(field)"
              v-model="contact.values[field.handle]"
              :name="contact.fieldName(field)"
              :multiple="field.multiple"
              :required="contact.isRequired(field)"
              :aria-describedby="contact.describedBy(field)"
              :aria-invalid="invalid(field)"
              class="w-full border-b border-current bg-transparent px-1 py-3"
            >
              <option
                v-if="!field.multiple"
                value=""
                :disabled="contact.isRequired(field)"
                :selected="!contact.values[field.handle]"
              >
                {{ field.placeholder || t('choose') }}
              </option>
              <option
                v-for="option in field.options"
                :key="option.value"
                :value="option.value"
                :selected="chosen(field, option.value)"
              >
                {{ option.label }}
              </option>
            </select>
            <input
              v-else-if="field.type === 'files'"
              :id="contact.inputId(field)"
              type="file"
              :name="contact.fieldName(field)"
              :accept="contact.accept(field)"
              :multiple="(field.max_files ?? 1) > 1"
              :required="contact.isRequired(field)"
              :aria-describedby="contact.describedBy(field)"
              :aria-invalid="invalid(field)"
              class="block w-full"
              @change="contact.setFiles(field.handle, $event)"
            />
            <input
              v-else-if="field.type === 'date'"
              :id="contact.inputId(field)"
              v-model="contact.values[field.handle] as string"
              :type="field.time_enabled ? 'datetime-local' : 'date'"
              :name="contact.fieldName(field)"
              :min="bound(field, field.earliest_date, '00:00')"
              :max="bound(field, field.latest_date, '23:59')"
              :required="contact.isRequired(field)"
              :aria-describedby="contact.describedBy(field)"
              :aria-invalid="invalid(field)"
              class="w-full border-b border-current bg-transparent px-1 py-3"
            />
            <div v-else-if="field.type === 'range'" class="flex items-center gap-3 border-b border-current px-1 py-3">
              <span v-if="field.prepend">{{ field.prepend }}</span>
              <input
                :id="contact.inputId(field)"
                v-model="contact.values[field.handle]"
                type="range"
                :name="contact.fieldName(field)"
                :min="field.min ?? 0"
                :max="field.max ?? 100"
                :step="field.step ?? 1"
                :aria-valuetext="rangeText(field)"
                :aria-describedby="contact.describedBy(field)"
                :aria-invalid="invalid(field)"
                class="w-0 min-w-0 flex-1 accent-accent"
              />
              <output :for="contact.inputId(field)" class="min-w-8 text-right tabular-nums">{{
                contact.values[field.handle]
              }}</output>
              <span v-if="field.append">{{ field.append }}</span>
            </div>
            <input
              v-else-if="field.type === 'time'"
              :id="contact.inputId(field)"
              v-model="contact.values[field.handle] as string"
              type="time"
              :name="contact.fieldName(field)"
              :step="field.seconds ? 1 : undefined"
              :min="field.earliest"
              :max="field.latest"
              :required="contact.isRequired(field)"
              :aria-describedby="contact.describedBy(field)"
              :aria-invalid="invalid(field)"
              class="w-full border-b border-current bg-transparent px-1 py-3"
            />
            <div v-else-if="field.type === 'color'" class="flex flex-wrap items-center gap-3">
              <input
                :id="contact.inputId(field)"
                :value="(contact.values[field.handle] as string) || undefined"
                type="color"
                :name="contact.fieldName(field)"
                :list="field.swatches?.length ? `${contact.inputId(field)}-swatches` : undefined"
                :required="contact.isRequired(field)"
                :aria-describedby="contact.describedBy(field)"
                :aria-invalid="invalid(field)"
                class="h-12 w-20 cursor-pointer border border-current bg-transparent p-1"
                :class="{ 'opacity-30': !contact.values[field.handle] }"
                @input="contact.values[field.handle] = ($event.target as HTMLInputElement).value"
              />
              <span v-if="!contact.values[field.handle]" class="text-sm text-gray-600 dark:text-gray-300">{{
                t('not_chosen')
              }}</span>
              <datalist v-if="field.swatches?.length" :id="`${contact.inputId(field)}-swatches`">
                <option v-for="swatch in field.swatches" :key="swatch" :value="swatch" />
              </datalist>
            </div>
            <output
              v-else-if="field.type === 'calculation'"
              :id="contact.inputId(field)"
              aria-live="polite"
              :aria-describedby="contact.describedBy(field)"
              class="block min-h-12 border-b border-current/40 px-1 py-3 tabular-nums"
              >{{ contact.calculatedText(field) }}</output
            >
            <div v-else class="flex items-baseline gap-2 border-b border-current">
              <span v-if="field.prepend">{{ field.prepend }}</span>
              <input
                :id="contact.inputId(field)"
                v-model="contact.values[field.handle] as string"
                :type="field.type === 'integer' || field.type === 'decimal' ? 'number' : (field.input_type ?? 'text')"
                :inputmode="field.type === 'integer' ? 'numeric' : field.type === 'decimal' ? 'decimal' : undefined"
                :min="field.min"
                :max="field.max"
                :step="field.type === 'decimal' ? (field.step ?? 10 ** -(field.decimals ?? 2)) : field.step"
                :name="contact.fieldName(field)"
                :maxlength="field.character_limit"
                :placeholder="field.placeholder"
                :autocomplete="field.autocomplete"
                :required="contact.isRequired(field)"
                :aria-describedby="contact.describedBy(field)"
                :aria-invalid="invalid(field)"
                class="w-0 min-w-0 flex-1 bg-transparent px-1 py-3"
              />
              <span v-if="field.append">{{ field.append }}</span>
            </div>
          </template>
          <p v-if="help(field)" :id="contact.helpId(field)" class="mt-2 text-sm text-gray-600 dark:text-gray-300">
            {{ help(field) }}
          </p>
          <p
            v-if="contact.errors.value[field.handle]"
            :id="contact.errorId(field)"
            class="mt-2 text-sm text-red-700 dark:text-red-400"
          >
            {{ contact.errors.value[field.handle] }}
          </p>
        </div>
      </template>
    </component>

    <input
      v-if="form.honeypot"
      v-model="contact.trap.value"
      :name="form.honeypot"
      type="text"
      tabindex="-1"
      autocomplete="off"
      aria-hidden="true"
      class="absolute -left-[9999px] h-px w-px overflow-hidden"
    />
    <input v-if="form.resume?.token" type="hidden" name="_nibble_resume" :value="form.resume.token" />
    <input v-if="form.timestamp" type="hidden" name="_nibble_t" :value="form.timestamp" />
    <div :ref="(el) => (contact.captchaEl.value = el as HTMLElement | null)" />

    <div class="flex flex-wrap items-center gap-x-6 gap-y-4">
      <button
        v-if="contact.stepping.value && contact.step.value > 0"
        type="button"
        class="min-h-14 border border-current/40 px-6 py-3 hover:text-accent disabled:cursor-not-allowed disabled:opacity-40 disabled:hover:text-current"
        :disabled="contact.processing.value"
        @click="contact.back"
      >
        {{ t('back') }}
      </button>
      <button
        type="submit"
        class="min-h-14 border border-current px-6 py-3 hover:text-accent disabled:cursor-not-allowed disabled:opacity-40 disabled:hover:text-current"
        :disabled="contact.processing.value || contact.unavailable"
      >
        {{ submitLabel }}
      </button>
      <button
        v-if="form.resume && contact.enhanced.value"
        type="button"
        class="min-h-14 underline underline-offset-4 hover:text-accent disabled:cursor-not-allowed disabled:opacity-40 disabled:hover:text-current"
        :disabled="contact.processing.value || contact.unavailable"
        @click="contact.saveForLater"
      >
        {{ t('save_later') }}
      </button>
    </div>
    <p
      v-if="form.resume"
      :ref="(el) => (contact.savedEl.value = el as HTMLElement | null)"
      role="status"
      tabindex="-1"
      class="text-sm empty:hidden"
    >
      {{ contact.saved.value }}
    </p>
  </form>
</template>
