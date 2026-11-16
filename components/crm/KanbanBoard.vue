<script setup lang="ts">
import { computed, ref, watch, onMounted, onUnmounted } from 'vue'
import { VueDraggable } from 'vue-draggable-plus'
import { Phone, Lock, Bot, Eye, EyeOff } from 'lucide-vue-next'

const props = defineProps<{
  columns: Record<string, { leads: any[]; total: number; loading: boolean; error: string }>
  stages: any[]
}>()

const emit = defineEmits<{
  (e: 'load-more', key: string, reset?: boolean): void
  (e: 'update-status', id: string, newStage: any): void
  (e: 'view-details', lead: any): void
}>()

const localColumns = ref<any>({})

// Auto-scroll & Dragging states (devem vir ANTES do Watch para evitar Temporal Dead Zone)
const kanbanRef = ref<HTMLElement | null>(null)
let scrollInterval: ReturnType<typeof setInterval> | null = null
const isDragging = ref(false)
const hideNumbers = ref(false)
const reducedMotion = ref(false)
const mobile = ref(false)
const selectedStage = ref('')
const activeStage = computed(() => props.stages.some(stage => stage.estagio === selectedStage.value)
  ? selectedStage.value : props.stages[0]?.estagio)
let mobileQuery: MediaQueryList | undefined
const updateViewport = () => { mobile.value = mobileQuery?.matches ?? false }
let motionPreference: MediaQueryList | undefined

watch(() => props.stages.map(stage => props.columns[stage.estagio]?.leads), () => {
  if (isDragging.value) return
  localColumns.value = Object.fromEntries(props.stages.map(stage => [stage.id, [...(props.columns[stage.estagio]?.leads ?? [])]]))
}, { immediate: true })

function loadOnScroll(event: Event, key: string) {
  const element = event.currentTarget as HTMLElement
  const column = props.columns[key]
  if (!isDragging.value && column && !column.error && element.scrollHeight - element.clientHeight - element.scrollTop < 280) {
    emit('load-more', key)
  }
}

const handleDrop = (event: { data?: { id: string } }, stage: any) => {
  if (event.data?.id) emit('update-status', event.data.id, stage)
}

// Auto-scroll logic

const onDragStart = () => { isDragging.value = true }
const onDragEnd = () => { isDragging.value = false; stopDragScroll() }

const handleDragScroll = (e: MouseEvent) => {
  if (!isDragging.value) return
  const container = kanbanRef.value
  if (!container) return
  
  const rect = container.getBoundingClientRect()
  const edgeZone = 80
  const scrollSpeed = 12
  
  if (scrollInterval) {
    clearInterval(scrollInterval)
    scrollInterval = null
  }
  
  if (e.clientX - rect.left < edgeZone) {
    scrollInterval = setInterval(() => {
      container.scrollLeft -= scrollSpeed
    }, 16)
  } else if (rect.right - e.clientX < edgeZone) {
    scrollInterval = setInterval(() => {
      container.scrollLeft += scrollSpeed
    }, 16)
  }
}

const stopDragScroll = () => {
  if (scrollInterval) {
    clearInterval(scrollInterval)
    scrollInterval = null
  }
}

onMounted(() => {
  mobileQuery = window.matchMedia('(max-width: 1023px)')
  updateViewport()
  mobileQuery.addEventListener('change', updateViewport)
  motionPreference = window.matchMedia('(prefers-reduced-motion: reduce)')
  reducedMotion.value = motionPreference.matches
  motionPreference.addEventListener('change', updateMotion)
  document.addEventListener('mousemove', handleDragScroll)
  document.addEventListener('mouseup', stopDragScroll)
  document.addEventListener('dragend', stopDragScroll)
})
const updateMotion = (event: MediaQueryListEvent) => { reducedMotion.value = event.matches }

const getStageColorClasses = (estagio: string) => {
  const norm = estagio?.toLowerCase() || '';
  if (norm.includes('novo')) return { bg: 'bg-orange-50 dark:bg-orange-500/10 border-orange-100 dark:border-orange-500/20', text: 'text-orange-700 dark:text-orange-400', dot: 'bg-orange-500' };
  if (norm.includes('atendimento')) return { bg: 'bg-blue-50 dark:bg-blue-500/10 border-blue-100 dark:border-blue-500/20', text: 'text-blue-700 dark:text-blue-400', dot: 'bg-blue-500' };
  if (norm.includes('negociacao') || norm.includes('negociação')) return { bg: 'bg-indigo-50 dark:bg-indigo-500/10 border-indigo-100 dark:border-indigo-500/20', text: 'text-indigo-700 dark:text-indigo-400', dot: 'bg-indigo-500' };
  if (norm.includes('visita')) return { bg: 'bg-fuchsia-50 dark:bg-fuchsia-500/10 border-fuchsia-100 dark:border-fuchsia-500/20', text: 'text-fuchsia-700 dark:text-fuchsia-400', dot: 'bg-fuchsia-500' };
  if (norm.includes('fechado') || norm.includes('convertido') || norm.includes('venda')) return { bg: 'bg-emerald-50 dark:bg-emerald-500/10 border-emerald-100 dark:border-emerald-500/20', text: 'text-emerald-700 dark:text-emerald-400', dot: 'bg-emerald-500' };
  if (norm.includes('perdido')) return { bg: 'bg-red-50 dark:bg-red-500/10 border-red-100 dark:border-red-500/20', text: 'text-red-700 dark:text-red-400', dot: 'bg-red-500' };
  
  return { bg: 'bg-gray-50 dark:bg-gray-800/50 border-gray-200 dark:border-gray-700', text: 'text-gray-700 dark:text-gray-300', dot: 'bg-gray-500' };
}

onUnmounted(() => {
  mobileQuery?.removeEventListener('change', updateViewport)
  stopDragScroll()
  motionPreference?.removeEventListener('change', updateMotion)
  document.removeEventListener('mousemove', handleDragScroll)
  document.removeEventListener('mouseup', stopDragScroll)
  document.removeEventListener('dragend', stopDragScroll)
})
</script>

<template>
  <div class="flex h-full min-h-0 flex-col">
    <div class="mb-3 flex flex-wrap items-center justify-between gap-2 lg:justify-end">
      <label class="flex min-w-0 flex-1 flex-col gap-1 text-xs font-semibold text-gray-600 dark:text-dark-muted lg:hidden">
        Etapa do Kanban
        <select :value="activeStage" class="min-h-11 w-full min-w-0 rounded-lg border border-gray-200 bg-white px-2 text-base font-medium text-gray-900 dark:border-dark-border dark:bg-dark-surface dark:text-white"
          @change="selectedStage = ($event.target as HTMLSelectElement).value">
          <option v-for="stage in stages" :key="stage.id" :value="stage.estagio">
            {{ stage.estagio_name || stage.descricao || stage.estagio }} ({{ (columns[stage.estagio]?.total ?? 0).toLocaleString('pt-BR') }})
          </option>
        </select>
      </label>
      <button type="button" @click="hideNumbers = !hideNumbers"
        class="mt-auto inline-flex h-11 w-11 shrink-0 items-center justify-center gap-2 rounded-lg border border-gray-200 bg-white text-gray-700 dark:border-dark-border dark:bg-dark-surface dark:text-gray-200 sm:w-auto sm:px-3"
        :aria-label="hideNumbers ? 'Mostrar números' : 'Ocultar números'">
        <Eye v-if="hideNumbers" class="h-4 w-4" aria-hidden="true" />
        <EyeOff v-else class="h-4 w-4" aria-hidden="true" />
        <span class="hidden text-sm font-medium sm:inline">{{ hideNumbers ? 'Mostrar números' : 'Ocultar números' }}</span>
      </button>
    </div>

    <div ref="kanbanRef" class="flex min-h-0 flex-1 gap-5 lg:overflow-x-auto lg:pb-3 kanban-scroll">
      <div 
        v-for="col in stages" 
        :key="col.id" 
        class="h-full min-w-0 w-full flex-col lg:flex lg:w-[300px] lg:shrink-0"
        :class="col.estagio === activeStage ? 'flex' : 'hidden'"
      >
        <!-- Column Header -->
        <div class="hidden px-1 lg:mb-4 lg:block">
          <div 
            :class="[
              'flex items-center justify-between px-3 py-2.5 rounded-xl border',
              getStageColorClasses(col.estagio).bg
            ]"
          >
            <div class="flex items-center gap-2.5">
              <div :class="['w-2.5 h-2.5 rounded-full', getStageColorClasses(col.estagio).dot]"></div>
              <span :class="['text-xs font-bold uppercase tracking-wider', getStageColorClasses(col.estagio).text]">
                {{ col.estagio_name || col.descricao || col.estagio }}
              </span>
            </div>
            <span :class="['text-[10px] font-bold px-2 py-0.5 rounded-full bg-white/60 dark:bg-black/20 shadow-sm', getStageColorClasses(col.estagio).text]">
              {{ columns[col.estagio]?.loading && !columns[col.estagio]?.leads.length ? '…' : (columns[col.estagio]?.total ?? 0).toLocaleString('pt-BR') }}
            </span>
          </div>
        </div>

        <div class="flex-1 min-h-0 overflow-y-auto" @scroll.passive="loadOnScroll($event, col.estagio)">
        <!-- Draggable Area -->
        <VueDraggable
          v-if="localColumns[col.id]"
          v-model="localColumns[col.id]"
          :group="{ name: 'crm-leads' }"
          :animation="reducedMotion ? 0 : 160"
          :sort="false"
          :disabled="mobile"
          ghost-class="ghost-card"
          class="flex flex-col gap-3 min-h-[100px] p-1"
          @start="onDragStart"
          @end="onDragEnd"
          @add="(e) => handleDrop(e, col)"
        >
          <div 
            v-for="lead in localColumns[col.id]"
            :key="lead.id" 
            class="bg-white/80 dark:bg-dark-surface/80 backdrop-blur-xl border border-gray-100/50 dark:border-dark-border/50 rounded-2xl p-3 sm:p-5 lg:cursor-grab lg:active:cursor-grabbing shadow-card hover:shadow-luxury lg:hover:-translate-y-1 transition-all duration-300 group flex flex-col justify-between relative overflow-hidden min-h-[156px] gap-3 lg:h-[195px] shrink-0"
          >
            <!-- Subtle top accent -->
            <div class="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-primary-400 to-primary-600 opacity-0 group-hover:opacity-100 transition-opacity duration-300"></div>

            <!-- Header: Avatar + Name -->
            <div class="flex items-center gap-3">
              <div v-if="lead.media_url" class="w-12 h-12 rounded-xl flex-shrink-0 overflow-hidden border border-gray-100 dark:border-dark-border">
                <img :src="lead.media_url" loading="lazy" :alt="lead.name || 'Avatar'" class="w-full h-full object-cover" />
              </div>
              <div v-else class="w-12 h-12 shrink-0 rounded-xl bg-primary-50 dark:bg-primary-500/10 flex items-center justify-center text-lg font-serif font-bold text-primary-600 dark:text-primary-400 border border-primary-100 dark:border-primary-500/20">
                {{ (lead.name || 'D').charAt(0).toUpperCase() }}
              </div>
              <div class="flex-1 min-w-0">
                 <span class="font-serif font-semibold text-gray-900 dark:text-white text-base block truncate tracking-tight">{{ lead.name || 'Desconhecido' }}</span>
              </div>
              <button 
                @click="emit('view-details', lead)"
                class="flex h-11 w-11 shrink-0 items-center justify-center text-gray-500 hover:text-primary-500 hover:bg-primary-50 dark:hover:bg-primary-500/10 rounded-xl transition-all bg-white/50 dark:bg-dark-bg/50 backdrop-blur-sm"
                aria-label="Ver Detalhes"
              >
                <Eye class="w-4 h-4" />
              </button>
            </div>

            <!-- Phone -->
            <div class="flex items-center gap-2 text-gray-500 dark:text-dark-muted text-sm bg-gray-50/80 dark:bg-dark-card/80 p-3 rounded-xl border border-gray-100/50 dark:border-dark-border/50">
               <Phone class="w-4 h-4 flex-shrink-0 text-primary-400" />
               <span class="min-w-0 break-all font-mono tracking-wide">{{ hideNumbers ? '***' : (lead.phone || 'Sem número') }}</span>
            </div>

            <!-- Footer: Badges -->
            <div class="flex items-center justify-between">
              <span 
                v-if="lead.stage === 'novo' || lead.stage === 'em_atendimento'" 
                class="text-[10px] font-medium px-2.5 py-1 rounded-full bg-gray-100 dark:bg-dark-card text-gray-400 shadow-sm"
              >
                Não qualificado
              </span>
              <span 
                v-else-if="lead.stage === 'negociacao' || lead.stage === 'visita'" 
                class="text-[10px] font-medium px-2.5 py-1 rounded-full bg-emerald-50 dark:bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border border-emerald-100 dark:border-emerald-500/20 shadow-sm"
              >
                Qualificado
              </span>
              <span 
                v-else-if="lead.stage === 'fechado' || lead.stage === 'convertido'" 
                class="text-[10px] font-medium px-2.5 py-1 rounded-full bg-green-50 dark:bg-green-500/10 text-green-600 dark:text-green-400 border border-green-100 dark:border-green-500/20 shadow-sm"
              >
                Fechado
              </span>
              <span 
                v-else-if="lead.stage === 'perdido'" 
                class="text-[10px] font-medium px-2.5 py-1 rounded-full bg-red-50 dark:bg-red-500/10 text-red-600 dark:text-red-400 border border-red-100 dark:border-red-500/20 shadow-sm"
              >
                Perdido
              </span>
              <span 
                v-else-if="lead.is_qualified" 
                class="text-[10px] font-medium px-2.5 py-1 rounded-full bg-emerald-50 dark:bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border border-emerald-100 dark:border-emerald-500/20 shadow-sm"
              >
                Qualificado
              </span>
              <span 
                v-else 
                class="text-[10px] font-medium px-2.5 py-1 rounded-full bg-gray-100 dark:bg-dark-card text-gray-400 shadow-sm"
              >
                Não qualificado
              </span>

              <div v-if="lead.agent_active === false" class="text-amber-500" title="Modo Manual (Travado)">
                 <Lock class="w-3.5 h-3.5" />
              </div>
              <div v-else class="text-primary-500" title="Modo Automático (IA)">
                 <Bot class="w-3.5 h-3.5" />
              </div>
            </div>
          </div>

        </VueDraggable>
        <div class="px-2 py-3 text-center text-xs text-gray-600 dark:text-dark-muted">
          <span v-if="columns[col.estagio]?.loading" role="status">Carregando leads…</span>
          <button v-else-if="columns[col.estagio]?.error" type="button" class="min-h-11 rounded-md border px-3" @click="emit('load-more', col.estagio, true)">
            {{ columns[col.estagio]?.error }} Tentar novamente
          </button>
          <button v-else-if="(columns[col.estagio]?.leads.length ?? 0) < (columns[col.estagio]?.total ?? 0)" type="button"
            class="min-h-11 rounded-md border border-gray-200 px-3 hover:text-primary-600 dark:border-dark-border"
            @click="emit('load-more', col.estagio)">Carregar mais leads</button>
          <span v-else-if="columns[col.estagio]?.total === 0">Nenhum lead nesta etapa</span>
        </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.ghost-card {
  opacity: 0.4;
  background: #F3F4F6;
  border: 1px dashed #D1D5DB;
}

:root.dark .ghost-card {
  background: #1F2937;
  border: 1px dashed #374151;
}

.hide-scrollbar {
  -ms-overflow-style: none;  /* IE and Edge */
  scrollbar-width: none;  /* Firefox */
}
.hide-scrollbar::-webkit-scrollbar {
  display: none;
}

.kanban-scroll {
  scrollbar-width: auto;
  scrollbar-color: #93C5FD #E5E7EB;
}

:root.dark .kanban-scroll {
  scrollbar-color: #1E40AF #1F2937;
}

.kanban-scroll::-webkit-scrollbar {
  height: 10px;
}

.kanban-scroll::-webkit-scrollbar-track {
  background: #E5E7EB;
  border-radius: 8px;
}

:root.dark .kanban-scroll::-webkit-scrollbar-track {
  background: #1F2937;
}

.kanban-scroll::-webkit-scrollbar-thumb {
  background: #93C5FD;
  border-radius: 8px;
  border: 2px solid #E5E7EB;
}

.kanban-scroll::-webkit-scrollbar-thumb:hover {
  background: #60A5FA;
}

:root.dark .kanban-scroll::-webkit-scrollbar-thumb {
  background: #1E40AF;
  border: 2px solid #1F2937;
}

:root.dark .kanban-scroll::-webkit-scrollbar-thumb:hover {
  background: #2563EB;
}
</style>
