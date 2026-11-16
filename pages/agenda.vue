<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useSupabaseClient } from '#imports'
import { 
  CalendarDays, ChevronLeft, ChevronRight, Clock, User, Bot, Sparkles, MessageSquare
} from 'lucide-vue-next'

const { mainMargin } = useSidebarState()

const notifyBrokerWhatsApp = (apt: any) => {
  const text = `Olá Corretor! 🤖 A IA agendou uma visita para o lead *${apt.patient}*.\n\n📅 *Horário:* ${apt.hour}\n🏠 *Interesse/Imóvel:* ${apt.procedure}\n\nPor favor, confirme na sua agenda!`
  const url = `https://wa.me/?text=${encodeURIComponent(text)}`
  window.open(url, '_blank')
}

// Brokers (Corretores)
// Appointment Statuses
const statuses = [
  { id: 'agendado', label: 'Agendado', color: 'bg-blue-500', light: 'bg-blue-50 dark:bg-blue-500/10 text-blue-700 dark:text-blue-300 border-blue-200 dark:border-blue-500/20' },
  { id: 'concluido', label: 'Concluído', color: 'bg-emerald-500', light: 'bg-emerald-50 dark:bg-emerald-500/10 text-emerald-700 dark:text-emerald-300 border-emerald-200 dark:border-emerald-500/20' },
  { id: 'cancelado', label: 'Cancelado', color: 'bg-red-500', light: 'bg-red-50 dark:bg-red-500/10 text-red-700 dark:text-red-300 border-red-200 dark:border-red-500/20' },
  { id: 'falta', label: 'Faltou', color: 'bg-orange-500', light: 'bg-orange-50 dark:bg-orange-500/10 text-orange-700 dark:text-orange-300 border-orange-200 dark:border-orange-500/20' },
]

// State
const currentDate = ref(new Date())

// Modal State
const isModalOpen = ref(false)
const selectedAppointment = ref<any>(null)
const updatingStatus = ref(false)

// Current week days
const weekDays = computed(() => {
  const d = new Date(currentDate.value)
  const day = d.getDay()
  const monday = new Date(d)
  monday.setDate(d.getDate() - (day === 0 ? 6 : day - 1))
  
  const days = []
  for (let i = 0; i < 7; i++) {
    const date = new Date(monday)
    date.setDate(monday.getDate() + i)
    days.push(date)
  }
  return days
})

const weekLabel = computed(() => {
  const first = weekDays.value[0]
  const last = weekDays.value[6]
  const months = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez']
  if (first!.getMonth() === last!.getMonth()) {
    return `${first!.getDate()} – ${last!.getDate()} ${months[first!.getMonth()]} ${first!.getFullYear()}`
  }
  return `${first!.getDate()} ${months[first!.getMonth()]} – ${last!.getDate()} ${months[last!.getMonth()]} ${last!.getFullYear()}`
})

const dayLabels = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom']
const hours = ['08:00', '09:00', '10:00', '11:00', '12:00', '13:00', '14:00', '15:00', '16:00', '17:00', '18:00']

// Navigate
const prevWeek = () => {
  const d = new Date(currentDate.value)
  d.setDate(d.getDate() - 7)
  currentDate.value = d
}
const nextWeek = () => {
  const d = new Date(currentDate.value)
  d.setDate(d.getDate() + 7)
  currentDate.value = d
}
const goToday = () => {
  currentDate.value = new Date()
}

// Check if date is today
const isToday = (date: Date) => {
  const today = new Date()
  return date.getDate() === today.getDate() && date.getMonth() === today.getMonth() && date.getFullYear() === today.getFullYear()
}

const supabase = useSupabaseClient<any>()
const dbAppointments = ref<any[]>([])
const loadingAppointments = ref(true)
const appointmentError = ref('')

const fetchAppointments = async () => {
  appointmentError.value = ''
  try {
    const { data: aps, error } = await supabase.from('appointments').select(`
      *,
      leads(name)
    `)
    if (error) throw error
    dbAppointments.value = aps || []
  } catch (error) {
    appointmentError.value = 'Não foi possível carregar os agendamentos.'
    console.error('Error fetching appointments:', error)
  } finally {
    loadingAppointments.value = false
  }
}

let realtimeChannel: any

const setupRealtime = () => {
  realtimeChannel = supabase.channel('agenda_appointments')
    .on(
      'postgres_changes',
      { event: '*', schema: 'public', table: 'appointments' },
      () => {
        fetchAppointments()
      }
    )
    .subscribe()
}

onMounted(() => {
  fetchAppointments()
  setupRealtime()
})

onUnmounted(() => {
  if (realtimeChannel) {
    supabase.removeChannel(realtimeChannel)
  }
})

const dateKey = (date: Date) => [
  date.getFullYear(),
  String(date.getMonth() + 1).padStart(2, '0'),
  String(date.getDate()).padStart(2, '0')
].join('-')

function mapAppointment(appointment: any) {
  let duration = 1
  if (appointment.start_time && appointment.end_time) {
    const start = new Date('1970-01-01T' + appointment.start_time)
    const end = new Date('1970-01-01T' + appointment.end_time)
    duration = (end.getTime() - start.getTime()) / (1000 * 60 * 60)
  }
  return {
    id: appointment.id,
    patient: appointment.leads?.name || 'Interessado Desconhecido',
    procedure: appointment.about || 'Contato ou Consulta',
    hour: appointment.start_time?.substring(0, 5) || 'Sem horário',
    duration: Number.isFinite(duration) ? Math.max(1, duration) : 1,
    status: appointment.status || 'agendado',
    is_ai: appointment.created_by_ia !== false
  }
}

const appointmentsByDate = computed(() => {
  const days = new Map<string, ReturnType<typeof mapAppointment>[]>()
  for (const appointment of dbAppointments.value) {
    const entries = days.get(appointment.appointment_date) ?? []
    entries.push(mapAppointment(appointment))
    days.set(appointment.appointment_date, entries)
  }
  for (const entries of days.values()) entries.sort((first, second) => first.hour.localeCompare(second.hour))
  return days
})
const selectedDay = computed(() => dateKey(currentDate.value))
const dayAppointments = computed(() => appointmentsByDate.value.get(selectedDay.value) ?? [])
const selectedDayLabel = computed(() => currentDate.value.toLocaleDateString('pt-BR', {
  weekday: 'long', day: 'numeric', month: 'long'
}))
const getAppointments = (date: Date, hour: string) =>
  appointmentsByDate.value.get(dateKey(date))?.filter(appointment => appointment.hour.slice(0, 2) === hour.slice(0, 2)) ?? []

// Get status info
const getStatusTheme = (statusStr: string): any => statuses.find(s => s.id === statusStr) || statuses[0]

// Modal Actions
const openAppointmentModal = (apt: any) => {
  // Pass a cloned object to model so it doesn't mutably break UI until confirmed via DB 
  selectedAppointment.value = { ...apt }
  isModalOpen.value = true
}

const closeModal = () => {
  isModalOpen.value = false
  setTimeout(() => { selectedAppointment.value = null }, 300)
}

const updateAppointmentMode = async () => {
  if (!selectedAppointment.value) return
  updatingStatus.value = true
  try {
    const { error } = await supabase.from('appointments').update({ status: selectedAppointment.value.status }).eq('id', selectedAppointment.value.id)
    if (error) throw error
    // Automatically picked up by setupRealtime -> fetchAppointments!
    closeModal()
  } catch (e) {
    console.error('Error updating status', e)
  } finally {
    updatingStatus.value = false
  }
}

const todayCount = computed(() => appointmentsByDate.value.get(dateKey(new Date()))?.length ?? 0)
</script>

<template>
  <div class="flow-root min-h-dvh bg-gray-50 dark:bg-dark-bg text-gray-900 dark:text-white font-sans transition-colors duration-300">
    <Sidebar />

    <main :class="[mainMargin, 'p-3 sm:p-5 xl:p-8 transition-all duration-300']">
      <!-- Header -->
      <header class="mb-4 flex flex-wrap items-center justify-between gap-3 lg:mb-6">
        <div class="flex items-center gap-4">
          <div class="p-2.5 bg-primary-50 dark:bg-primary-500/10 rounded-xl text-primary-500">
            <CalendarDays class="w-6 h-6" />
          </div>
          <div>
            <h1 class="text-xl font-bold tracking-tight">Agenda</h1>
            <p class="text-gray-400 dark:text-dark-muted text-sm mt-0.5">{{ todayCount }} agendamentos hoje</p>
          </div>
        </div>

        <div class="flex w-full flex-wrap items-center gap-2 lg:w-auto lg:gap-3">
          <!-- Status Legend -->
          <div class="mr-2 hidden flex-wrap items-center gap-3 2xl:flex">
            <div v-for="st in statuses" :key="st.id" class="flex items-center gap-1.5">
              <div :class="['w-2.5 h-2.5 rounded-full', st.color]"></div>
              <span class="text-[11px] font-medium text-gray-500 dark:text-dark-muted">{{ st.label }}</span>
            </div>
          </div>

          <!-- Navigation -->
          <button @click="goToday" class="min-h-11 px-3 text-xs font-semibold text-primary-500 bg-primary-50 dark:bg-primary-500/10 rounded-lg border border-primary-200 dark:border-primary-500/20 hover:bg-primary-100 transition-colors">
            Hoje
          </button>
          <div class="flex min-w-0 flex-1 items-center justify-between gap-1 rounded-lg border border-gray-200 bg-white dark:border-dark-border dark:bg-dark-surface lg:flex-none">
            <button aria-label="Semana anterior" @click="prevWeek" class="inline-flex h-11 w-11 shrink-0 items-center justify-center rounded-lg text-gray-600 hover:text-gray-700 dark:hover:text-white hover:bg-gray-100 dark:hover:bg-dark-card transition-colors">
              <ChevronLeft class="w-4 h-4" />
            </button>
            <span class="text-sm font-semibold text-gray-700 dark:text-gray-300 text-center lg:min-w-32 lg:px-2">{{ weekLabel }}</span>
            <button aria-label="Próxima semana" @click="nextWeek" class="inline-flex h-11 w-11 shrink-0 items-center justify-center rounded-lg text-gray-600 hover:text-gray-700 dark:hover:text-white hover:bg-gray-100 dark:hover:bg-dark-card transition-colors">
              <ChevronRight class="w-4 h-4" />
            </button>
          </div>
        </div>
      </header>

      <p v-if="appointmentError" role="alert" class="mb-4 rounded-lg bg-red-50 p-3 text-sm text-red-700 dark:bg-red-500/10 dark:text-red-200">
        {{ appointmentError }} <button type="button" class="underline" @click="fetchAppointments">Tentar novamente</button>
      </p>

      <section class="lg:hidden" aria-label="Agenda por dia">
        <div class="grid grid-cols-7 gap-1 rounded-xl border border-gray-200 bg-white p-1 dark:border-dark-border dark:bg-dark-surface">
          <button v-for="(day, index) in weekDays" :key="dateKey(day)" type="button" :aria-pressed="dateKey(day) === selectedDay"
            :aria-label="day.toLocaleDateString('pt-BR', { weekday: 'long', day: 'numeric', month: 'long' })"
            :class="['flex min-h-14 min-w-0 flex-col items-center justify-center rounded-lg text-xs font-semibold',
              dateKey(day) === selectedDay ? 'bg-primary-600 text-white' : 'text-gray-600 hover:bg-gray-100 dark:text-gray-200 dark:hover:bg-dark-card']"
            @click="currentDate = day">
            <span>{{ dayLabels[index] }}</span>
            <span class="text-base tabular-nums">{{ day.getDate() }}</span>
          </button>
        </div>
        <h2 class="mb-3 mt-5 text-base font-semibold capitalize">{{ selectedDayLabel }}</h2>
        <p v-if="loadingAppointments" role="status" class="text-sm text-gray-600 dark:text-dark-muted">Carregando agendamentos…</p>
        <p v-else-if="!appointmentError && !dayAppointments.length" class="rounded-xl border border-dashed border-gray-200 p-5 text-sm text-gray-600 dark:border-dark-border dark:text-dark-muted">Nenhum agendamento neste dia.</p>
        <ul v-else class="space-y-2">
          <li v-for="apt in dayAppointments" :key="apt.id">
            <button type="button" @click="openAppointmentModal(apt)"
              class="grid w-full grid-cols-[auto_minmax(0,1fr)] gap-3 rounded-xl border border-gray-200 bg-white px-3 py-3 text-left dark:border-dark-border dark:bg-dark-surface">
              <span class="rounded-lg bg-primary-50 px-2 py-1 text-sm font-bold tabular-nums text-primary-700 dark:bg-primary-500/10 dark:text-primary-400">{{ apt.hour }}</span>
              <span class="min-w-0">
                <span class="block break-words text-sm font-semibold">{{ apt.patient }}</span>
                <span class="mb-2 block break-words text-sm text-gray-600 dark:text-dark-muted">{{ apt.procedure }}</span>
                <span :class="['inline-flex rounded-md border px-2 py-0.5 text-xs', getStatusTheme(apt.status).light]">{{ getStatusTheme(apt.status).label }}</span>
                <span v-if="apt.is_ai" class="ml-2 text-xs font-medium text-primary-600 dark:text-primary-400">IA</span>
              </span>
            </button>
          </li>
        </ul>
      </section>

      <!-- Calendar Grid -->
      <div class="hidden lg:block bg-white dark:bg-dark-surface border border-gray-100 dark:border-dark-border rounded-xl overflow-hidden">
        <!-- Day Headers -->
        <div class="grid grid-cols-[60px_repeat(7,1fr)] border-b border-gray-100 dark:border-dark-border">
          <div class="p-2"></div>
          <div 
            v-for="(day, idx) in weekDays" 
            :key="idx"
            :class="[
              'py-3 px-2 text-center border-l border-gray-100 dark:border-dark-border',
              isToday(day) ? 'bg-primary-50/50 dark:bg-primary-500/5' : ''
            ]"
          >
            <span class="text-[10px] font-semibold text-gray-400 dark:text-dark-muted uppercase tracking-wider">{{ dayLabels[idx] }}</span>
            <p :class="[
              'text-lg font-bold mt-0.5',
              isToday(day) ? 'text-primary-500' : 'text-gray-900 dark:text-white'
            ]">
              {{ day.getDate() }}
            </p>
          </div>
        </div>

        <!-- Time Slots -->
        <div class="max-h-[calc(100dvh-260px)] overflow-y-auto">
          <div v-for="hour in hours" :key="hour" class="grid grid-cols-[60px_repeat(7,1fr)] border-b border-gray-50 dark:border-dark-border/50 min-h-[70px]">
            <!-- Hour Label -->
            <div class="p-2 text-[11px] font-medium text-gray-400 dark:text-dark-muted text-right pr-3 pt-1">
              {{ hour }}
            </div>

            <!-- Day Cells -->
            <div 
              v-for="(day, dayIdx) in weekDays" 
              :key="dayIdx"
              :class="[
                'border-l border-gray-50 dark:border-dark-border/50 p-0.5 relative min-w-0',
                isToday(day) ? 'bg-primary-50/20 dark:bg-primary-500/[0.02]' : ''
              ]"
            >
              <!-- Appointments -->
              <div 
                v-for="apt in getAppointments(day, hour)" 
                :key="apt.id + apt.hour"
                @click="openAppointmentModal(apt)"
                :class="[
                  'rounded-lg p-2 border text-[11px] leading-tight cursor-pointer shadow-sm transition-all overflow-hidden flex flex-col hover:ring-2 hover:ring-primary-500/30 hover:shadow-md hover:-translate-y-0.5',
                  getStatusTheme(apt.status).light
                ]"
                :style="{ minHeight: (apt.duration * 66 - 4) + 'px' }"
              >
                <div class="flex items-center justify-between gap-1 mb-0.5 min-w-0">
                  <div class="flex items-center gap-1.5 min-w-0">
                    <div :class="['w-2 h-2 rounded-full flex-shrink-0 animate-pulse', getStatusTheme(apt.status).color]"></div>
                    <span class="font-bold truncate">{{ apt.patient }}</span>
                  </div>
                  <span v-if="apt.is_ai" class="inline-flex items-center gap-0.5 text-[8px] font-bold text-primary-600 dark:text-primary-400 bg-primary-50 dark:bg-primary-500/10 px-1 rounded border border-primary-200 dark:border-primary-500/20 flex-shrink-0" title="Agendado automaticamente por IA">
                    <Bot class="w-2.5 h-2.5" /> IA
                  </span>
                </div>
                <p class="text-[10px] opacity-75 truncate w-full">{{ apt.procedure }}</p>
                <div class="flex items-center gap-1 mt-auto opacity-60">
                  <Clock class="w-2.5 h-2.5" />
                  <span class="text-[9px]">{{ apt.hour }} · {{ apt.duration }}h</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </main>

    <!-- Appointment Modal -->
    <Transition name="fade">
      <div v-if="isModalOpen" class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <!-- Backdrop -->
        <div class="absolute inset-0 bg-gray-900/40 backdrop-blur-sm transition-opacity" @click="closeModal"></div>
        
        <!-- Modal Content -->
        <div class="relative w-full max-w-sm bg-white dark:bg-dark-surface rounded-2xl shadow-xl overflow-hidden border border-gray-100 dark:border-dark-border transform transition-all scale-100">
          <div class="px-5 py-4 border-b border-gray-100 dark:border-dark-border flex items-center justify-between bg-gray-50/50 dark:bg-dark-card">
            <h3 class="text-sm font-bold text-gray-900 dark:text-white">Detalhes do Agendamento</h3>
            <button @click="closeModal" class="text-gray-400 hover:text-gray-600 dark:hover:text-white transition-colors">
              <span class="sr-only">Fechar</span>
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/></svg>
            </button>
          </div>
          
          <div class="p-5 flex flex-col gap-4" v-if="selectedAppointment">
            <!-- Patient / Lead -->
            <div>
              <label class="text-[9px] uppercase font-bold text-gray-400 tracking-wider block mb-1">Paciente / Lead</label>
              <div class="text-sm font-semibold text-gray-900 dark:text-white">{{ selectedAppointment.patient }}</div>
            </div>
            
            <!-- Procedure -->
            <div>
              <label class="text-[9px] uppercase font-bold text-gray-400 tracking-wider block mb-1">Procedimento</label>
              <div class="text-sm text-gray-700 dark:text-gray-300">{{ selectedAppointment.procedure }}</div>
            </div>
            
            <!-- Info Row -->
            <div class="flex items-center gap-6 bg-gray-50 dark:bg-dark-bg p-3 rounded-xl border border-gray-100 dark:border-dark-border">
              <div class="flex-1">
                <label class="text-[9px] uppercase font-bold text-gray-400 tracking-wider block mb-1 flex items-center gap-1">
                   <Clock class="w-3 h-3" /> Horário
                </label>
                <div class="text-sm font-medium text-gray-800 dark:text-gray-200">{{ selectedAppointment.hour }}</div>
              </div>
              <div class="flex-1">
                <label class="text-[9px] uppercase font-bold text-gray-400 tracking-wider block mb-1">Duração</label>
                <div class="text-sm font-medium text-gray-800 dark:text-gray-200">{{ selectedAppointment.duration }} hr(s)</div>
              </div>
            </div>
            
            <!-- Status Updater -->
            <div class="pt-1">
              <label class="text-[9px] uppercase font-bold text-gray-400 tracking-wider block mb-1.5">Status do Agendamento</label>
              <div class="relative">
                <select 
                  v-model="selectedAppointment.status"
                  @change="updateAppointmentMode"
                  :disabled="updatingStatus"
                  class="w-full bg-white dark:bg-dark-card border border-gray-200 dark:border-dark-border rounded-xl px-4 py-2.5 text-sm font-medium focus:outline-none focus:ring-2 focus:ring-primary-500/50 appearance-none disabled:opacity-50 transition-colors shadow-sm"
                  :class="[
                     getStatusTheme(selectedAppointment.status).color.replace('bg-', 'text-').replace('500', '600'),
                     'dark:' + getStatusTheme(selectedAppointment.status).color.replace('bg-', 'text-').replace('500', '400')
                  ]"
                >
                  <option v-for="st in statuses" :key="st.id" :value="st.id">{{ st.label }}</option>
                </select>
                <div class="pointer-events-none absolute inset-y-0 right-0 flex items-center px-4 text-gray-500">
                  <div v-if="updatingStatus" class="animate-spin w-3.5 h-3.5 border-2 border-gray-400 border-t-transparent rounded-full"></div>
                  <svg v-else class="h-4 w-4 opacity-50" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/></svg>
                </div>
              </div>
            </div>
            
            <!-- Notificar Corretor via WhatsApp -->
            <div class="pt-2">
              <button 
                @click="notifyBrokerWhatsApp(selectedAppointment)" 
                class="w-full flex items-center justify-center gap-2 px-4 py-2.5 bg-emerald-500 hover:bg-emerald-600 text-white font-semibold text-xs rounded-xl transition-all shadow-sm group"
              >
                <MessageSquare class="w-4 h-4 group-hover:scale-110 transition-transform" /> 
                Notificar Corretor via WhatsApp
              </button>
            </div>
            
          </div>
        </div>
      </div>
    </Transition>
  </div>
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
