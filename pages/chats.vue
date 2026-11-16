<script setup lang="ts">
import { ref, onMounted, onUnmounted, nextTick, watch } from 'vue'
import { useSupabaseClient } from '#imports'
import { isLeadId, qualifiedStages, searchLeadColumns } from '@/utils/crmQueries'
import { MessageSquare, Phone, Search, FileText, Menu, X, BotOff, Bot, PhoneForwarded, ArrowLeft } from 'lucide-vue-next'

const route = useRoute()
const { desktopMargin, isCollapsed } = useSidebarState()
const threadMargin = computed(() => isCollapsed.value ? 'lg:ml-20 xl:ml-0' : 'lg:ml-72 xl:ml-0')
const supabase = useSupabaseClient<any>()

// State
const chats = ref<any[]>([])
const selectedChat = ref<any>(null)
const mobileThread = ref(false)
type ChatMessage = {
  id: number
  sender: 'contact' | 'assistant' | 'system'
  body: string | null
}
const messages = ref<ChatMessage[]>([])
const visibleMessages = computed(() => messages.value.filter(message => message.body))
const loading = ref(true)
const messagesLoading = ref(false)
const searchQuery = ref('')
const isSidebarOpen = ref(false)
const messagesContainer = ref<HTMLElement | null>(null)

const stages = ref<any[]>([
  { id: 1, estagio: 'novo', estagio_name: 'Novo Contato' },
  { id: 2, estagio: 'em_atendimento', estagio_name: 'Em Atendimento' },
  { id: 3, estagio: 'agendamento', estagio_name: 'Agendamento' },
  { id: 4, estagio: 'visita', estagio_name: 'Visita' },
  { id: 5, estagio: 'negociacao', estagio_name: 'Em Negociação' },
  { id: 6, estagio: 'fechado', estagio_name: 'Venda Fechada' },
  { id: 7, estagio: 'perdido', estagio_name: 'Perdido' }
])


// Summary state
const summaryText = ref('')
const summaryLoading = ref(false)
const showSummary = ref(false)

// Handoff state
const handoffNumber = ref('+55 11 99999-0000')
const editingHandoff = ref(false)
const globalHandoffNumber = ref('+55 11 98888-0000')
const editingGlobalHandoff = ref(false)

const formatStageName = (stage: string) => {
  if (!stage) return 'novo'
  const map: Record<string, string> = {
    novo: 'novo',
    em_atendimento: 'atendimento',
    agendamento: 'agendamento',
    visita: 'visita',
    negociacao: 'negociação',
    fechado: 'fechado',
    perdido: 'perdido'
  }
  return map[stage] || stage
}

const directorySize = 25
const messageSize = 40
const directoryOffset = ref(0)
const hasMoreChats = ref(false)
const directoryError = ref('')
const messagesError = ref('')
const hasOlder = ref(false)
const loadingOlder = ref(false)
let directoryRequest = 0
let messageRequest = 0
let searchTimer: ReturnType<typeof setTimeout> | undefined
let pollTimer: ReturnType<typeof setInterval> | undefined
let polling = false

function mapChat(row: any) {
  return {
    id: row.id,
    name: row.name || 'Sem nome',
    phone: row.phone || 'Sem telefone',
    lastMessage: row.preview || 'Conversa iniciada…',
    timestamp: row.created_at ? new Date(row.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '',
    avatar: (row.name || 'U').charAt(0).toUpperCase(),
    Ativado: Boolean(row.agent_active),
    is_qualified: qualifiedStages.includes(row.stage),
    estagiokanbam: row.stage || 'novo',
  }
}

async function fetchChats(reset = false) {
  if (!reset && (loading.value || !hasMoreChats.value)) return
  const request = ++directoryRequest
  loading.value = true
  directoryError.value = ''
  const offset = reset ? 0 : directoryOffset.value
  let query = supabase.from('crm_chat_directory')
    .select('id,name,phone,stage,agent_active,created_at,preview')
  if (searchQuery.value.trim()) query = query.or(searchLeadColumns(searchQuery.value))
  const result = await query.order('created_at', { ascending: false, nullsFirst: false }).order('id', { ascending: false })
    .range(offset, offset + directorySize)
  if (request !== directoryRequest) return
  loading.value = false
  if (result.error) {
    directoryError.value = 'Não foi possível carregar a lista de conversas.'
    return
  }
  const batch = (result.data ?? []).slice(0, directorySize).map(mapChat)
  const prior = reset ? [] : chats.value
  const seen = new Set(prior.map(chat => chat.id))
  chats.value = [...prior, ...batch.filter(chat => !seen.has(chat.id))]
  directoryOffset.value = offset + batch.length
  hasMoreChats.value = (result.data?.length ?? 0) > directorySize
}

async function fetchMessages(older = false) {
  const chatId = selectedChat.value?.id
  if (!chatId || (older && (loadingOlder.value || !hasOlder.value))) return
  const request = messageRequest
  const oldest = older ? messages.value[0]?.id : null
  if (older) loadingOlder.value = true
  else messagesLoading.value = true
  messagesError.value = ''
  let query = supabase.from('crm_chat_messages').select('id,sender,body').eq('session_id', chatId)
    .order('id', { ascending: false }).limit(messageSize + 1)
  if (oldest != null) query = query.lt('id', oldest)
  const result = await query
  if (request !== messageRequest) return
  messagesLoading.value = false
  loadingOlder.value = false
  if (result.error) {
    messagesError.value = 'Não foi possível carregar as mensagens.'
    return
  }
  const container = messagesContainer.value
  const previousHeight = container?.scrollHeight ?? 0
  const previousTop = container?.scrollTop ?? 0
  const batch = (result.data ?? []).slice(0, messageSize).reverse() as ChatMessage[]
  const unique = new Map([...batch, ...messages.value].map(message => [message.id, message]))
  messages.value = [...unique.values()].sort((a, b) => a.id - b.id)
  hasOlder.value = (result.data?.length ?? 0) > messageSize
  await nextTick()
  if (request !== messageRequest || !container) return
  if (older) container.scrollTop = previousTop + container.scrollHeight - previousHeight
  else container.scrollTop = container.scrollHeight
}

async function appendMessages(rows: ChatMessage[], request: number) {
  if (request !== messageRequest || !rows.length) return
  const container = messagesContainer.value
  const atBottom = !container || container.scrollHeight - container.clientHeight - container.scrollTop < 120
  const seen = new Set(messages.value.map(message => message.id))
  const batch = rows.filter(row => !seen.has(row.id))
  if (!batch.length) return
  messages.value = [...messages.value, ...batch].sort((a, b) => a.id - b.id)
  const preview = batch.filter(message => message.body && message.sender !== 'system').at(-1)
  if (preview?.body) {
    const chat = [selectedChat.value, ...chats.value].filter(item => item?.id === selectedChat.value?.id)
    for (const item of chat) item.lastMessage = Array.from(preview.body).slice(0, 180).join('')
  }
  await nextTick()
  if (request === messageRequest && atBottom && container) container.scrollTop = container.scrollHeight
}

async function pollActiveConversation() {
  const chatId = selectedChat.value?.id
  if (!chatId || polling || messagesLoading.value || document.hidden) return
  if (!mobileThread.value && !window.matchMedia('(min-width: 1280px)').matches) return
  polling = true
  const request = messageRequest
  try {
    const newestId = messages.value.at(-1)?.id ?? 0
    const { data, error } = await supabase.from('crm_chat_messages').select('id,sender,body')
      .eq('session_id', chatId).gt('id', newestId).order('id').limit(messageSize)
    if (!error) await appendMessages(data ?? [], request)
  } finally {
    polling = false
  }
}

function selectChat(chat: any, reveal = true) {
  if (reveal) mobileThread.value = true
  if (selectedChat.value?.id === chat.id) {
    if (reveal) void pollActiveConversation()
    return
  }
  ++messageRequest
  selectedChat.value = chat
  messages.value = []
  isSidebarOpen.value = false
  showSummary.value = false
  summaryText.value = ''
  messagesError.value = ''
  hasOlder.value = false
  loadingOlder.value = false
  void fetchMessages()
}

async function selectFromRoute(value: unknown) {
  if (typeof value !== 'string' || !value) return
  const existing = chats.value.find(chat => chat.id === value || chat.phone === value)
  if (existing) return selectChat(existing)
  let query = supabase.from('crm_chat_directory').select('id,name,phone,stage,agent_active,created_at,preview')
  query = isLeadId(value) ? query.eq('id', value) : query.eq('phone', value)
  const { data } = await query.limit(1).maybeSingle()
  if (route.query.clientId === value && data) selectChat(mapChat(data))
}

watch(searchQuery, () => {
  clearTimeout(searchTimer)
  ++directoryRequest
  loading.value = true
  chats.value = []
  searchTimer = setTimeout(() => { void fetchChats(true) }, 250)
})
watch(() => route.query.clientId, value => { void selectFromRoute(value) })

// Generate Summary
const generateSummary = async () => {
  if (!selectedChat.value) return
  summaryLoading.value = true
  showSummary.value = true

  // Simulate AI processing
  await new Promise(resolve => setTimeout(resolve, 1500))

  const { mockSummaries } = useMockData()
  const summary = (mockSummaries as any)[selectedChat.value.id]
  
  if (summary) {
    summaryText.value = summary
  } else {
    let statusText = 'Em análise'
    let temperaturaText = '⚪ Frio — aguardando mais interação'
    let proxPassoText = 'Continuar qualificação via IA'

    switch (selectedChat.value.estagiokanbam) {
      case 'novo':
        statusText = 'Aguardando contato inicial'
        temperaturaText = '⚪ Frio — lead recém-chegado'
        proxPassoText = 'Iniciar qualificação'
        break
      case 'em_atendimento':
        statusText = 'Em conversação'
        temperaturaText = '🟡 Morno — demonstrando interesse inicial'
        proxPassoText = 'Qualificar e direcionar para agendamento/visita'
        break
      case 'agendamento':
        statusText = 'Tentando agendar'
        temperaturaText = '🟡 Morno — em processo de agendamento'
        proxPassoText = 'Confirmar data e horário'
        break
      case 'visita':
        statusText = 'Esperando a visita'
        temperaturaText = '🔴 Quente — visita agendada'
        proxPassoText = 'Análise de documentos pessoalmente'
        break
      case 'negociacao':
        statusText = 'Proposta em análise'
        temperaturaText = '🔥 Muito Quente — em negociação financeira'
        proxPassoText = 'Fechar valores e encaminhar contrato'
        break
      case 'fechado':
        statusText = 'Negócio Fechado'
        temperaturaText = '🏆 Convertido'
        proxPassoText = 'Pós-venda e assinatura final'
        break
      case 'perdido':
        statusText = 'Contato encerrado'
        temperaturaText = '🧊 Congelado — sem interesse atual'
        proxPassoText = 'Adicionar à lista de reativação futura'
        break
    }

    summaryText.value = `📋 **Resumo da Conversa — ${selectedChat.value.name}**\n\n• Interesse: ${formatStageName(selectedChat.value.estagiokanbam)}\n• Status: ${statusText}\n• Temperatura: ${temperaturaText}\n• Próximo passo: ${proxPassoText}`
  }

  summaryLoading.value = false
}



// Actions
const toggleAI = async () => {
  if (!selectedChat.value) return
  const newVal = !selectedChat.value.Ativado
  selectedChat.value.Ativado = newVal
  await supabase.from('leads').update({ agent_active: newVal }).eq('id', selectedChat.value.id)
}

const updateStatus = async () => {
  if (!selectedChat.value) return
  const isQual = ['qualificado', 'convertido', 'agendado', 'negociacao', 'visita', 'fechado'].includes(selectedChat.value.estagiokanbam)
  selectedChat.value.is_qualified = isQual
  
  const stageObj = stages.value.find(s => s.estagio === selectedChat.value.estagiokanbam)
  const updateData: any = {
    stage: selectedChat.value.estagiokanbam
  }
  if (stageObj) {
    updateData.stage_id = stageObj.id
  }
  
  const { error: updateError } = await supabase.from('leads').update(updateData).eq('id', selectedChat.value.id)
  if (updateError) {
    console.error('Error updating status in DB:', updateError)
  }
}

onMounted(async () => {
  const [, stageResult] = await Promise.all([
    fetchChats(true),
    supabase.from('stage').select('id,estagio,estagio_name').order('id'),
  ])
  if (!stageResult.error) stages.value = stageResult.data ?? []
  if (route.query.clientId) await selectFromRoute(route.query.clientId)
  else if (chats.value[0]) selectChat(chats.value[0], false)
  pollTimer = setInterval(() => { void pollActiveConversation() }, 20000)
  document.addEventListener('visibilitychange', pollActiveConversation)
})
onUnmounted(() => {
  ++directoryRequest
  ++messageRequest
  clearTimeout(searchTimer)
  clearInterval(pollTimer)
  document.removeEventListener('visibilitychange', pollActiveConversation)
})
</script>

<template>
  <div class="h-dvh w-full pt-14 lg:pt-0 bg-gray-50 dark:bg-dark-bg text-gray-900 dark:text-white font-sans flex overflow-hidden transition-colors duration-300">
    <Sidebar />

    <!-- Chat Sidebar (Left) -->
    <aside
      :class="[desktopMargin, mobileThread ? 'hidden xl:flex' : 'flex']"
      class="w-full xl:w-80 xl:shrink-0 flex-col border-r border-gray-100 dark:border-dark-border bg-white dark:bg-dark-surface transition-colors duration-300"
    >
      <!-- Header -->
      <div class="p-5 border-b border-gray-100 dark:border-dark-border">
        <div class="flex items-center justify-between mb-3">
          <h2 class="text-lg font-bold text-gray-900 dark:text-white">Conversas</h2>

        </div>
        

        <div class="relative">
          <Search class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <input
            v-model="searchQuery"
            type="text"
            placeholder="Buscar conversas..."
            class="w-full bg-gray-50 dark:bg-dark-card border border-gray-100 dark:border-dark-border rounded-xl py-2.5 pl-10 pr-4 text-sm focus:outline-none focus:ring-2 focus:ring-primary-200 dark:focus:ring-primary-500/30 transition-all"
          />
        </div>
      </div>

      <!-- Chat List -->
      <div class="flex-1 overflow-y-auto">
        <div v-if="loading" class="p-8 text-center text-gray-400 dark:text-dark-muted text-sm">
          Carregando...
        </div>
        <div v-else-if="!directoryError && chats.length === 0" class="p-8 text-center text-gray-400 dark:text-dark-muted text-sm">
          Nenhuma conversa encontrada.
        </div>
        <button
          v-for="chat in chats"
          :key="chat.id"
          @click="selectChat(chat)"
          :class="[
            'w-full p-4 flex gap-3 border-b border-gray-50 dark:border-dark-border transition-all hover:bg-gray-50 dark:hover:bg-white/5',
            selectedChat?.id === chat.id ? 'bg-primary-50/50 dark:bg-primary-500/5 border-l-2 border-l-primary-500' : ''
          ]"
        >
          <div class="w-10 h-10 rounded-xl bg-primary-50 dark:bg-primary-500/10 text-primary-600 dark:text-primary-400 flex items-center justify-center font-bold text-sm flex-shrink-0">
            {{ chat.avatar }}
          </div>
          <div class="flex-1 min-w-0 text-left">
            <div class="flex items-center justify-between mb-1">
              <div class="flex items-center gap-1.5">
                <h3 class="font-semibold text-gray-900 dark:text-white truncate text-sm">{{ chat.name }}</h3>
                <span class="text-[9px] font-medium bg-emerald-50 dark:bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 px-1.5 py-0.5 rounded-md border border-emerald-100 dark:border-emerald-500/20 flex-shrink-0 whitespace-nowrap">{{ formatStageName(chat.estagiokanbam) }}</span>
              </div>
              <span class="text-[10px] text-gray-400 dark:text-dark-muted flex-shrink-0">{{ chat.timestamp }}</span>
            </div>
            <p class="truncate text-xs text-gray-500 dark:text-dark-muted">{{ chat.lastMessage }}</p>
          </div>
        </button>
        <div v-if="directoryError || hasMoreChats" class="p-3 text-center">
          <p v-if="directoryError" role="alert" class="mb-2 text-xs text-red-600">{{ directoryError }}</p>
          <button class="min-h-9 rounded-md border px-3 text-sm" type="button" :disabled="loading"
            @click="fetchChats(directoryOffset === 0)">{{ directoryError ? 'Tentar novamente' : 'Carregar mais conversas' }}</button>
        </div>
      </div>
    </aside>

    <!-- Chat Content (Middle) -->
    <section :class="mobileThread ? ['flex', threadMargin] : 'hidden xl:flex'"
      class="flex-1 flex-col bg-gray-50 dark:bg-dark-bg relative min-w-0 transition-colors duration-300">
      <div v-if="selectedChat" class="flex-1 flex flex-col overflow-hidden relative">
        <!-- Header -->
        <header class="flex-wrap gap-2 px-3 sm:px-6 py-4 border-b border-gray-100 dark:border-dark-border bg-white dark:bg-dark-surface flex items-center justify-between z-20">
          <div class="flex min-w-0 items-center gap-2">
            <button type="button" class="shrink-0 p-1 xl:hidden" aria-label="Voltar para conversas" @click="mobileThread = false">
              <ArrowLeft class="h-4 w-4" />
            </button>
            <div class="w-10 h-10 rounded-xl bg-primary-50 dark:bg-primary-500/10 text-primary-600 dark:text-primary-400 flex items-center justify-center font-bold">
              {{ selectedChat.avatar }}
            </div>
            <div>
              <h2 class="font-semibold text-gray-900 dark:text-white text-sm">{{ selectedChat.name }}</h2>
              <p class="text-xs text-gray-400 dark:text-dark-muted flex items-center gap-1">
                <Phone class="w-3 h-3" />
                {{ selectedChat.phone }}
              </p>
            </div>
          </div>
          
          <div class="flex items-center gap-2">
            <NuxtLink 
              :to="`/crm?clientId=${selectedChat.id}`"
              class="flex items-center gap-2 px-3 py-1.5 bg-gray-50 dark:bg-dark-card text-gray-600 dark:text-gray-300 rounded-lg text-xs font-medium hover:bg-gray-100 dark:hover:bg-dark-border transition-all border border-gray-100 dark:border-dark-border"
            >
              <FileText class="w-3 h-3" /> Ver no CRM
            </NuxtLink>

            <button 
              @click="isSidebarOpen = !isSidebarOpen"
              class="p-2 text-gray-400 hover:text-gray-600 dark:hover:text-white transition-colors hover:bg-gray-50 dark:hover:bg-dark-card rounded-lg"
              title="Ações"
            >
              <Menu class="w-5 h-5" v-if="!isSidebarOpen" />
              <X class="w-5 h-5" v-else />
            </button>
          </div>
        </header>

        <!-- Messages Area -->
        <div ref="messagesContainer" class="min-h-0 flex-1 overflow-y-auto overflow-x-hidden p-3 md:p-6 flex flex-col gap-4 relative custom-scrollbar pb-12">
          <div v-if="messagesLoading" class="flex-1 flex items-center justify-center">
             <div class="animate-spin rounded-full h-6 w-6 border-b-2 border-primary-500"></div>
          </div>
          <div v-else-if="!messagesError && !hasOlder && visibleMessages.length === 0" class="flex-1 flex items-center justify-center">
             <p class="text-gray-400 dark:text-dark-muted text-sm">Nenhuma mensagem encontrada nesta sessão.</p>
          </div>
          <div v-if="!messagesLoading && hasOlder" class="shrink-0 text-center">
            <button type="button" :disabled="loadingOlder" class="min-h-9 rounded-md border px-3 text-sm" @click="fetchMessages(true)">
              {{ loadingOlder ? 'Carregando…' : 'Carregar mensagens anteriores' }}
            </button>
          </div>
          <p v-if="messagesError" role="alert" class="text-center text-sm text-red-600">
            {{ messagesError }} <button type="button" class="underline" @click="fetchMessages(!!messages.length)">Tentar novamente</button>
          </p>
          <div
            v-for="message in visibleMessages"
            :key="message.id"
            :data-sender="message.sender"
            :class="['flex shrink-0', message.sender === 'system' ? 'justify-center' : message.sender === 'assistant' ? 'justify-end' : 'justify-start']"
          >
            <div
              v-if="message.sender === 'system'"
              class="flex max-w-full items-start gap-2 rounded-xl border border-gray-200 bg-gray-100 px-3 py-1.5 text-xs text-gray-600 dark:border-dark-border dark:bg-dark-surface dark:text-dark-muted"
            >
              <Bot class="mt-0.5 h-3.5 w-3.5 shrink-0 text-primary-500" aria-hidden="true" />
              <p class="min-w-0 whitespace-pre-wrap break-words">
                <span class="mr-1 font-semibold">Sistema</span> {{ message.body }}
              </p>
            </div>
            <div
              v-else
              :class="[
                'min-w-0 max-w-[min(100%,28rem)] rounded-2xl px-4 py-3 shadow-sm',
                message.sender === 'assistant'
                  ? 'rounded-br-none bg-primary-600 text-white'
                  : 'rounded-bl-none border border-gray-100 bg-white text-gray-800 dark:border-dark-border dark:bg-dark-surface dark:text-gray-200'
              ]"
            >
              <p v-if="message.sender === 'assistant'" class="mb-1 text-xs font-semibold text-white/90">IA</p>
              <p class="whitespace-pre-wrap break-words text-sm leading-relaxed">{{ message.body }}</p>
            </div>
          </div>

          <!-- Summary Result -->
          <Transition name="fade">
            <div v-if="showSummary" class="bg-white dark:bg-dark-surface border border-primary-100 dark:border-primary-500/20 rounded-xl p-5 shadow-card">
              <div class="flex items-center gap-2 mb-3">
                <FileText class="w-4 h-4 text-primary-500" />
                <h4 class="text-sm font-semibold text-gray-900 dark:text-white">Resumo Gerado pela IA</h4>
              </div>
              <div v-if="summaryLoading" class="flex items-center gap-2 text-sm text-gray-400">
                <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-primary-500"></div>
                Analisando conversa...
              </div>
              <p v-else class="text-sm text-gray-700 dark:text-gray-300 leading-relaxed whitespace-pre-wrap">{{ summaryText }}</p>
            </div>
          </Transition>
        </div>

        <!-- Floating Action: Generate Summary -->
        <div class="absolute bottom-20 right-6 z-30">
           <button 
             @click="generateSummary"
             :disabled="summaryLoading"
             class="bg-white dark:bg-dark-surface hover:bg-gray-50 dark:hover:bg-dark-card border border-gray-200 dark:border-dark-border shadow-card-hover text-gray-900 dark:text-white px-5 py-2.5 rounded-xl flex items-center gap-2 text-sm font-medium transition-all hover:-translate-y-0.5 disabled:opacity-50"
           >
             <FileText class="w-4 h-4 text-primary-500" /> 
             {{ summaryLoading ? 'Gerando...' : 'Gerar Resumo' }}
           </button>
        </div>

        <!-- Footer -->
        <footer class="p-4 border-t border-gray-100 dark:border-dark-border bg-white dark:bg-dark-surface z-20">
          <div class="bg-primary-50 dark:bg-primary-500/5 border border-primary-100 dark:border-primary-500/20 text-primary-600 dark:text-primary-400 px-4 py-2.5 rounded-xl text-xs text-center font-medium">
            O envio de mensagens deve ser feito via WhatsApp ou automação externa.
          </div>
        </footer>
      </div>

      <!-- Empty State -->
      <div v-else class="flex-1 flex flex-col items-center justify-center text-gray-400 dark:text-dark-muted p-12">
        <div class="w-16 h-16 bg-gray-100 dark:bg-dark-surface border border-gray-200 dark:border-dark-border rounded-xl flex items-center justify-center mb-5">
          <MessageSquare class="w-8 h-8 opacity-30" />
        </div>
        <h2 class="text-lg font-semibold text-gray-900 dark:text-white mb-1">Selecione uma conversa</h2>
        <p class="text-center max-w-xs text-sm">Escolha um lead à esquerda para visualizar o histórico da conversa.</p>
      </div>
    </section>

    <!-- Side Actions Drawer (Right) -->
    <aside 
      v-if="isSidebarOpen && selectedChat" 
      class="w-72 border-l border-gray-100 dark:border-dark-border bg-white dark:bg-dark-surface flex flex-col flex-shrink-0 transition-colors"
    >
      <div class="p-5 border-b border-gray-100 dark:border-dark-border">
        <h2 class="font-bold text-gray-900 dark:text-white text-base">Ações</h2>
      </div>

      <div class="p-5 flex flex-col gap-6 flex-1 overflow-y-auto">
        <!-- AI Toggle -->
        <div>
          <label class="text-[10px] uppercase tracking-wider text-gray-400 dark:text-dark-muted mb-2 block font-semibold">IA Automática</label>
          <button 
            @click="toggleAI"
            :class="[
              'w-full py-2.5 rounded-xl flex items-center justify-center gap-2 font-medium transition-all border text-sm',
              selectedChat.Ativado 
                ? 'bg-primary-50 dark:bg-primary-500/10 text-primary-600 dark:text-primary-400 hover:bg-primary-100 border-primary-100 dark:border-primary-500/20'
                : 'bg-amber-50 dark:bg-amber-500/10 text-amber-600 dark:text-amber-500 hover:bg-amber-100 border-amber-100 dark:border-amber-500/20' 
            ]"
          >
            <BotOff class="w-4 h-4" v-if="!selectedChat.Ativado" />
            <Bot class="w-4 h-4" v-else />
            {{ selectedChat.Ativado ? 'Ativada' : 'Desativada' }}
          </button>
        </div>

        <!-- Status -->
        <div>
          <label class="text-[10px] uppercase tracking-wider text-gray-400 dark:text-dark-muted mb-2 block font-semibold">Status CRM</label>
          <div class="relative">
            <select 
              v-model="selectedChat.estagiokanbam" 
              @change="updateStatus"
              class="w-full bg-gray-50 dark:bg-dark-card border border-gray-100 dark:border-dark-border rounded-xl p-3 text-gray-900 dark:text-white text-sm font-medium focus:outline-none focus:ring-2 focus:ring-primary-200 dark:focus:ring-primary-500/30 appearance-none"
            >
              <option 
                v-for="s in stages" 
                :key="s.id" 
                :value="s.estagio"
              >
                {{ s.estagio_name || s.descricao || s.estagio }}
              </option>
            </select>
            <div class="pointer-events-none absolute inset-y-0 right-0 flex items-center px-4 text-gray-400">
               <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                 <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
               </svg>
            </div>
          </div>
        </div>

        <!-- Handoff Number -->
        <div>
          <label class="text-[10px] uppercase tracking-wider text-gray-400 dark:text-dark-muted mb-2 block font-semibold">
            <PhoneForwarded class="w-3 h-3 inline mr-1" /> Número de Handoff
          </label>
          <div v-if="editingHandoff" class="flex gap-2">
            <input 
              v-model="handoffNumber" 
              type="text"
              class="flex-1 bg-gray-50 dark:bg-dark-card border border-gray-100 dark:border-dark-border rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-primary-200 dark:focus:ring-primary-500/30"
              placeholder="+55 11 99999-0000"
            />
            <button 
              @click="editingHandoff = false"
              class="px-3 py-2 bg-primary-500 text-white rounded-xl text-xs font-medium hover:bg-primary-600 transition-colors"
            >
              OK
            </button>
          </div>
          <button 
            v-else
            @click="editingHandoff = true"
            class="w-full bg-gray-50 dark:bg-dark-card border border-gray-100 dark:border-dark-border rounded-xl p-3 text-sm text-left font-mono text-gray-700 dark:text-gray-300 hover:border-primary-200 dark:hover:border-primary-500/30 transition-colors flex items-center justify-between"
          >
            <span>{{ handoffNumber }}</span>
            <span class="text-[10px] text-primary-500 font-sans font-medium">Editar</span>
          </button>
          <p class="text-[10px] text-gray-400 dark:text-dark-muted mt-1.5">Número para transferência quando IA finalizar qualificação.</p>
        </div>

        <!-- Generate Summary -->
        <div>
          <label class="text-[10px] uppercase tracking-wider text-gray-400 dark:text-dark-muted mb-2 block font-semibold">Resumo</label>
          <button 
            @click="generateSummary"
            :disabled="summaryLoading"
            class="w-full bg-white dark:bg-dark-card hover:bg-gray-50 dark:hover:bg-dark-border border border-gray-100 dark:border-dark-border text-gray-900 dark:text-white py-3 rounded-xl flex items-center justify-center gap-2 font-medium transition-all text-sm disabled:opacity-50"
          >
            <FileText class="w-4 h-4 text-primary-500" /> 
            {{ summaryLoading ? 'Gerando...' : 'Gerar Resumo' }}
          </button>
        </div>
      </div>
    </aside>
  </div>
</template>

<style scoped>
.custom-scrollbar {
  scrollbar-width: thin;
  scrollbar-color: #E5E7EB #F9FAFB;
}
:global(.dark) .custom-scrollbar {
  scrollbar-color: #1F2937 #0B0F1A;
}

.custom-scrollbar::-webkit-scrollbar {
  width: 6px;
}
.custom-scrollbar::-webkit-scrollbar-track {
  background: #F9FAFB;
}
:global(.dark) .custom-scrollbar::-webkit-scrollbar-track {
  background: #0B0F1A;
}
.custom-scrollbar::-webkit-scrollbar-thumb {
  background-color: #E5E7EB;
  border-radius: 4px;
}
:global(.dark) .custom-scrollbar::-webkit-scrollbar-thumb {
  background-color: #1F2937;
}

.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.3s ease;
}
.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
