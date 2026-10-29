<script setup lang="ts">
import { Check, X } from '@lucide/vue'
import { computed, ref, watch } from 'vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { fieldtypeEmits, fieldtypeProps, useFieldtype } from '../useFieldtype'

const props = defineProps(fieldtypeProps)
const emit = defineEmits(fieldtypeEmits)
const { update, isReadOnly, expose } = useFieldtype(emit, props)
defineExpose(expose)

const HEX = /^#[0-9a-f]{6}$/
const current = computed(() => (typeof props.value === 'string' ? props.value.toLowerCase() : ''))
const swatches = computed(() =>
  (Array.isArray(props.config.swatches) ? props.config.swatches : []).map((swatch) => String(swatch).toLowerCase()),
)
const allowAny = computed(() => props.config.allow_any !== false)

const text = ref(current.value)
watch(current, (value) => (text.value = value))

function choose(raw: string) {
  const next = raw.trim().toLowerCase()
  text.value = next
  update(next === '' ? null : next)
}
</script>

<template>
  <div class="flex flex-wrap items-center gap-2">
    <div v-if="swatches.length" :id="allowAny ? undefined : id" role="group" class="flex flex-wrap gap-1.5">
      <button
        v-for="swatch in swatches"
        :key="swatch"
        type="button"
        :aria-label="swatch"
        :aria-pressed="current === swatch"
        :title="swatch"
        :disabled="isReadOnly"
        class="flex size-8 items-center justify-center rounded-md border border-black/15 shadow-ui-sm outline-none focus-visible:focus-outline disabled:cursor-not-allowed disabled:opacity-50 dark:border-white/20"
        :style="{ backgroundColor: swatch }"
        @click="choose(swatch)"
      >
        <Check v-if="current === swatch" class="size-4 text-white mix-blend-difference" aria-hidden="true" />
      </button>
    </div>
    <template v-if="allowAny">
      <input
        type="color"
        :value="HEX.test(current) ? current : '#000000'"
        :disabled="isReadOnly"
        aria-label="Pick a colour"
        class="h-10 w-12 cursor-pointer rounded-lg border border-gray-300 bg-white p-1 shadow-ui-sm outline-none focus-visible:focus-outline disabled:cursor-not-allowed disabled:opacity-50 dark:border-gray-700 dark:bg-gray-900"
        @input="choose(($event.target as HTMLInputElement).value)"
      />
      <Input
        :id="id"
        :name="handle"
        class="w-32 font-mono"
        :model-value="text"
        placeholder="#rrggbb"
        maxlength="7"
        spellcheck="false"
        autocomplete="off"
        :readonly="isReadOnly"
        @update:model-value="(next) => choose(String(next))"
        @focus="emit('focus')"
        @blur="emit('blur')"
      />
    </template>
    <Button
      v-if="current && !isReadOnly"
      type="button"
      variant="subtle"
      size="icon-sm"
      aria-label="Clear colour"
      @click="choose('')"
      ><X
    /></Button>
  </div>
</template>
