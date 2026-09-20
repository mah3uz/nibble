<script setup lang="ts">
import { useNibbleForm, type NibbleForm } from '@nibble'

const props = defineProps<{ form: NibbleForm }>()
const contact = useNibbleForm(props.form)
</script>

<template>
  <form
    :action="form.action"
    method="post"
    enctype="multipart/form-data"
    class="grid max-w-2xl gap-8"
    novalidate
    @submit="contact.submit"
  >
    <p v-if="contact.sent.value" role="status" class="border-l-2 border-accent pl-4 text-lg">
      {{ contact.message.value }}
    </p>
    <p
      v-if="contact.errors.value.base"
      role="alert"
      class="border-l-2 border-red-600 pl-4 text-red-700 dark:text-red-400"
    >
      {{ contact.errors.value.base }}
    </p>

    <div v-for="field in form.fields" :key="field.handle">
      <label :for="`contact-${field.handle}`" class="mb-3 block">
        {{ field.display }}<span v-if="field.required" class="text-accent"> *</span>
      </label>
      <textarea
        v-if="field.type === 'textarea'"
        :id="`contact-${field.handle}`"
        v-model="contact.values[field.handle] as string"
        :name="contact.fieldName(field)"
        :maxlength="field.character_limit"
        :required="field.required"
        rows="6"
        class="w-full border border-current/40 bg-transparent p-3"
      />
      <select
        v-else-if="field.type === 'select'"
        :id="`contact-${field.handle}`"
        v-model="contact.values[field.handle]"
        :name="contact.fieldName(field)"
        class="w-full border-b border-current bg-transparent px-1 py-3"
      >
        <option value="">Choose one…</option>
        <option v-for="option in field.options" :key="option.value" :value="option.value">{{ option.label }}</option>
      </select>
      <input
        v-else-if="field.type === 'files'"
        :id="`contact-${field.handle}`"
        type="file"
        :name="contact.fieldName(field)"
        :accept="contact.accept(field)"
        :multiple="(field.max_files ?? 1) > 1"
        class="block w-full"
        @change="contact.setFiles(field.handle, $event)"
      />
      <input
        v-else
        :id="`contact-${field.handle}`"
        v-model="contact.values[field.handle] as string"
        :type="field.input_type ?? 'text'"
        :name="contact.fieldName(field)"
        :maxlength="field.character_limit"
        :required="field.required"
        class="w-full border-b border-current bg-transparent px-1 py-3"
      />
      <p v-if="field.instructions" class="mt-2 text-sm text-gray-600 dark:text-gray-300">{{ field.instructions }}</p>
      <p v-if="contact.errors.value[field.handle]" class="mt-2 text-sm text-red-700 dark:text-red-400">
        {{ contact.errors.value[field.handle] }}
      </p>
    </div>

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
    <div :ref="(el) => (contact.captchaEl.value = el as HTMLElement | null)" />

    <div>
      <button
        type="submit"
        class="min-h-14 border border-current px-6 py-3 hover:text-accent"
        :disabled="contact.processing.value"
      >
        {{ contact.processing.value ? 'Sending…' : 'Send message' }}
      </button>
    </div>
  </form>
</template>
