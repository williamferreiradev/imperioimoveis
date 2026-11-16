<script setup lang="ts">
import { ref, onMounted, onUnmounted, computed, watch } from 'vue'
import { MessageSquare, KanbanSquare, Table as TableIcon, Download } from 'lucide-vue-next'
import KanbanBoard from '@/components/crm/KanbanBoard.vue'
import LeadTable from '@/components/crm/LeadTable.vue'
import LeadDetailsModal from '@/components/leads/LeadDetailsModal.vue'
import type { Cliente } from '@/types/crm'
import { isLeadId, leadPageColumns } from '@/utils/crmQueries'
import { useSupabaseClient } from '#imports'

const { mainMargin } = useSidebarState()
const supabase = useSupabaseClient<any>()

// State
const currentView = ref<'kanban' | 'table'>('kanban')
const leads = ref<any[]>([])
const stages = ref<any[]>([])
const loading = ref(true)
const error = ref<any>(null)
const total = ref(0)
const tablePage = ref(1)
const tableSize = 25
const columnSize = 20
interface PipelineColumn {
  leads: any[]
  total: number
  loading: boolean
  error: string
}
const columns = ref<Record<string, PipelineColumn>>({})
const exporting = ref(false)
let tableRequest = 0
let detailRequest = 0
let realtimeChannel: ReturnType<typeof supabase.channel> | undefined
let refreshTimer: ReturnType<typeof setTimeout> | undefined

const showModal = ref(false)
const selectedLead = ref<Cliente | null>(null)

// Export Logic
const downloadCSV = async () => {
  if (exporting.value) return
  exporting.value = true
  try {
  const columns = [
    'id', 'name', 'phone', 'stage', 'agent_active', 'created_at', 'source', 'expected_value', 'about', 'ativo', 'stage_id', 'ultima_mensagem_at', 'corretor_id', 'tipo_imovel', 'localizacao', 'situacao_nome', 'profissao', 'tempo_trabalho', 'renda_mensal', 'tipo_renda', 'doc_cpf', 'doc_rg', 'doc_certidao', 'doc_residencia', 'doc_carteira_trabalho', 'doc_contracheque', 'doc_movimentacao', 'url_cpf', 'url_rg', 'url_certidao', 'url_residencia', 'url_contracheque', 'dataHandoff', 'estado_civil', 'endereco_atual', 'url_carteira_trabalho', 'url_movimentacao', 'last_followup_status', 'last_mensagem_followup_at'
  ];

  const escapeCSV = (value: any) => {
    if (value === null || value === undefined) return '""';
    const stringValue = String(value);
    return '"' + stringValue.replace(/"/g, '""') + '"';
  };

  const header = columns.join(',') + "\r\n";
  const rows = []
  let after: string | undefined
  while (true) {
    let query = supabase.from('leads').select(columns.join(',')).order('id').limit(200)
    if (after) query = query.gt('id', after)
    const { data, error: exportError } = await query
    if (exportError) throw exportError
    const batch = (data || []) as unknown as Record<string, unknown>[]
    rows.push(...batch.map(lead => columns.map(col => escapeCSV(lead[col])).join(',')))
    if (batch.length < 200) break
    after = String(batch.at(-1)?.id)
  }
  const csvContent = "\uFEFF" + header + rows.join("\r\n");

  const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.setAttribute("href", url);
  link.setAttribute("download", `leads_export_${new Date().toISOString().split('T')[0]}.csv`);
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(url)
  } catch (err) {
    error.value = 'Não foi possível exportar o CSV. Tente novamente.'
    console.error(err)
  } finally {
    exporting.value = false
  }
}

async function loadTable(page = tablePage.value) {
  const request = ++tableRequest
  loading.value = true
  error.value = null
  const start = (page - 1) * tableSize
  try {
    const result = await supabase.from('leads').select(leadPageColumns, { count: 'exact' })
      .order('created_at', { ascending: false, nullsFirst: false }).order('id', { ascending: false })
      .range(start, start + tableSize - 1)
    if (request !== tableRequest || currentView.value !== 'table') return
    if (result.error) throw result.error
    total.value = result.count ?? 0
    const last = Math.max(1, Math.ceil(total.value / tableSize))
    if (page > last) return await loadTable(last)
    tablePage.value = page
    leads.value = result.data ?? []
  } catch (err) {
    if (request === tableRequest) error.value = 'Não foi possível carregar os leads.'
    console.error(err)
  } finally {
    if (request === tableRequest && currentView.value === 'table') loading.value = false
  }
}

async function loadColumn(key: string, reset = false) {
  const previous = columns.value[key]
  if (!reset && (previous?.loading || (previous && previous.leads.length >= previous.total))) return
  columns.value[key] = { leads: previous?.leads ?? [], total: previous?.total ?? 0, loading: true, error: '' }
  const column = columns.value[key]!
  const cursor = !reset ? previous?.leads.at(-1) : undefined
  try {
    let query = supabase.from('crm_pipeline_leads').select(
      `${leadPageColumns},sort_at`, cursor ? undefined : { count: 'exact' }
    ).eq('stage_key', key).order('sort_at', { ascending: false }).order('id', { ascending: false }).limit(columnSize)
    if (cursor) query = query.or(`sort_at.lt.${cursor.sort_at},and(sort_at.eq.${cursor.sort_at},id.lt.${cursor.id})`)
    const result = await query
    if (columns.value[key] !== column) return
    if (result.error) throw result.error
    if (result.count !== null) column.total = result.count
    const existing = new Set(cursor ? column.leads.map(lead => lead.id) : [])
    column.leads = [...(cursor ? column.leads : []), ...(result.data ?? []).filter(lead => !existing.has(lead.id))]
    if (cursor && !result.data?.length) {
      const count = await supabase.from('crm_pipeline_leads').select('id', { count: 'exact', head: true }).eq('stage_key', key)
      if (!count.error) column.total = count.count ?? column.total
      if (column.total > column.leads.length) column.error = 'A coluna mudou. Atualize para continuar.'
    }
  } catch (err) {
    column.error = 'Não foi possível carregar esta coluna.'
    console.error(err)
  } finally {
    column.loading = false
  }
}

const boardTotal = computed(() => Object.values(columns.value).reduce((sum, col) => sum + col.total, 0))

async function refreshView() {
  if (currentView.value === 'table') return loadTable()
  loading.value = false
  error.value = null
  await Promise.all(stages.value.map(stage => loadColumn(stage.estagio, true)))
}

async function handleStatusUpdate(id: string, stage: any) {
  const stageObj = typeof stage === 'string' ? stages.value.find(s => s.estagio === stage) : stage
  if (!stageObj) return
  const oldKey = Object.keys(columns.value).find(key => columns.value[key]?.leads.some(lead => lead.id === id))
  const { error: updateError } = await supabase.from('leads').update({ stage_id: stageObj.id, stage: stageObj.estagio }).eq('id', id)
  if (updateError) error.value = 'Não foi possível mover o lead.'
  else if (selectedLead.value?.id === id) Object.assign(selectedLead.value, { stage: stageObj.estagio, stage_id: stageObj.id })
  if (currentView.value === 'table') await loadTable()
  else await Promise.all([...new Set([oldKey, stageObj.estagio].filter(Boolean) as string[])].map(key => loadColumn(key, true)))
  if (updateError) error.value = 'Não foi possível mover o lead.'
}

async function openLeadDetails(lead: Pick<Cliente, 'id'>) {
  const request = ++detailRequest
  const result = await supabase.from('leads').select('*').eq('id', lead.id).maybeSingle()
  if (request !== detailRequest) return
  if (result.error || !result.data) {
    error.value = 'Não foi possível carregar os detalhes do lead.'
    return
  }
  selectedLead.value = result.data as Cliente
  showModal.value = true
}

const openChat = (leadId: string) => navigateTo(`/chats?clientId=${leadId}`)

async function handleNotesUpdate(id: string, notes: string) {
  const { error: updateError } = await supabase.from('leads').update({ about: notes }).eq('id', id)
  if (updateError) error.value = 'Não foi possível salvar a anotação.'
  else if (selectedLead.value?.id === id) selectedLead.value.about = notes
}

watch(currentView, () => {
  ++tableRequest
  if (stages.value.length) refreshView()
})

onMounted(async () => {
  const result = await supabase.from('stage').select('id,estagio,estagio_name,descricao').order('id')
  if (result.error) {
    error.value = 'Não foi possível carregar as etapas.'
    loading.value = false
    return
  }
  stages.value = result.data ?? []
  await refreshView()
  const clientId = useRoute().query.clientId
  if (typeof clientId === 'string' && isLeadId(clientId)) void openLeadDetails({ id: clientId })
  realtimeChannel = supabase.channel('crm_leads_changes')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'leads' }, () => {
      clearTimeout(refreshTimer)
      refreshTimer = setTimeout(() => { void refreshView() }, 400)
    }).subscribe()
})

onUnmounted(() => {
  ++tableRequest
  ++detailRequest
  clearTimeout(refreshTimer)
  if (realtimeChannel) supabase.removeChannel(realtimeChannel)
})
</script>

<template>
  <div class="min-h-screen bg-gray-50 dark:bg-dark-bg text-gray-900 dark:text-white font-sans transition-colors duration-300">
    <Sidebar />

    <!-- Error Debug Output -->
    <pre v-if="error" class="fixed top-4 right-4 bg-red-50 text-red-600 dark:bg-red-900 dark:text-white p-4 rounded-xl z-50 max-w-md overflow-auto shadow-card">{{ error }}</pre>

    <main :class="[mainMargin, 'min-w-0 p-3 sm:p-5 xl:p-8 h-dvh overflow-hidden flex flex-col transition-all duration-300']">
      <!-- Header -->
      <header class="flex flex-wrap justify-between items-start gap-3 mb-4 sm:mb-6">
        <div class="flex items-center gap-4">
          <div class="p-2.5 bg-primary-50 dark:bg-primary-500/10 rounded-xl text-primary-500">
             <MessageSquare class="w-5 h-5" />
          </div>
          <div>
            <h1 class="text-xl font-bold tracking-tight flex flex-wrap items-center gap-2">
              Pipeline de Negociações
              <span v-if="!loading" class="text-xs font-medium text-gray-500 dark:text-dark-muted px-2.5 py-1 rounded-lg bg-gray-100 dark:bg-dark-card border border-gray-200 dark:border-dark-border">
                {{ (currentView === 'kanban' ? boardTotal : total).toLocaleString('pt-BR') }} interessados
              </span>
            </h1>
            <p class="text-gray-400 dark:text-dark-muted text-sm mt-0.5">Gerencie os interessados nos imóveis.</p>
          </div>
        </div>
        
        <div class="flex items-center gap-3">
          <button 
            @click="downloadCSV" :disabled="exporting" aria-label="Exportar CSV"
            class="flex items-center gap-2 px-4 py-2 rounded-xl bg-white dark:bg-dark-surface border border-gray-200 dark:border-dark-border text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-white/5 text-sm font-medium transition-colors shadow-sm"
          >
            <Download class="w-4 h-4 text-primary-500" /> <span class="hidden sm:inline">{{ exporting ? 'Exportando…' : 'Exportar CSV' }}</span>
          </button>

          <!-- View Toggle -->
          <div class="bg-white dark:bg-dark-surface p-1 rounded-xl border border-gray-100 dark:border-dark-border shadow-card flex gap-1 transition-colors duration-300">
            <button 
              @click="currentView = 'kanban'"
              :class="[
                'flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition-all',
                currentView === 'kanban' ? 'bg-primary-500 text-white shadow-luxury' : 'text-gray-500 dark:text-dark-muted hover:bg-gray-50 dark:hover:bg-white/5 hover:text-gray-900 dark:hover:text-white'
              ]"
            >
              <KanbanSquare class="w-4 h-4" /> Kanban
            </button>
            
            <button 
              @click="currentView = 'table'"
              :class="[
                 'flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition-all',
                 currentView === 'table' ? 'bg-primary-500 text-white shadow-luxury' : 'text-gray-500 dark:text-dark-muted hover:bg-gray-50 dark:hover:bg-white/5 hover:text-gray-900 dark:hover:text-white'
              ]"
            >
              <TableIcon class="w-4 h-4" /> Tabela
            </button>
          </div>
        </div>
      </header>

      <!-- Content Area -->
      <div class="flex-1 overflow-hidden relative">
        <div v-if="loading" class="absolute inset-0 flex items-center justify-center z-10 bg-white/80 dark:bg-dark-bg/80 backdrop-blur-sm transition-colors duration-300">
           <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-500"></div>
        </div>

        <Transition name="fade" mode="out-in">
          <KanbanBoard 
            v-if="currentView === 'kanban'" 
            :columns="columns"
            :stages="stages"
            @load-more="loadColumn"
            @update-status="handleStatusUpdate"
            @view-details="openLeadDetails"
          />
          <LeadTable 
            v-else 
            :leads="leads"
            :page="tablePage" :page-size="tableSize" :total="total" :loading="loading"
            @change-page="loadTable"
            @view-details="openLeadDetails"
            @open-chat="openChat"
          />
        </Transition>
      </div>
    </main>
  </div>

  <LeadDetailsModal
    :model-value="showModal"
    @update:model-value="showModal = $event"
    :lead="selectedLead"
    :stages="stages"
    @update-status="handleStatusUpdate"
    @save-notes="handleNotesUpdate"
  />
</template>

<style scoped>
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
