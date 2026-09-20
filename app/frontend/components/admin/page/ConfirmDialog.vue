<script setup lang="ts">
import {
  AlertDialog,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { answerConfirm, useConfirmState } from '@/lib/confirm'

const state = useConfirmState()
</script>

<template>
  <AlertDialog :open="state.open" @update:open="(open) => !open && answerConfirm(false)">
    <AlertDialogContent class="sm:max-w-md">
      <AlertDialogHeader>
        <AlertDialogTitle>{{ state.title }}</AlertDialogTitle>
        <AlertDialogDescription v-if="state.description">{{ state.description }}</AlertDialogDescription>
      </AlertDialogHeader>
      <div v-if="state.fields?.length" class="space-y-3">
        <div v-for="field in state.fields" :key="field.handle" class="space-y-2">
          <Label :for="`confirm-${field.handle}`">{{ field.label }}</Label>
          <Input
            v-if="!field.options.length"
            :id="`confirm-${field.handle}`"
            v-model="state.values[field.handle]"
            @keydown.enter.prevent="answerConfirm(true)"
          />
          <Select v-else v-model="state.values[field.handle]">
            <SelectTrigger :id="`confirm-${field.handle}`" class="w-full"><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem v-for="option in field.options" :key="option.value" :value="option.value">{{
                option.label
              }}</SelectItem>
            </SelectContent>
          </Select>
        </div>
      </div>
      <AlertDialogFooter>
        <!-- Not AlertDialogAction: its DialogClose resolves the confirm as false before our handler runs. -->
        <Button variant="ghost" @click="answerConfirm(false)">{{ state.cancelText }}</Button>
        <Button :variant="state.dangerous ? 'destructive' : 'default'" @click="answerConfirm(true)">
          {{ state.confirmText }}
        </Button>
      </AlertDialogFooter>
    </AlertDialogContent>
  </AlertDialog>
</template>
