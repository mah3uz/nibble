<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
import { computed } from 'vue'
import CpIcon from '@/components/cp/icons/CpIcon.vue'
import { Button } from '@/components/ui/button'
import CalendarEntryChip from './CalendarEntryChip.vue'
import { WEEKDAYS, type CalendarDay } from './types'

const props = defineProps<{
  days: CalendarDay[]
  todayWeekday: number
  selected: string | null
  createUrl: string | null
}>()

defineEmits<{ select: [key: string] }>()

const weeks = computed(() => {
  const rows: CalendarDay[][] = []
  for (let index = 0; index < props.days.length; index += 7) rows.push(props.days.slice(index, index + 7))
  return rows.filter((row) => row.some((day) => !day.outside))
})

const DOT: Record<string, string> = {
  published: 'bg-green-500',
  draft: 'bg-gray-300',
  scheduled: 'bg-purple-500',
}
</script>

<template>
  <div class="w-full border-collapse">
    <div class="mb-2 grid grid-cols-7 gap-3">
      <div
        v-for="(weekday, index) in WEEKDAYS"
        :key="weekday"
        class="rounded-lg bg-gray-200/75 p-2 text-center text-sm font-medium text-gray-700 dark:bg-gray-900/75 dark:text-gray-400"
      >
        <div class="flex items-center justify-center gap-1">
          <div v-if="index === todayWeekday" class="mr-1 size-1.5 rounded-full bg-ui-accent-bg" />
          <span class="@4xl:hidden">{{ weekday.slice(0, 2) }}</span>
          <span class="hidden @4xl:block">{{ weekday }}</span>
        </div>
      </div>
    </div>

    <div class="space-y-3">
      <div v-for="(week, index) in weeks" :key="index" class="grid grid-cols-7 gap-3">
        <div
          v-for="day in week"
          :key="day.key"
          class="group relative aspect-square cursor-pointer rounded-xl p-2 shadow-ui-sm ring ring-gray-200 dark:ring-gray-700"
          :class="
            day.today
              ? 'border! border-ui-accent-bg! bg-ui-accent-bg/10!'
              : day.outside
                ? 'bg-gray-100 ring-1 ring-gray-200 dark:bg-gray-800 dark:ring-gray-700'
                : 'bg-white dark:bg-gray-900'
          "
          @click="$emit('select', day.key)"
        >
          <div class="flex h-full max-h-full w-full flex-col items-center @3xl:items-start">
            <button
              type="button"
              class="mb-1 flex size-6 cursor-pointer items-center justify-center rounded-full text-sm"
              :class="[
                day.outside ? 'text-gray-600 dark:text-gray-400' : 'text-gray-900 dark:text-white',
                selected === day.key ? 'bg-blue-600 text-white' : '',
                day.today ? 'text-ui-accent-text' : '',
              ]"
              :aria-label="`Entries on ${day.key}`"
              @click.stop="$emit('select', day.key)"
            >
              {{ day.number }}
            </button>

            <div v-if="day.entries.length" class="w-full @3xl:hidden">
              <div class="flex h-1 items-center justify-center overflow-hidden rounded-full">
                <div
                  v-for="entry in day.entries.slice(0, 4)"
                  :key="entry.id"
                  class="h-full w-1/4 first:rounded-s-full last:rounded-e-full"
                  :class="DOT[entry.status] ?? DOT.draft"
                />
              </div>
            </div>

            <div class="hidden w-full flex-1 space-y-1.5 overflow-auto overscroll-contain @3xl:block">
              <CalendarEntryChip v-for="entry in day.entries" :key="entry.id" :entry="entry" />
            </div>
          </div>

          <div
            v-if="createUrl"
            class="absolute top-1 right-1 hidden opacity-0 transition-opacity group-hover:opacity-100 @3xl:block"
          >
            <Button as-child variant="subtle" size="sm" :aria-label="`New entry on ${day.key}`">
              <Link :href="`${createUrl}?date=${day.key}`"><CpIcon name="plus" /></Link>
            </Button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
