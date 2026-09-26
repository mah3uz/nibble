<script setup lang="ts">
import { parseDate, parseDateTime, type DateValue } from '@internationalized/date'
import { CalendarIcon, X } from '@lucide/vue'
import { DateFieldInput, DateFieldRoot } from 'reka-ui'
import { computed, ref } from 'vue'
import { fromIso, toIsoWithOffset } from '../../lib/datetime'
import { Button } from '@/components/ui/button'
import { Calendar } from '@/components/ui/calendar'
import { Popover, PopoverAnchor, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import { fieldtypeEmits, fieldtypeProps, useFieldtype } from '../useFieldtype'

const props = defineProps(fieldtypeProps)
const emit = defineEmits(fieldtypeEmits)
const { update, isReadOnly, expose } = useFieldtype(emit, props)
defineExpose(expose)

const calendarOpen = ref(false)
const timeEnabled = computed(() => props.config.time_enabled === true)
const timezone = computed(() => (props.meta.timezone as string) || Intl.DateTimeFormat().resolvedOptions().timeZone)
const raw = computed(() => (typeof props.value === 'string' && props.value !== 'now' ? props.value : null))

const parts = computed(() => {
  if (!raw.value) return { dateIso: null as string | null, time: '' }
  return timeEnabled.value ? fromIso(raw.value, timezone.value) : { dateIso: raw.value.slice(0, 10), time: '' }
})
const fieldValue = computed(() => {
  if (!parts.value.dateIso) return undefined
  return timeEnabled.value
    ? parseDateTime(`${parts.value.dateIso}T${parts.value.time || '00:00'}`)
    : parseDate(parts.value.dateIso)
})
const calendarValue = computed(() => (parts.value.dateIso ? parseDate(parts.value.dateIso) : undefined))
const pad = (n: number) => String(n).padStart(2, '0')

function emitDate(dateIso: string, time = parts.value.time) {
  update(timeEnabled.value ? toIsoWithOffset(dateIso, time || '00:00', timezone.value) : dateIso)
}

function onFieldChange(next: DateValue | undefined) {
  if (!next) return
  const dateIso = `${next.year}-${pad(next.month)}-${pad(next.day)}`
  emitDate(dateIso, 'hour' in next ? `${pad(next.hour)}:${pad(next.minute)}` : undefined)
}
</script>

<template>
  <Popover v-model:open="calendarOpen">
    <PopoverAnchor as-child>
      <DateFieldRoot
        :id="id"
        v-slot="{ segments }"
        :model-value="fieldValue"
        :granularity="timeEnabled ? (config.time_seconds_enabled ? 'second' : 'minute') : 'day'"
        hide-time-zone
        :disabled="isReadOnly"
        class="flex h-10 w-full items-center overflow-x-auto overflow-y-hidden rounded-lg border border-gray-300 bg-white px-2 leading-[1.375rem] text-gray-600 shadow-ui-sm focus-within:focus-outline dark:border-gray-700 dark:bg-gray-900 dark:text-gray-300 data-disabled:border-dashed data-disabled:shadow-none"
        @update:model-value="onFieldChange"
      >
        <PopoverTrigger
          :disabled="isReadOnly"
          class="-ms-1 flex shrink-0 items-center justify-center rounded-lg p-2 text-gray-500 outline-hidden hover:bg-gray-100 focus:bg-gray-100 dark:text-gray-400 dark:hover:bg-gray-900"
          aria-label="Open calendar"
        >
          <CalendarIcon class="size-4" />
        </PopoverTrigger>
        <div class="flex flex-1 items-center text-base whitespace-nowrap uppercase">
          <template v-for="item in segments" :key="item.part">
            <DateFieldInput v-if="item.part === 'literal'" :part="item.part" class="whitespace-pre">{{
              item.value
            }}</DateFieldInput>
            <DateFieldInput
              v-else
              :part="item.part"
              class="rounded-sm px-0.25 py-0.5 focus:bg-blue-100 focus:outline-hidden data-placeholder:text-gray-600 dark:focus:bg-blue-900 dark:data-placeholder:text-gray-400"
              >{{ item.value }}</DateFieldInput
            >
          </template>
        </div>
        <Button
          v-if="value && !isReadOnly"
          type="button"
          variant="subtle"
          size="icon-sm"
          class="-my-1.25 ms-1 -me-1"
          aria-label="Clear date"
          @click="update(null)"
          ><X
        /></Button>
      </DateFieldRoot>
    </PopoverAnchor>
    <PopoverContent align="start" class="w-[20rem] p-4">
      <Calendar
        :model-value="calendarValue"
        :default-placeholder="calendarValue"
        :min-value="config.earliest_date ? parseDate(String(config.earliest_date)) : undefined"
        :max-value="config.latest_date ? parseDate(String(config.latest_date)) : undefined"
        @update:model-value="(picked) => picked && (emitDate(picked.toString()), (calendarOpen = false))"
      />
    </PopoverContent>
  </Popover>
</template>
