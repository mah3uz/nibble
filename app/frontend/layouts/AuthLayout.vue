<script setup lang="ts">
import logo from '@/assets/nibble.svg?url'
import { Toaster } from '@/components/ui/sonner'
import 'vue-sonner/style.css'
</script>

<template>
  <div class="flex min-h-full items-center justify-center bg-muted/40 px-4 py-12">
    <div class="w-full max-w-sm">
      <div class="mb-6 flex flex-col items-center gap-2 text-lg font-semibold tracking-tight">
        <img :src="logo" alt="" class="size-14" />Nibble
      </div>
      <slot />
    </div>
    <Toaster rich-colors />
  </div>
</template>
