<script setup lang="ts">
import CpPanel from '@/components/cp/page/CpPanel.vue'
import { Link, router } from '@inertiajs/vue3'
import { computed, ref } from 'vue'
import CpIcon from '@/components/cp/icons/CpIcon.vue'
import StatusCell from '@/components/cp/listing/cells/StatusCell.vue'
import { Button } from '@/components/ui/button'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group'
import CalendarMonth from './calendar/CalendarMonth.vue'
import CalendarWeek from './calendar/CalendarWeek.vue'
import { buildDays, isoDay, parseDay, type CalendarData } from './calendar/types'

export type { CalendarData } from './calendar/types'

const props = defineProps<{ calendar: CalendarData; createUrl: string | null }>()

const selected = ref<string | null>(null)

const days = computed(() => buildDays(props.calendar))
const todayWeekday = computed(() => parseDay(props.calendar.today).getUTCDay())
const cursor = computed(() => parseDay(props.calendar.date))

const MONTHS = Array.from({ length: 12 }, (_, index) => ({
  value: index + 1,
  label: new Date(Date.UTC(2024, index, 1)).toLocaleDateString('en', { month: 'long', timeZone: 'UTC' }),
}))

const YEARS = Array.from({ length: 21 }, (_, index) => new Date().getFullYear() - 10 + index)

const selectedEntries = computed(() => (selected.value ? (props.calendar.days[selected.value] ?? []) : []))
const selectedLabel = computed(() =>
  selected.value
    ? parseDay(selected.value).toLocaleDateString('en', {
        weekday: 'long',
        year: 'numeric',
        month: 'long',
        day: 'numeric',
        timeZone: 'UTC',
      })
    : '',
)

function go(date: Date, scale = props.calendar.scale) {
  router.get(
    window.location.pathname,
    { view: 'calendar', scale, date: isoDay(date) },
    { preserveState: true, preserveScroll: true },
  )
}

function shift(direction: -1 | 1) {
  const date = cursor.value
  if (props.calendar.scale === 'week') date.setUTCDate(date.getUTCDate() + 7 * direction)
  else date.setUTCMonth(date.getUTCMonth() + direction, 1)
  go(date)
}

const setMonth = (month: number) => go(new Date(Date.UTC(cursor.value.getUTCFullYear(), month - 1, 1)))
const setYear = (year: number) => go(new Date(Date.UTC(year, cursor.value.getUTCMonth(), 1)))
</script>

<template>
  <section aria-label="Calendar" class="@container">
    <div class="rounded-2xl bg-gray-100 p-3 dark:bg-gray-800">
      <div class="flex flex-col items-center gap-4 pb-4 @3xl:flex-row @3xl:pb-8">
        <div class="flex w-full items-center justify-between @3xl:flex-1 @3xl:justify-start">
          <ToggleGroup
            type="single"
            variant="outline"
            :model-value="calendar.scale"
            class="flex"
            @update:model-value="(scale) => scale && go(cursor, scale as CalendarData['scale'])"
          >
            <ToggleGroupItem value="week">Week</ToggleGroupItem>
            <ToggleGroupItem value="month">Month</ToggleGroupItem>
          </ToggleGroup>

          <div class="flex items-center gap-2 @3xl:hidden">
            <Button variant="outline" size="icon" aria-label="Previous" @click="shift(-1)">
              <CpIcon name="chevron-left" />
            </Button>
            <Button variant="outline" @click="go(parseDay(calendar.today))">Today</Button>
            <Button variant="outline" size="icon" aria-label="Next" @click="shift(1)">
              <CpIcon name="chevron-right" />
            </Button>
          </div>
        </div>

        <div class="px-2 text-center @3xl:flex-1">
          <Popover>
            <PopoverTrigger
              class="cursor-pointer text-2xl font-medium text-gray-800 transition-colors hover:text-gray-600 dark:text-white dark:hover:text-gray-300"
            >
              {{ calendar.title }}
            </PopoverTrigger>
            <PopoverContent class="flex items-center gap-3">
              <div class="space-y-2">
                <Label for="calendar-month">Month</Label>
                <Select
                  :model-value="String(cursor.getUTCMonth() + 1)"
                  @update:model-value="(value) => setMonth(Number(value))"
                >
                  <SelectTrigger id="calendar-month" class="w-36"><SelectValue /></SelectTrigger>
                  <SelectContent>
                    <SelectItem v-for="month in MONTHS" :key="month.value" :value="String(month.value)">
                      {{ month.label }}
                    </SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div class="space-y-2">
                <Label for="calendar-year">Year</Label>
                <Select
                  :model-value="String(cursor.getUTCFullYear())"
                  @update:model-value="(value) => setYear(Number(value))"
                >
                  <SelectTrigger id="calendar-year" class="w-24"><SelectValue /></SelectTrigger>
                  <SelectContent>
                    <SelectItem v-for="year in YEARS" :key="year" :value="String(year)">{{ year }}</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </PopoverContent>
          </Popover>
        </div>

        <div class="hidden w-1/4 items-center justify-end gap-2 @3xl:flex @3xl:flex-1">
          <Button variant="outline" size="icon" aria-label="Previous" @click="shift(-1)">
            <CpIcon name="chevron-left" />
          </Button>
          <Button variant="outline" @click="go(parseDay(calendar.today))">Today</Button>
          <Button variant="outline" size="icon" aria-label="Next" @click="shift(1)">
            <CpIcon name="chevron-right" />
          </Button>
        </div>
      </div>

      <CalendarMonth
        v-if="calendar.scale === 'month'"
        :days="days"
        :today-weekday="todayWeekday"
        :selected="selected"
        :create-url="createUrl"
        @select="(key) => (selected = key)"
      />
      <CalendarWeek
        v-else
        :days="days"
        :selected="selected"
        :create-url="createUrl"
        @select="(key) => (selected = key)"
      />
    </div>

    <div v-if="selected" class="mt-6">
      <h2 class="pb-3 text-center text-base font-medium text-gray-800 dark:text-white">{{ selectedLabel }}</h2>
      <CpPanel v-if="selectedEntries.length" flush>
        <ul class="divide-y divide-gray-100 dark:divide-gray-800" role="list">
          <li v-for="entry in selectedEntries" :key="entry.id">
            <Link
              :href="entry.edit_url"
              class="flex items-center justify-between gap-4 px-4.5 py-3 text-sm transition-colors hover:bg-gray-50 dark:hover:bg-gray-900/60"
            >
              <span class="truncate font-medium text-gray-900 dark:text-white">{{ entry.title ?? 'Untitled' }}</span>
              <StatusCell :value="entry.status" />
            </Link>
          </li>
        </ul>
      </CpPanel>
      <p
        v-else
        class="rounded-lg border border-dashed border-gray-300 py-6 text-center text-gray-500 dark:border-gray-700 dark:text-gray-400"
      >
        No results
      </p>
    </div>
  </section>
</template>
