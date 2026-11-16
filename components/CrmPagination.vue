<script setup lang="ts">
const props = withDefaults(defineProps<{
  page: number
  pageSize: number
  total: number
  loading?: boolean
  label?: string
}>(), { loading: false, label: 'registros' })
const emit = defineEmits<{ change: [page: number] }>()

const last = computed(() => Math.max(1, Math.ceil(props.total / props.pageSize)))
const firstItem = computed(() => props.total ? (props.page - 1) * props.pageSize + 1 : 0)
const lastItem = computed(() => Math.min(props.page * props.pageSize, props.total))
const pages = computed(() => {
  const all = Array.from({ length: last.value }, (_, i) => i + 1)
  if (all.length <= 7) return all
  const from = Math.max(2, Math.min(props.page - 1, all.length - 4))
  const to = Math.min(all.length - 1, Math.max(props.page + 1, 5))
  return [1, ...(from > 2 ? ['…'] : []), ...all.slice(from - 1, to), ...(to < all.length - 1 ? ['…'] : []), all.length]
})
</script>

<template>
  <nav aria-label="Paginação" class="flex flex-wrap items-center justify-between gap-2 border-t border-gray-200 px-3 py-3 text-sm dark:border-dark-border">
    <span class="text-gray-600 dark:text-dark-muted" aria-live="polite">{{ firstItem }}–{{ lastItem }} de {{ total.toLocaleString('pt-BR') }} {{ label }}</span>
    <div class="flex flex-wrap items-center gap-1">
      <button type="button" class="page-button" aria-label="Página anterior" :disabled="loading || page <= 1" @click="emit('change', page - 1)">‹</button>
      <template v-for="(number, index) in pages" :key="index">
        <button v-if="typeof number === 'number'" type="button" class="page-button" :aria-current="page === number ? 'page' : undefined"
          :disabled="loading || page === number"
          :class="page === number ? 'bg-primary-600 text-white dark:text-white' : ''" @click="emit('change', number)">{{ number }}</button>
        <span v-else class="px-1" aria-hidden="true">…</span>
      </template>
      <button type="button" class="page-button" aria-label="Próxima página" :disabled="loading || page >= last" @click="emit('change', page + 1)">›</button>
    </div>
  </nav>
</template>

<style scoped>
.page-button { @apply min-h-9 min-w-9 rounded-md border border-gray-200 px-2 font-medium tabular-nums dark:border-dark-border; }
.page-button:enabled { @apply hover:border-primary-500 hover:text-primary-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-primary-500; }
.page-button:disabled:not([aria-current]) { @apply opacity-40; }
</style>
