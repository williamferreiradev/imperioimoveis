<script setup lang="ts">
import { computed, ref, onMounted, onUnmounted } from 'vue'
import { VueDraggable } from 'vue-draggable-plus'
import { Phone, Lock, Bot, Eye, EyeOff } from 'lucide-vue-next'
import type { Cliente, CrmStatus } from '@/types/crm'

const props = defineProps<{
  leads: any[]
  stages: any[]
}>()

const emit = defineEmits<{
  (e: 'update-status', id: string, newStage: any): void
  (e: 'view-details', lead: any): void
}>()

const localColumns = ref<any>({})

// Auto-scroll & Dragging states (devem vir ANTES do Watch para evitar Temporal Dead Zone)
const kanbanRef = ref<HTMLElement | null>(null)
let scrollInterval: ReturnType<typeof setInterval> | null = null
const isDragging = ref(false)
const hideNumbers = ref(false)

watch(() => props.leads, (newLeads) => {
  if (!props.stages || isDragging.value) return
  
  const map: Record<string, any[]> = {}
  props.stages.forEach(col => {
    map[col.id] = newLeads.filter(l => {
      if (l.stage_id === col.id) return true
      if (!l.stage_id && l.stage === col.estagio) return true
      if (!l.stage_id && col.estagio === 'novo') return true
      return false
    })
  })
  localColumns.value = map
}, { deep: true, immediate: true })

const handleDragChange = (e: any, col: any) => {
  if (e.added) {
    const lead = e.added.element
    emit('update-status', lead.id, col)
  }
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
  document.addEventListener('mousemove', handleDragScroll)
  document.addEventListener('mouseup', stopDragScroll)
  document.addEventListener('dragend', stopDragScroll)
})

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
  stopDragScroll()
  document.removeEventListener('mousemove', handleDragScroll)
  document.removeEventListener('mouseup', stopDragScroll)
  document.removeEventListener('dragend', stopDragScroll)
})
</script>

<template>
  <div class="kanban-wrapper h-full">
    <button 
      @click="hideNumbers = !hideNumbers" 
      class="fixed bottom-6 right-6 z-50 bg-gray-900 dark:bg-white text-white dark:text-gray-900 px-4 py-2 rounded-full shadow-lg flex items-center gap-2 hover:opacity-90 transition-all text-sm font-medium"
    >
      <Eye v-if="hideNumbers" class="w-4 h-4" />
      <EyeOff v-else class="w-4 h-4" />
      {{ hideNumbers ? 'Mostrar Números' : 'Ocultar Números' }}
    </button>

    <div ref="kanbanRef" class="flex gap-5 overflow-x-auto pb-6 h-[calc(100vh-180px)] kanban-scroll">
      <div 
        v-for="col in stages" 
        :key="col.id" 
        class="min-w-[300px] w-[300px] flex flex-col h-full"
      >
        <!-- Column Header -->
        <div class="mb-4 px-1">
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
              {{ localColumns[col.id]?.length || 0 }}
            </span>
          </div>
        </div>

        <!-- Draggable Area -->
        <VueDraggable
          v-if="localColumns[col.id]"
          v-model="localColumns[col.id]"
          :group="{ name: 'crm-leads' }"
          :animation="200"
          ghost-class="ghost-card"
          class="flex-1 flex flex-col gap-3 min-h-[100px] p-1 overflow-y-auto hide-scrollbar"
          @start="onDragStart"
          @end="onDragEnd"
          @change="(e) => handleDragChange(e, col)"
        >
          <div 
            v-for="lead in localColumns[col.id]"
            :key="lead.id" 
            class="bg-white/80 dark:bg-dark-surface/80 backdrop-blur-xl border border-gray-100/50 dark:border-dark-border/50 rounded-2xl p-5 cursor-grab active:cursor-grabbing shadow-card hover:shadow-luxury hover:-translate-y-1 transition-all duration-300 group flex flex-col justify-between relative overflow-hidden h-[195px] shrink-0"
          >
            <!-- Subtle top accent -->
            <div class="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-primary-400 to-primary-600 opacity-0 group-hover:opacity-100 transition-opacity duration-300"></div>

            <!-- Header: Avatar + Name -->
            <div class="flex items-center gap-3">
              <div v-if="lead.media_url" class="w-12 h-12 rounded-xl flex-shrink-0 overflow-hidden border border-gray-100 dark:border-dark-border">
                <img :src="lead.media_url" :alt="lead.name || 'Avatar'" class="w-full h-full object-cover" />
              </div>
              <div v-else class="w-12 h-12 rounded-xl bg-primary-50 dark:bg-primary-500/10 flex items-center justify-center text-lg font-serif font-bold text-primary-600 dark:text-primary-400 border border-primary-100 dark:border-primary-500/20">
                {{ (lead.name || 'D').charAt(0).toUpperCase() }}
              </div>
              <div class="flex-1 min-w-0">
                 <span class="font-serif font-semibold text-gray-900 dark:text-white text-base block truncate tracking-tight">{{ lead.name || 'Desconhecido' }}</span>
              </div>
              <button 
                @click="emit('view-details', lead)"
                class="p-2 text-gray-400 hover:text-primary-500 hover:bg-primary-50 dark:hover:bg-primary-500/10 rounded-xl transition-all opacity-0 group-hover:opacity-100 bg-white/50 dark:bg-dark-bg/50 backdrop-blur-sm"
                title="Ver Detalhes"
              >
                <Eye class="w-4 h-4" />
              </button>
            </div>

            <!-- Phone -->
            <div class="flex items-center gap-2 text-gray-500 dark:text-dark-muted text-sm bg-gray-50/80 dark:bg-dark-card/80 p-3 rounded-xl border border-gray-100/50 dark:border-dark-border/50">
               <Phone class="w-4 h-4 flex-shrink-0 text-primary-400" />
               <span class="font-mono tracking-wider">{{ hideNumbers ? '***' : (lead.phone || 'Sem número') }}</span>
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

          <!-- Empty State -->
          <div v-if="localColumns[col.id]?.length === 0" class="flex-1 flex items-center justify-center border border-dashed border-gray-200 dark:border-dark-border bg-gray-50/30 dark:bg-dark-bg/30 rounded-sm m-1 min-h-[120px]">
            <span class="text-gray-400 dark:text-gray-500 text-xs font-medium uppercase tracking-wider">Vazio</span>
          </div>
        </VueDraggable>
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
