<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { Button } from '@/components/ui/button'
import { Textarea } from '@/components/ui/textarea'
import { fieldtypeEmits, fieldtypeProps, useFieldtype } from '../useFieldtype'

const props = defineProps(fieldtypeProps)
const emit = defineEmits(fieldtypeEmits)
const { updateDebounced, isReadOnly, expose } = useFieldtype(emit, props)
defineExpose(expose)

const text = ref(props.value == null ? '' : String(props.value))
watch(
  () => props.value,
  (value) => (text.value = value == null ? '' : String(value)),
)

const limit = computed(() => Number(props.config.character_limit) || 0)
const previewable = computed(() => props.config.preview !== false)
const showing = ref(false)
const previewClasses =
  'prose prose-sm prose-nibble rounded-md border border-gray-200 px-3.5 py-2.5 dark:border-gray-700'
const html = ref('')
const failed = ref(false)

// The server renders it, so the preview is what the theme will receive rather than an approximation.
async function preview() {
  showing.value = !showing.value
  if (!showing.value) return

  failed.value = false
  const csrf = document.querySelector<HTMLMetaElement>('meta[name=csrf-token]')?.content ?? ''
  try {
    const response = await fetch('/admin/nibble/markdown/preview', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json', 'X-CSRF-Token': csrf },
      body: JSON.stringify({ text: text.value, sanitize: String(props.config.sanitize === true) }),
    })
    if (!response.ok) throw new Error(String(response.status))
    html.value = (await response.json()).html
  } catch {
    failed.value = true
  }
}
</script>

<template>
  <div class="space-y-1.5">
    <Textarea
      v-show="!showing"
      :id="id"
      :name="handle"
      :model-value="text"
      :rows="(config.rows as number) || 12"
      :placeholder="config.placeholder as string"
      :readonly="isReadOnly"
      class="font-mono text-[13px]"
      @update:model-value="(raw) => updateDebounced((text = String(raw)))"
      @focus="emit('focus')"
      @blur="emit('blur')"
    />

    <!-- eslint-disable-next-line vue/no-v-html -- the server rendered it, raw HTML is dropped, and it is the author's own text -->
    <div v-if="showing" :class="previewClasses" v-html="failed ? '' : html" />
    <p v-if="showing && failed" class="text-sm text-destructive">The preview could not be rendered.</p>

    <div class="flex items-center justify-between">
      <Button v-if="previewable" type="button" variant="ghost" size="sm" @click="preview">
        {{ showing ? 'Write' : 'Preview' }}
      </Button>
      <p
        v-if="limit && !isReadOnly"
        class="text-xs"
        :class="text.length > limit ? 'text-destructive' : 'text-muted-foreground'"
      >
        {{ text.length }}/{{ limit }}
      </p>
    </div>
  </div>
</template>
