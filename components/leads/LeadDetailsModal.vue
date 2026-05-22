<script setup lang="ts">
import { ref, watch, computed } from 'vue'
import { User, Phone, Calendar, Package, X, TrendingUp } from 'lucide-vue-next'
import type { Cliente } from '@/types/crm'

const props = defineProps<{
  modelValue: boolean
  lead: Cliente | null
  stages?: any[]
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'update-status', id: string, status: string): void
  (e: 'save-notes', id: string, notes: string): void
}>()

const localNotes = ref('')

// Sync state when lead changes
watch(() => props.lead, (newLead) => {
  if (newLead) {
    localNotes.value = newLead.about || ''
  }
}, { immediate: true })

const close = () => emit('update:modelValue', false)

const isNotesModified = computed(() => {
  return localNotes.value !== (props.lead?.about || '')
})

const handleCancelNotes = () => {
  localNotes.value = props.lead?.about || ''
}

const handleSaveNotes = async () => {
  if (!props.lead) return
  emit('save-notes', props.lead.id, localNotes.value)
}

const formatDate = (dateString?: string) => {
  if (!dateString) return 'Desconhecido'
  return new Date(dateString).toLocaleDateString('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  })
}

const formatPhone = (phone?: string | null, remotejid?: string | null) => {
  const raw = phone || remotejid || ''
  return raw.replace('@c.us', '')
}

const formatRelativeTime = (dateString?: string) => {
  if (!dateString) return 'Desconhecido'
  const date = new Date(dateString)
  const now = new Date()
  const diffInSeconds = Math.floor((now.getTime() - date.getTime()) / 1000)
  
  if (diffInSeconds < 60) return 'Agora mesmo'
  if (diffInSeconds < 3600) {
    const m = Math.floor(diffInSeconds / 60)
    return `${m} minuto${m > 1 ? 's' : ''} atrás`
  }
  if (diffInSeconds < 86400) {
    const h = Math.floor(diffInSeconds / 3600)
    return `${h} hora${h > 1 ? 's' : ''} atrás`
  }
  if (diffInSeconds < 2592000) {
    const d = Math.floor(diffInSeconds / 86400)
    return `${d} dia${d > 1 ? 's' : ''} atrás`
  }
  if (diffInSeconds < 31536000) {
    const m = Math.floor(diffInSeconds / 2592000)
    return `${m} mês${m > 1 ? 'es' : ''} atrás`
  }
  const y = Math.floor(diffInSeconds / 31536000)
  return `${y} ano${y > 1 ? 's' : ''} atrás`
}

const computedScore = computed(() => {
  if (!props.lead || !props.stages || props.stages.length === 0) {
    // Fallback to static mapping if stages are empty or not loaded
    const leadStage = props.lead?.stage || props.lead?.estagiokanbam || 'novo'
    switch (leadStage) {
      case 'novo': return 'C'
      case 'qualificando': return 'B'
      case 'qualificado': return 'A'
      case 'agendado': return 'A+'
      case 'fechado':
      case 'convertido': return 'A++'
      case 'perdido': return 'F'
      default: return props.lead?.score || 'C'
    }
  }
  
  const leadStage = props.lead.stage || props.lead.estagiokanbam || 'novo'
  const leadStageId = props.lead.stage_id
  
  // Find the index of the stage in props.stages
  const stageIndex = props.stages.findIndex(s => s.estagio === leadStage || s.id === leadStageId)
  
  if (stageIndex === -1) {
    return props.lead.score || 'C'
  }
  
  const stageObj = props.stages[stageIndex]
  if (stageObj.estagio === 'perdido') {
    return 'F'
  }
  
  // First column -> C, then B, A, A+, A++...
  const scores = ['C', 'B', 'A', 'A+', 'A++']
  return scores[stageIndex] || 'A++'
})

const currentStageLabel = computed(() => {
  if (!props.lead) return 'Desconhecido'
  const leadStage = props.lead.stage || props.lead.estagiokanbam || 'novo'
  const stageObj = props.stages?.find(s => s.estagio === leadStage || s.id === props.lead?.stage_id)
  if (stageObj) {
    return stageObj.estagio_name || stageObj.descricao || stageObj.estagio
  }
  // Simple mapping if stages list is not loaded
  const fallbackOptions: Record<string, string> = {
    novo: 'Novo',
    qualificando: 'Qualificando',
    qualificado: 'Qualificado',
    agendado: 'Visita',
    fechado: 'Fechado',
    convertido: 'Fechado',
    perdido: 'Perdido'
  }
  return fallbackOptions[leadStage] || leadStage
})

const currentStageBadgeClasses = computed(() => {
  const leadStage = props.lead?.stage || props.lead?.estagiokanbam || 'novo'
  switch (leadStage) {
    case 'novo':
      return 'bg-blue-50 dark:bg-blue-500/10 text-blue-600 dark:text-blue-400 border border-blue-200 dark:border-blue-500/20 shadow-sm'
    case 'em_atendimento':
    case 'qualificando':
      return 'bg-violet-50 dark:bg-violet-500/10 text-violet-600 dark:text-violet-400 border border-violet-200 dark:border-violet-500/20 shadow-sm'
    case 'negociacao':
    case 'qualificado':
      return 'bg-amber-50 dark:bg-amber-500/10 text-amber-600 dark:text-amber-400 border border-amber-200 dark:border-amber-500/20 shadow-sm'
    case 'visita':
    case 'agendado':
      return 'bg-emerald-50 dark:bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border border-emerald-200 dark:border-emerald-500/20 shadow-sm'
    case 'fechado':
    case 'convertido':
      return 'bg-green-50 dark:bg-green-500/10 text-green-600 dark:text-green-400 border border-green-200 dark:border-green-500/20 shadow-sm'
    case 'perdido':
      return 'bg-red-50 dark:bg-red-500/10 text-red-600 dark:text-red-400 border border-red-200 dark:border-red-500/20 shadow-sm'
    default:
      return 'bg-gray-100 dark:bg-dark-bg text-gray-500 dark:text-gray-400 border border-gray-200 dark:border-dark-border'
  }
})
</script>

<template>
  <!-- Teleport to body for true popup behavior -->
  <Teleport to="body">
    <Transition name="modal">
      <div 
        v-if="modelValue && lead" 
        class="fixed inset-0 z-50 flex items-center justify-center p-4"
        @click.self="close"
      >
        <!-- Backdrop -->
        <div class="absolute inset-0 bg-gray-900/40 dark:bg-black/80 backdrop-blur-sm"></div>
        
        <!-- Modal Card -->
        <div class="relative bg-white dark:bg-dark-surface border border-gray-200 dark:border-dark-border rounded-sm shadow-luxury max-w-2xl w-full max-h-[90vh] overflow-y-auto">
          
          <!-- Header -->
          <div class="flex items-center justify-between p-6 border-b border-gray-200 dark:border-dark-border sticky top-0 bg-white dark:bg-dark-surface z-10">
            <div class="flex items-center gap-3">
              <User class="w-5 h-5 text-primary-500" />
              <h2 class="text-xl font-bold text-gray-900 dark:text-white">Detalhes do Interessado</h2>
            </div>
            <button 
              @click="close" 
              class="p-2 text-gray-400 hover:text-gray-900 dark:hover:text-white hover:bg-gray-100 dark:hover:bg-white/10 rounded-sm transition-all"
            >
              <X class="w-5 h-5" />
            </button>
          </div>

          <!-- Body -->
          <div class="p-6 space-y-6">
            
            <!-- Info Grid -->
            <div class="grid grid-cols-2 gap-6">
              
              <!-- Nome e Avatar -->
              <div class="col-span-2 flex items-center gap-4 border-b border-gray-200 dark:border-dark-border pb-6 mb-2">
                <div v-if="lead.media_url" class="w-16 h-16 rounded-sm flex-shrink-0 overflow-hidden border border-gray-200 dark:border-dark-border shadow-sm">
                  <img :src="lead.media_url" :alt="lead.name || 'Avatar'" class="w-full h-full object-cover" />
                </div>
                <div v-else class="w-16 h-16 rounded-sm bg-primary-100 dark:bg-primary-900/40 flex items-center justify-center text-primary-600 dark:text-primary-500 font-bold text-2xl flex-shrink-0 shadow-sm border border-transparent">
                  {{ (lead.name || 'D').charAt(0).toUpperCase() }}
                </div>
                <div class="space-y-1">
                  <span class="text-xs font-semibold text-gray-400 dark:text-dark-muted uppercase tracking-wide">Nome</span>
                  <p class="text-2xl font-bold text-gray-900 dark:text-white">{{ lead.name || 'Desconhecido' }}</p>
                </div>
              </div>

              <!-- Telefone -->
              <div class="space-y-1">
                <span class="text-xs font-semibold text-gray-400 dark:text-dark-muted uppercase tracking-wide">Telefone</span>
                <div class="flex items-center gap-2 text-lg text-gray-900 dark:text-white">
                  <Phone class="w-4 h-4 text-primary-500" />
                  <span>{{ formatPhone(lead.phone, lead.remotejid) }}</span>
                </div>
              </div>

              <!-- Data de Cadastro -->
              <div class="space-y-1">
                <span class="text-xs font-semibold text-gray-400 dark:text-dark-muted uppercase tracking-wide">Cadastrado em</span>
                <div class="flex items-center gap-2 text-gray-900 dark:text-white">
                  <Calendar class="w-4 h-4 text-gray-400 dark:text-gray-500" />
                  <span class="text-sm font-medium">{{ formatDate(lead.created_at) }}</span>
                </div>
              </div>

              <!-- Interesse -->
              <div class="space-y-1">
                <span class="text-xs font-semibold text-gray-400 dark:text-dark-muted uppercase tracking-wide">Avaliação</span>
                <div>
                  <span 
                    :class="['inline-flex px-3 py-1 rounded-sm text-xs font-bold border shadow-sm', currentStageBadgeClasses]"
                  >
                    {{ currentStageLabel }}
                  </span>
                </div>
              </div>

              <!-- Vertical / Produto -->
              <div class="col-span-1 space-y-1">
                <span class="text-xs font-semibold text-gray-400 dark:text-dark-muted uppercase tracking-wide">Interesse</span>
                <div class="flex items-center gap-2 text-gray-900 dark:text-white">
                  <Package class="w-4 h-4 text-primary-500" />
                  <span class="text-sm font-medium">{{ lead.about || 'Não informado' }}</span>
                </div>
              </div>

              <!-- Score -->
              <div class="col-span-1 space-y-1">
                <span class="text-xs font-semibold text-gray-400 dark:text-dark-muted uppercase tracking-wide">Score IA</span>
                <div class="flex items-center gap-2 text-gray-900 dark:text-white">
                  <TrendingUp class="w-4 h-4 text-primary-500" />
                  <span class="font-bold text-sm">{{ computedScore }}</span>
                </div>
              </div>

            </div>

            <!-- Divider -->
            <div class="h-px bg-gray-200 dark:bg-dark-border"></div>

            <!-- Actions -->
            <div class="space-y-4">
              
              <!-- Notes -->
              <div class="space-y-2">
                <label class="text-xs font-semibold text-gray-400 dark:text-dark-muted uppercase tracking-wide">Observações</label>
                <textarea
                  v-model="localNotes"
                  placeholder="Adicione observações sobre o perfil deste interessado..."
                  rows="4"
                  class="w-full bg-gray-50 dark:bg-dark-bg border border-gray-200 dark:border-dark-border text-gray-900 dark:text-white placeholder-gray-400 dark:placeholder-gray-500 rounded-sm px-4 py-3 focus:outline-none focus:ring-1 focus:ring-primary-500 resize-none text-sm shadow-sm"
                ></textarea>
                
                <!-- Cancel / Save Buttons -->
                <Transition name="fade">
                  <div v-if="isNotesModified" class="flex justify-end gap-2 pt-1">
                    <button
                      @click="handleCancelNotes"
                      class="px-4 py-2 text-xs font-semibold text-gray-500 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white transition-colors duration-200"
                    >
                      Cancelar
                    </button>
                    <button
                      @click="handleSaveNotes"
                      class="px-4 py-2 text-xs font-semibold text-white bg-primary-500 hover:bg-primary-600 rounded-sm shadow-sm transition-colors duration-200"
                    >
                      Salvar Observações
                    </button>
                  </div>
                </Transition>
              </div>

            </div>
          </div>

          <!-- Footer -->
          <div class="flex items-center justify-between px-6 py-4 border-t border-gray-200 dark:border-dark-border text-xs text-gray-500 dark:text-dark-muted bg-gray-50 dark:bg-dark-bg mt-2">
            <span class="font-medium">Follow-ups: {{ lead.metadata?.followups || 0 }} tentativas</span>
            <span class="font-medium">Última interação: {{ formatRelativeTime(lead.ultima_mensagem_at || lead.created_at) }}</span>
          </div>

        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.modal-enter-active,
.modal-leave-active {
  transition: opacity 0.3s ease;
}

.modal-enter-from,
.modal-leave-to {
  opacity: 0;
}

.modal-enter-active .relative,
.modal-leave-active .relative {
  transition: transform 0.3s ease;
}

.modal-enter-from .relative,
.modal-leave-to .relative {
  transform: scale(0.95);
}
</style>
