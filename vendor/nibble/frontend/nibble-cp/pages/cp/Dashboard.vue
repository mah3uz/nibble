<script setup lang="ts">
import { Deferred, Link } from '@inertiajs/vue3'
import { computed, ref, type Component } from 'vue'
import CustomizeDashboardDialog from '@/components/cp/dashboard/CustomizeDashboardDialog.vue'
import ActivityChartWidget from '@/components/cp/dashboard/ActivityChartWidget.vue'
import ActivityWidget from '@/components/cp/dashboard/ActivityWidget.vue'
import AwaitingReviewWidget from '@/components/cp/dashboard/AwaitingReviewWidget.vue'
import CommentsWidget from '@/components/cp/dashboard/CommentsWidget.vue'
import ContentMixWidget from '@/components/cp/dashboard/ContentMixWidget.vue'
import FailuresWidget from '@/components/cp/dashboard/FailuresWidget.vue'
import FormSubmissionsWidget from '@/components/cp/dashboard/FormSubmissionsWidget.vue'
import MissingPagesWidget from '@/components/cp/dashboard/MissingPagesWidget.vue'
import OverviewWidget from '@/components/cp/dashboard/OverviewWidget.vue'
import SiteHealthWidget from '@/components/cp/dashboard/SiteHealthWidget.vue'
import UploadsWidget from '@/components/cp/dashboard/UploadsWidget.vue'
import ContentHealthWidget from '@/components/cp/dashboard/ContentHealthWidget.vue'
import QuickLinksWidget from '@/components/cp/dashboard/QuickLinksWidget.vue'
import RecentEntriesWidget from '@/components/cp/dashboard/RecentEntriesWidget.vue'
import ScheduledWidget from '@/components/cp/dashboard/ScheduledWidget.vue'
import type { AvailableWidget, WidgetLayoutItem } from '@/components/cp/dashboard/types'
import DraftsWidget from '@/components/cp/dashboard/DraftsWidget.vue'
import CpPanel from '@/components/cp/page/CpPanel.vue'
import PageHeader from '@/components/cp/page/PageHeader.vue'
import { Button } from '@/components/ui/button'
import { Skeleton } from '@/components/ui/skeleton'

const props = defineProps<{
  layout: WidgetLayoutItem[]
  data?: Record<string, unknown>
  available: AvailableWidget[]
}>()

// Tailwind's scanner needs literal class strings, not `col-span-${n}` built at runtime.
const WIDTH_CLASS: Record<number, string> = {
  33: 'col-span-12 md:col-span-4',
  50: 'col-span-12 md:col-span-6',
  66: 'col-span-12 md:col-span-8',
  100: 'col-span-12 md:col-span-12',
}

const WIDGET_COMPONENTS: Record<string, Component> = {
  overview: OverviewWidget,
  activity_chart: ActivityChartWidget,
  content_mix: ContentMixWidget,
  awaiting_review: AwaitingReviewWidget,
  form_submissions: FormSubmissionsWidget,
  missing_pages: MissingPagesWidget,
  site_health: SiteHealthWidget,
  failures: FailuresWidget,
  comments: CommentsWidget,
  uploads: UploadsWidget,
  recent_entries: RecentEntriesWidget,
  scheduled: ScheduledWidget,
  drafts: DraftsWidget,
  activity: ActivityWidget,
  content_health: ContentHealthWidget,
  quick_links: QuickLinksWidget,
}

const labelFor = (type: string) => props.available.find((widget) => widget.type === type)?.label ?? type
const customizeOpen = ref(false)
const layout = computed(() => props.layout.filter((widget) => WIDGET_COMPONENTS[widget.type]))

const createUrl = computed(() => (props.data?.recent_entries as { create_url?: string | null } | undefined)?.create_url)
</script>

<template>
  <div>
    <PageHeader title="Dashboard" icon="dashboard">
      <template #actions>
        <Button type="button" variant="outline" @click="customizeOpen = true">Customize</Button>
      </template>
    </PageHeader>

    <CpPanel v-if="!layout.length">
      <p class="text-sm text-gray-600 dark:text-gray-400">
        No widgets on your dashboard yet.
        <button type="button" class="font-medium text-gray-900 underline dark:text-white" @click="customizeOpen = true">
          Add some</button
        >.
      </p>
    </CpPanel>
    <div v-else class="grid grid-cols-12 gap-6">
      <div
        v-for="widget in layout"
        :key="widget.type"
        :class="[WIDTH_CLASS[widget.width], widget.type === 'overview' ? '' : 'min-h-64']"
        :style="widget.height ? { height: widget.height } : undefined"
      >
        <CpPanel :title="labelFor(widget.type)" flush fill>
          <template v-if="widget.type === 'recent_entries' && createUrl" #actions>
            <Button as-child variant="outline" size="sm"><Link :href="createUrl">New entry</Link></Button>
          </template>
          <Deferred :data="`data.${widget.type}`">
            <template #fallback>
              <div class="space-y-2.5 px-4.5 py-4">
                <Skeleton class="h-4 w-full" /><Skeleton class="h-4 w-3/4" /><Skeleton class="h-4 w-1/2" />
              </div>
            </template>
            <template #default>
              <component :is="WIDGET_COMPONENTS[widget.type]" :data="data?.[widget.type]" />
            </template>
          </Deferred>
        </CpPanel>
      </div>
    </div>

    <CustomizeDashboardDialog v-model:open="customizeOpen" :layout="props.layout" :available="available" />
  </div>
</template>
