<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useSupabaseClient } from '#imports'
import { User, Phone, Search, Filter, Calendar, ChevronLeft, ChevronRight } from 'lucide-vue-next'
import LeadDetailsModal from '@/components/leads/LeadDetailsModal.vue'
import type { Cliente } from '@/types/crm'
import { addCalendarDays, leadPageColumns, searchLeadColumns, startOfSaoPauloDay } from '@/utils/crmQueries'

const { mainMargin } = useSidebarState()
const supabase = useSupabaseClient<any>()

// State
const contacts = ref<any[]>([])
const stages = ref<any[]>([])
const loading = ref(true)
const searchQuery = ref('')
const showModal = ref(false)
const selectedContact = ref<Cliente | null>(null)

const showFilters = ref(false)
const filterStage = ref<string>('all')
const filterDateFrom = ref('')
const filterDateTo = ref('')

const currentPage = ref(1)
const itemsPerPage = 10

const totalContacts = ref(0)
const filteredTotal = ref(0)
const loadError = ref('')
let request = 0
let detailRequest = 0
let refreshTimer: ReturnType<typeof setTimeout> | undefined
let realtimeChannel: ReturnType<typeof supabase.channel> | undefined

async function fetchContacts(page = currentPage.value) {
  const id = ++request
  loading.value = true
  loadError.value = ''
  let query = supabase.from('leads').select(leadPageColumns, { count: 'exact' })
  if (searchQuery.value.trim()) query = query.or(searchLeadColumns(searchQuery.value))
  if (filterStage.value !== 'all') query = query.eq('stage', filterStage.value)
  if (filterDateFrom.value) query = query.gte('created_at', startOfSaoPauloDay(filterDateFrom.value))
  if (filterDateTo.value) query = query.lt('created_at', startOfSaoPauloDay(addCalendarDays(filterDateTo.value, 1)))
  const offset = (page - 1) * itemsPerPage
  const result = await query.order('created_at', { ascending: false, nullsFirst: false }).order('id', { ascending: false })
    .range(offset, offset + itemsPerPage - 1)
  if (id !== request) return
  if (result.error) {
    loadError.value = 'Não foi possível carregar os contatos.'
    loading.value = false
    return
  }
  filteredTotal.value = result.count ?? 0
  const last = Math.max(1, Math.ceil(filteredTotal.value / itemsPerPage))
  if (page > last) return await fetchContacts(last)
  currentPage.value = page
  contacts.value = result.data ?? []
  if (!hasActiveFilters.value && !searchQuery.value.trim()) totalContacts.value = filteredTotal.value
  loading.value = false
}

watch([filterStage, filterDateFrom, filterDateTo, searchQuery], () => {
  clearTimeout(refreshTimer)
  ++request
  currentPage.value = 1
  loading.value = true
  refreshTimer = setTimeout(() => { void fetchContacts(1) }, 220)
})

const hasActiveFilters = computed(() => filterStage.value !== 'all' || filterDateFrom.value || filterDateTo.value)

const clearFilters = () => {
  filterStage.value = 'all'
  filterDateFrom.value = ''
  filterDateTo.value = ''
}

// CRM Stage Helpers
const getStageLabel = (stage: string, stageId?: number | null) => {
  const stageObj = stages.value.find((s: any) => s.estagio === stage || s.id === stageId)
  if (stageObj) {
    return stageObj.estagio_name || stageObj.descricao || stageObj.estagio
  }
  const fallbackOptions: Record<string, string> = {
    novo: 'Novo',
    em_atendimento: 'Em Atendimento',
    negociacao: 'Em Negociação',
    visita: 'Visita',
    agendado: 'Visita',
    fechado: 'Venda Fechada',
    convertido: 'Venda Fechada',
    perdido: 'Perdido'
  }
  return fallbackOptions[stage] || stage || 'Novo'
}

const getStageBadgeClass = (stage: string) => {
  const s = stage || 'novo'
  switch (s) {
    case 'novo':
      return 'bg-blue-50 dark:bg-blue-500/10 text-blue-600 dark:text-blue-400 border border-blue-200 dark:border-blue-500/20 shadow-sm'
    case 'em_atendimento':
      return 'bg-violet-50 dark:bg-violet-500/10 text-violet-600 dark:text-violet-400 border border-violet-200 dark:border-violet-500/20 shadow-sm'
    case 'negociacao':
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
      return 'bg-gray-100 dark:bg-dark-bg text-gray-500 dark:text-gray-400 border border-gray-200 dark:border-dark-border shadow-sm'
  }
}

async function openContactDetails(contact: Pick<Cliente, 'id'>) {
  const id = ++detailRequest
  const result = await supabase.from('leads').select('*').eq('id', contact.id).maybeSingle()
  if (id !== detailRequest) return
  if (result.error || !result.data) {
    loadError.value = 'Não foi possível carregar os detalhes do contato.'
    return
  }
  selectedContact.value = result.data as Cliente
  showModal.value = true
}

// Handle status update from modal
const handleStatusUpdate = async (id: string, newStage: any) => {
  let stageObj = newStage
  if (typeof newStage === 'string') {
    stageObj = stages.value.find((s: any) => s.estagio === newStage)
  }
  
  if (!stageObj) {
    console.error('Stage not found for status update:', newStage)
    return
  }

  try {
    const { error: updateError } = await supabase.from('leads').update({
      stage_id: stageObj.id,
      stage: stageObj.estagio
    }).eq('id', id)
    
    if (updateError) {
      loadError.value = 'Não foi possível atualizar a etapa.'
    } else {
      if (selectedContact.value?.id === id) Object.assign(selectedContact.value, { stage: stageObj.estagio, stage_id: stageObj.id })
      await fetchContacts()
    }
  } catch (err) {
    console.error('Error updating status:', err)
  }
}

// Handle notes update from modal
const handleNotesUpdate = async (id: string, notes: string) => {
  const contact = contacts.value.find(c => c.id === id)
  if (contact) {
    contact.about = notes
  }
  try {
    await supabase.from('leads').update({ about: notes }).eq('id', id)
  } catch (err) {
    console.error('Error updating notes:', err)
  }
}

onMounted(async () => {
  void fetchContacts()
  const result = await supabase.from('stage').select('id,estagio,estagio_name,descricao').order('id')
  if (!result.error) stages.value = result.data ?? []
  realtimeChannel = supabase.channel('contacts_leads_changes')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'leads' }, () => {
      clearTimeout(refreshTimer)
      refreshTimer = setTimeout(async () => {
        await fetchContacts()
        if (hasActiveFilters.value || searchQuery.value.trim()) {
          const count = await supabase.from('leads').select('id', { count: 'exact', head: true })
          if (!count.error) totalContacts.value = count.count ?? 0
        }
      }, 300)
    }).subscribe()
})

onUnmounted(() => {
  ++request
  ++detailRequest
  clearTimeout(refreshTimer)
  if (realtimeChannel) supabase.removeChannel(realtimeChannel)
})
</script>

<template>
  <div class="min-h-screen bg-gray-50 dark:bg-dark-bg text-gray-900 dark:text-white font-sans selection:bg-primary-500 selection:text-white transition-colors duration-300">
    <Sidebar />

    <main :class="[mainMargin, 'p-3 sm:p-5 xl:p-8 transition-all duration-300']">
      <!-- Header -->
      <header class="mb-8">
        <h1 class="text-2xl font-bold text-gray-900 dark:text-white">Contatos</h1>
        <p class="text-gray-400 dark:text-dark-muted text-sm mt-1">Lista de todos os contatos com filtros</p>
      </header>

      <!-- Main Card -->
      <div class="bg-white dark:bg-dark-surface rounded-xl border border-gray-200 dark:border-dark-border overflow-hidden shadow-sm transition-colors">
        
        <!-- Card Header with Icon and Count -->
        <div class="px-6 py-4 border-b border-gray-200 dark:border-dark-border flex items-center justify-between">
          <div class="flex items-center gap-3">
            <div class="p-2 bg-primary-100 dark:bg-primary-900/40 rounded-xl">
              <User class="w-5 h-5 text-primary-600 dark:text-primary-500" />
            </div>
            <h2 class="text-lg font-bold text-gray-900 dark:text-white">Diretório de Interessados</h2>
          </div>
          <div class="flex items-center gap-2">


            <!-- Filter toggle -->
            <button 
              @click="showFilters = !showFilters"
              :class="['flex items-center gap-1.5 text-xs font-medium px-3 py-1.5 rounded-lg transition-colors border', showFilters || hasActiveFilters ? 'text-primary-600 bg-primary-50 dark:bg-primary-500/10 border-primary-200 dark:border-primary-500/20' : 'text-gray-500 dark:text-dark-muted hover:text-gray-900 dark:hover:text-white hover:bg-gray-50 dark:hover:bg-dark-card border-gray-100 dark:border-dark-border']"
            >
              <Filter class="w-3.5 h-3.5" />
              <span v-if="!showFilters">Filtrar</span>
            </button>

            <span class="bg-gray-100 dark:bg-white/5 text-gray-700 dark:text-gray-300 text-xs font-bold px-3 py-1.5 rounded-full border border-gray-200 dark:border-white/10 shadow-inner">
              {{ filteredTotal }} de {{ totalContacts }}
            </span>
          </div>
        </div>

        <!-- Filters Panel -->
        <Transition name="slide">
          <div v-if="showFilters" class="px-6 py-4 border-b border-gray-200 dark:border-dark-border bg-gray-50/80 dark:bg-dark-card/30">
            <div class="flex flex-wrap items-center gap-6">
              <!-- Status Filter -->
              <div class="flex items-center gap-3 overflow-x-auto max-w-full pb-2 md:pb-0">
                <span class="text-[11px] font-semibold text-gray-400 dark:text-dark-muted uppercase tracking-wider flex-shrink-0">Status</span>
                <div class="flex gap-1.5 bg-white dark:bg-dark-surface p-1 rounded-xl border border-gray-100 dark:border-dark-border min-w-max">
                  <button 
                    v-for="opt in [
                      { value: 'all', label: 'Todos' }, 
                      { value: 'novo', label: 'Novo' }, 
                      { value: 'em_atendimento', label: 'Em Atendimento' },
                      { value: 'negociacao', label: 'Negociação' },
                      { value: 'visita', label: 'Visita' },
                      { value: 'fechado', label: 'Fechado' },
                      { value: 'perdido', label: 'Perdido' }
                    ]"
                    :key="opt.value"
                    @click="filterStage = opt.value"
                    :class="['px-3 py-1.5 rounded-lg text-xs font-semibold transition-all whitespace-nowrap', filterStage === opt.value ? 'bg-primary-500 text-white shadow-sm' : 'text-gray-500 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-dark-card']"
                  >
                    {{ opt.label }}
                  </button>
                </div>
              </div>

              <!-- Date Filter -->
              <div class="flex items-center gap-3">
                <span class="text-[11px] font-semibold text-gray-400 dark:text-dark-muted uppercase tracking-wider">Período</span>
                <div class="flex items-center gap-2">
                  <input v-model="filterDateFrom" type="date" class="bg-white dark:bg-dark-surface border border-gray-100 dark:border-dark-border rounded-lg px-2.5 py-1.5 text-xs text-gray-700 dark:text-gray-300 focus:outline-none focus:ring-1 focus:ring-primary-400" />
                  <span class="text-[10px] text-gray-400">até</span>
                  <input v-model="filterDateTo" type="date" class="bg-white dark:bg-dark-surface border border-gray-100 dark:border-dark-border rounded-lg px-2.5 py-1.5 text-xs text-gray-700 dark:text-gray-300 focus:outline-none focus:ring-1 focus:ring-primary-400" />
                </div>
              </div>

              <!-- Clear -->
              <button v-if="hasActiveFilters" @click="clearFilters" class="text-xs text-red-500 hover:text-red-600 font-medium">Limpar</button>
            </div>
          </div>
        </Transition>

        <!-- Search Bar -->
        <div class="px-6 py-4 bg-gray-50 dark:bg-dark-bg border-b border-gray-200 dark:border-dark-border">
          <div class="relative max-w-2xl">
            <Search class="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400 dark:text-gray-500" />
            <input
              v-model="searchQuery"
              type="text"
              placeholder="Buscar interessado por nome ou telefone..."
              class="w-full bg-white dark:bg-dark-surface border border-gray-300 dark:border-dark-border text-gray-900 dark:text-white placeholder-gray-400 dark:placeholder-gray-500 rounded-xl pl-12 pr-4 py-3 text-sm flex-1 focus:outline-none focus:ring-1 focus:ring-primary-500 shadow-sm transition-all"
            />
          </div>
        </div>

        <!-- Table Header -->
        <div class="px-6 py-3 bg-gray-50 dark:bg-dark-bg border-b border-gray-200 dark:border-dark-border grid grid-cols-12 gap-4 text-xs font-bold text-gray-500 dark:text-dark-muted uppercase tracking-wider">
          <div class="col-span-8">Nome</div>
          <div class="col-span-4 text-right">Avaliação</div>
        </div>

        <!-- Contact List -->
        <div class="divide-y divide-gray-200 dark:divide-dark-border">
          <!-- Loading State -->
          <div v-if="loading" class="p-12 flex items-center justify-center">
            <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-500"></div>
          </div>

          <!-- Empty State -->
          <div v-else-if="loadError" class="p-8 text-center" role="alert">
            {{ loadError }} <button type="button" class="underline" @click="fetchContacts()">Tentar novamente</button>
          </div>
          <div v-else-if="filteredTotal === 0" class="p-12 text-center">
            <p class="text-gray-500 dark:text-dark-muted">Nenhum interessado encontrado</p>
          </div>

          <!-- Contact Rows -->
          <div
            v-else
            v-for="contact in contacts"
            :key="contact.id"
            @click="openContactDetails(contact)"
            class="px-6 py-4 bg-white dark:bg-dark-surface hover:bg-gray-50 dark:hover:bg-white/5 cursor-pointer transition-all group grid grid-cols-12 gap-4 items-center"
          >
            <!-- Left: Avatar + Name + Phone -->
            <div class="col-span-8 flex items-center gap-4">
              <!-- Avatar -->
              <div v-if="(contact as any).media_url" class="w-10 h-10 rounded-xl flex-shrink-0 overflow-hidden border border-gray-200 dark:border-dark-border shadow-sm">
                <img :src="(contact as any).media_url" :alt="contact.name || 'Avatar'" class="w-full h-full object-cover" />
              </div>
              <div v-else class="w-10 h-10 rounded-xl bg-primary-100 dark:bg-primary-900/40 text-primary-600 dark:text-primary-500 flex items-center justify-center font-bold text-lg flex-shrink-0 shadow-sm">
                {{ (contact.name || 'I').charAt(0).toUpperCase() }}
              </div>

              <!-- Info -->
              <div class="min-w-0 flex-1">
                <h3 class="font-bold text-gray-900 dark:text-white text-base truncate group-hover:text-primary-500 transition-colors">
                  {{ contact.name || 'Desconhecido' }}
                </h3>
                <div class="flex items-center gap-2 text-sm text-gray-500 dark:text-dark-muted mt-0.5">
                  <Phone class="w-3 h-3" />
                  <span>{{ contact.phone || '' }}</span>
                </div>
              </div>
            </div>

            <div class="col-span-4 flex items-center justify-end gap-2">
              <span
                :class="['inline-flex items-center px-3 py-1 rounded-lg text-xs font-bold border shadow-sm', getStageBadgeClass(contact.stage)]"
              >
                {{ getStageLabel(contact.stage, contact.stage_id) }}
              </span>

              <!-- Travado Badge -->
              <span
                v-if="contact.agent_active === false"
                class="inline-flex items-center px-3 py-1 rounded-lg text-xs font-bold bg-red-50 dark:bg-red-500/10 text-red-600 dark:text-red-500 border border-red-200 dark:border-red-500/20"
              >
                 Travado
              </span>
            </div>
          </div>
        </div>

        <CrmPagination :page="currentPage" :page-size="itemsPerPage" :total="filteredTotal" :loading="loading" label="contatos" @change="fetchContacts" />
      </div>
    </main>
  </div>

  <!-- Lead Details Modal -->
  <LeadDetailsModal
    :model-value="showModal"
    @update:model-value="showModal = $event"
    :lead="selectedContact"
    :stages="stages"
    @update-status="handleStatusUpdate"
    @save-notes="handleNotesUpdate"
  />
</template>

<style scoped>
.slide-enter-active, .slide-leave-active {
  transition: all 0.2s ease;
}
.slide-enter-from, .slide-leave-to {
  opacity: 0;
  max-height: 0;
  overflow: hidden;
}
.slide-enter-to, .slide-leave-from {
  max-height: 200px;
}
</style>
