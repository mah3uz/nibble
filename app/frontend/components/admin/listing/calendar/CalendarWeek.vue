<script setup lang="ts">
import { Link } from '@inertiajs/vue3'
import AdminIcon from '@/components/admin/icons/AdminIcon.vue'
import { Button } from '@/components/ui/button'
import CalendarEntryChip from './CalendarEntryChip.vue'
import { WEEKDAYS, type CalendarDay } from './types'

defineProps<{ days: CalendarDay[]; selected: string | null; createUrl: string | null }>()

defineEmits<{ select: [key: string] }>()

const HOURS = Array.from({ length: 24 }, (_, hour) => hour)

const hourLabel = (hour: number) => `${hour % 12 === 0 ? 12 : hour % 12} ${hour < 12 ? 'AM' : 'PM'}`

const entriesAt = (day: CalendarDay, hour: number) => day.entries.filter((entry) => entry.hour === hour)
</script>

<template>
  <div class="w-full">
    <div class="grid grid-cols-8 overflow-hidden rounded-t-lg border border-gray-200 dark:border-gray-700">
      <div class="bg-gray-50 p-3 text-sm font-medium text-gray-500 dark:bg-gray-900/10 dark:text-gray-400" />
      <button
        v-for="day in days"
        :key="day.key"
        type="button"
        class="cursor-pointer border-l border-gray-200 p-3 text-center dark:border-gray-700"
        :class="
          selected === day.key
            ? 'bg-blue-50 dark:bg-blue-900/20'
            : day.today
              ? 'bg-gray-50 dark:bg-gray-800'
              : 'bg-gray-50 dark:bg-gray-900/10'
        "
        @click="$emit('select', day.key)"
      >
        <div class="text-xs text-gray-500 dark:text-gray-400">{{ WEEKDAYS[day.weekday].slice(0, 3) }}</div>
        <div
          class="inline p-1 text-sm font-medium"
          :class="[
            selected === day.key ? 'text-blue-600 dark:text-blue-400' : 'text-gray-900 dark:text-white',
            day.today ? 'rounded-full bg-ui-accent-bg text-white' : '',
          ]"
        >
          {{ day.number }}
        </div>
      </button>
    </div>

    <div
      class="grid max-h-[60vh] grid-cols-8 gap-0 overflow-auto rounded-b-lg border border-gray-200 dark:border-gray-700"
    >
      <div class="bg-gray-50 dark:bg-gray-900/10">
        <div
          v-for="hour in HOURS"
          :key="hour"
          class="flex h-12 items-start justify-end border-b border-gray-200 pt-1 pr-2 dark:border-gray-700"
        >
          <span class="text-xs text-gray-500 dark:text-gray-400">{{ hourLabel(hour) }}</span>
        </div>
      </div>

      <div
        v-for="day in days"
        :key="day.key"
        class="border-l border-gray-200 bg-white dark:border-gray-700 dark:bg-gray-900"
      >
        <div
          v-for="hour in HOURS"
          :key="hour"
          class="group relative h-12 border-b border-gray-200 dark:border-gray-700"
          :class="entriesAt(day, hour).length ? '' : 'hover:bg-gray-50 dark:hover:bg-gray-800/50'"
          @click="$emit('select', day.key)"
        >
          <div class="absolute inset-0 overflow-scroll overscroll-contain p-1">
            <CalendarEntryChip v-for="entry in entriesAt(day, hour)" :key="entry.id" :entry="entry" />
          </div>
          <div
            v-if="createUrl && !entriesAt(day, hour).length"
            class="absolute top-1 right-1 opacity-0 transition-opacity group-hover:opacity-100"
          >
            <Button as-child variant="subtle" size="sm" :aria-label="`New entry on ${day.key} at ${hourLabel(hour)}`">
              <Link :href="`${createUrl}?date=${day.key}T${String(hour).padStart(2, '0')}:00`">
                <AdminIcon name="plus" />
              </Link>
            </Button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
