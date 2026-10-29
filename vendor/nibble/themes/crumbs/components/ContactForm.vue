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

const hasRequired = computed(() => props.form.fields.some((field) => field.required && !field.hidden))
const hasErrors = computed(() => Object.keys(contact.errors.value).length > 0)
const submitLabel = computed(() => {
  if (!contact.isLastStep.value) return t(contact.processing.value ? 'checking' : 'next')
  return contact.processing.value ? t('sending') : props.form.submit_label || t('send')
})

const help = (field: NibbleFormField) => [field.instructions, contact.fileLimits(field)].filter(Boolean).join(' ')
const invalid = (field: NibbleFormField) => (contact.errors.value[field.handle] ? 'true' : undefined)
const optionId = (field: NibbleFormField, index: number) =>
  index === 0 ? contact.inputId(field) : `${contact.inputId(field)}-${index}`

function chosen(field: NibbleFormField, value: string) {
  const current = contact.values[field.handle]
  return Array.isArray(current) ? (current as string[]).includes(value) : current === value
}

function bound(field: NibbleFormField, date: string | undefined, time: string) {
  if (!date || !/^\d{4}-\d{2}-\d{2}$/.test(date)) return undefined
  return field.time_enabled ? `${date}T${time}` : date
}
</script>

<template>
  <p v-if="form.closed" role="status">{{ form.closed_message }}</p>
  <form
    v-else
    :action="form.action"
    method="post"
    enctype="multipart/form-data"
    class="grid max-w-2xl gap-8"
    novalidate
    @submit="contact.submit"
  >
    <p
      v-if="contact.sent.value"
      :ref="(el) => (contact.messageEl.value = el as HTMLElement | null)"
      role="status"
      tabindex="-1"
      class="border-l-2 border-accent pl-4 text-lg"
    >
      {{ contact.message.value }}
    </p>
    <div
      v-if="hasErrors"
      :ref="(el) => (contact.summaryEl.value = el as HTMLElement | null)"
      role="alert"
      tabindex="-1"
      class="border-l-2 border-red-600 pl-4 text-red-700 dark:text-red-400"
    >
      <p>{{ contact.errors.value.base ?? t('check_answers') }}</p>
      <ul v-if="contact.errorList.value.length" class="mt-2 grid gap-1 text-sm">
        <li v-for="error in contact.errorList.value" :key="error.handle">
          <a :href="error.href" class="underline underline-offset-4 hover:text-accent"
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
      class="grid gap-8"
    >
      <template v-if="form.sections">
        <legend class="mb-2 text-xl">{{ index + 1 }}. {{ group.display }}</legend>
        <p v-if="group.instructions" class="-mt-4 text-sm text-gray-600 dark:text-gray-300">{{ group.instructions }}</p>
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
            v-if="field.type === 'radio' || field.type === 'checkboxes'"
            :aria-describedby="contact.describedBy(field)"
          >
            <legend class="mb-3">
              {{ field.display
              }}<template v-if="field.required"
                ><span class="text-accent" aria-hidden="true"> *</span
                ><span class="sr-only">{{ ` ${t('required')}` }}</span></template
              >
            </legend>
            <div :class="field.inline ? 'flex flex-wrap gap-x-6 gap-y-3' : 'grid gap-3'">
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
          <div v-else-if="field.type === 'toggle'">
            <p v-if="field.inline_label" class="mb-3">{{ field.display }}</p>
            <div class="flex items-start gap-3">
              <input
                :id="contact.inputId(field)"
                v-model="contact.values[field.handle]"
                type="checkbox"
                :name="contact.fieldName(field)"
                value="true"
                :required="field.required"
                :aria-describedby="contact.describedBy(field)"
                :aria-invalid="invalid(field)"
                class="mt-1 size-5 shrink-0 accent-accent"
              />
              <label :for="contact.inputId(field)">
                {{ field.inline_label || field.display
                }}<span v-if="field.required" class="text-accent" aria-hidden="true"> *</span>
              </label>
            </div>
          </div>
          <template v-else>
            <label :for="contact.inputId(field)" class="mb-3 block">
              {{ field.display }}<span v-if="field.required" class="text-accent" aria-hidden="true"> *</span>
            </label>
            <textarea
              v-if="field.type === 'textarea'"
              :id="contact.inputId(field)"
              v-model="contact.values[field.handle] as string"
              :name="contact.fieldName(field)"
              :maxlength="field.character_limit"
              :placeholder="field.placeholder"
              :rows="field.rows ?? 6"
              :required="field.required"
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
              :required="field.required"
              :aria-describedby="contact.describedBy(field)"
              :aria-invalid="invalid(field)"
              class="w-full border-b border-current bg-transparent px-1 py-3"
            >
              <option
                v-if="!field.multiple"
                value=""
                :disabled="field.required"
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
              :required="field.required"
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
              :required="field.required"
              :aria-describedby="contact.describedBy(field)"
              :aria-invalid="invalid(field)"
              class="w-full border-b border-current bg-transparent px-1 py-3"
            />
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
                :type="field.type === 'integer' ? 'number' : (field.input_type ?? 'text')"
                :inputmode="field.type === 'integer' ? 'numeric' : undefined"
                :min="field.min"
                :max="field.max"
                :step="field.step"
                :name="contact.fieldName(field)"
                :maxlength="field.character_limit"
                :placeholder="field.placeholder"
                :autocomplete="field.autocomplete"
                :required="field.required"
                :aria-describedby="contact.describedBy(field)"
                :aria-invalid="invalid(field)"
                class="min-w-0 flex-1 bg-transparent px-1 py-3"
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
    <div :ref="(el) => (contact.captchaEl.value = el as HTMLElement | null)" />

    <div class="flex flex-wrap items-center gap-x-6 gap-y-4">
      <button
        v-if="contact.stepping.value && contact.step.value > 0"
        type="button"
        class="min-h-14 border border-current/40 px-6 py-3 hover:text-accent"
        :disabled="contact.processing.value"
        @click="contact.back"
      >
        {{ t('back') }}
      </button>
      <button
        type="submit"
        class="min-h-14 border border-current px-6 py-3 hover:text-accent"
        :disabled="contact.processing.value"
      >
        {{ submitLabel }}
      </button>
      <button
        v-if="form.resume && contact.enhanced.value"
        type="button"
        class="min-h-14 underline underline-offset-4 hover:text-accent"
        :disabled="contact.processing.value"
        @click="contact.saveForLater"
      >
        {{ t('save_later') }}
      </button>
    </div>
    <p v-if="form.resume" role="status" class="text-sm empty:hidden">{{ contact.saved.value }}</p>
  </form>
</template>
