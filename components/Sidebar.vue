<script setup lang="ts">
import { ref, computed, nextTick, onMounted, onUnmounted, watch } from 'vue'
import { useSupabaseClient } from '#imports'
import { 
  LayoutDashboard, 
  KanbanSquare, 
  MessageSquare, 
  Users, 
  UserCircle,
  BarChart3, 
  LogOut,
  Building,
  ChevronsLeft,
  ChevronsRight,
  RefreshCw,
  Globe,
  Settings,
  Car,
  CalendarDays,
  Clock,
  Menu,
  X
} from 'lucide-vue-next'

const router = useRouter()
const route = useRoute()
const mobileMenuOpen = ref(false)
const mobileTrigger = ref<HTMLButtonElement | null>(null)
const mobileClose = ref<HTMLButtonElement | null>(null)
const sidebar = ref<HTMLElement | null>(null)
const desktop = ref(false)
const menuModal = computed(() => mobileMenuOpen.value && !desktop.value)
let desktopQuery: MediaQueryList | undefined

function syncViewport() {
  desktop.value = desktopQuery?.matches ?? false
  if (desktop.value) mobileMenuOpen.value = false
}

async function openMenu() {
  mobileMenuOpen.value = true
  await nextTick()
  mobileClose.value?.focus()
}

async function closeMenu(restoreFocus = true) {
  mobileMenuOpen.value = false
  if (restoreFocus) {
    await nextTick()
    mobileTrigger.value?.focus()
  }
}

function handleMenuKey(event: KeyboardEvent) {
  if (!menuModal.value) return
  if (event.key === 'Escape') {
    event.preventDefault()
    void closeMenu()
  }
  if (event.key !== 'Tab') return
  const controls = Array.from(sidebar.value?.querySelectorAll<HTMLElement>('button:not(:disabled), a[href]:not([aria-disabled="true"])') ?? [])
    .filter(control => control.getClientRects().length)
  const first = controls[0]
  const last = controls.at(-1)
  if (event.shiftKey && document.activeElement === first) {
    event.preventDefault()
    last?.focus()
  } else if (!event.shiftKey && document.activeElement === last) {
    event.preventDefault()
    first?.focus()
  }
}

watch(() => route.fullPath, () => {
  if (mobileMenuOpen.value) void closeMenu(false)
})
const { isCollapsed, toggleSidebar, sidebarWidth } = useSidebarState()
const supabase = useSupabaseClient<any>()
const currentUser = useSupabaseUser()

const leadsCount = ref(0)
const semCorretorCount = ref(0)
let realtimeChannel: any

const fetchLeadsCount = async () => {
  try {
    const { count, error } = await supabase
      .from('leads')
      .select('*', { count: 'exact', head: true })
      
    if (!error && count !== null) {
      leadsCount.value = count
    }

    const { count: unassignedCount, error: unassignedError } = await supabase
      .from('leads')
      .select('*', { count: 'exact', head: true })
      .is('corretor_id', null)

    if (!unassignedError && unassignedCount !== null) {
      semCorretorCount.value = unassignedCount
    }
  } catch (err) {
    console.error('Error fetching leads count:', err)
  }
}

onMounted(() => {
  desktopQuery = window.matchMedia('(min-width: 1024px)')
  syncViewport()
  desktopQuery.addEventListener('change', syncViewport)
  fetchLeadsCount()
  
  realtimeChannel = supabase.channel('sidebar_leads_changes')
    .on(
      'postgres_changes',
      { event: '*', schema: 'public', table: 'leads' },
      () => {
        fetchLeadsCount()
      }
    )
    .subscribe()
})

onUnmounted(() => {
  desktopQuery?.removeEventListener('change', syncViewport)
  if (realtimeChannel) {
    supabase.removeChannel(realtimeChannel)
  }
})

const navigation = computed(() => [
  { name: 'PRINCIPAL', items: [
    { name: 'Dashboard', icon: LayoutDashboard, route: '/dashboard' },
    { name: 'Negociações', icon: KanbanSquare, route: '/crm', badge: leadsCount.value > 0 ? String(leadsCount.value) : undefined },
    { name: 'Contatos', icon: Users, route: '/contatos' },
    { name: 'Corretores', icon: UserCircle, route: '/corretores' },
    { name: 'Visitas', icon: CalendarDays, route: '/agenda' },
    { name: 'Leads Espera', icon: Clock, route: '/semcorretor', badge: semCorretorCount.value > 0 ? String(semCorretorCount.value) : undefined },
  ]},
  { name: 'GESTÃO', items: [
    { name: 'Imóveis', icon: Building, route: '/inventario' },
    { name: 'Conversas', icon: MessageSquare, route: '/chats' },
    { name: 'Relatórios', icon: BarChart3, route: '/relatorios' },
    { name: 'Reativar Interessados', icon: RefreshCw, route: '#', badge: 'PRO', disabled: true },
  ]},
  { name: 'ADMINISTRAÇÃO', items: [
    { name: 'Catálogo Público', icon: Globe, route: '#', badge: 'PRO', disabled: true },
    { name: 'Configurações', icon: Settings, route: '/configuracoes' },
  ]}
])

const handleLogout = async () => {
  router.push('/login')
}
</script>

<template>
  <div class="fixed inset-x-0 top-0 z-40 flex h-14 items-center gap-3 border-b border-gray-200 bg-white px-3 dark:border-dark-border dark:bg-dark-bg lg:hidden">
    <button ref="mobileTrigger" type="button" class="inline-flex h-11 w-11 items-center justify-center rounded-lg text-primary-600 hover:bg-primary-50 dark:text-primary-400 dark:hover:bg-primary-500/10"
      aria-label="Abrir menu" aria-controls="crm-navigation" :aria-expanded="menuModal" @click="openMenu">
      <Menu class="h-6 w-6" aria-hidden="true" />
    </button>
    <span class="text-sm font-bold tracking-tight">Império Imóveis</span>
  </div>

  <div v-if="menuModal" aria-hidden="true" class="fixed inset-0 z-50 bg-black/40 lg:hidden" @click="closeMenu()" />

  <aside
    id="crm-navigation"
    ref="sidebar"
    :role="menuModal ? 'dialog' : undefined"
    :aria-modal="menuModal ? true : undefined"
    :aria-label="menuModal ? 'Menu principal' : undefined"
    @keydown="handleMenuKey"
    :class="[
      'fixed left-0 top-0 z-[60] h-dvh w-[min(18rem,calc(100vw-2.75rem))] flex-col overflow-hidden border-r border-gray-100 bg-white dark:border-dark-border dark:bg-dark-bg lg:z-50 lg:flex lg:bg-white/80 lg:backdrop-blur-2xl lg:dark:bg-dark-bg/80 sidebar-transition',
      menuModal ? 'flex' : 'hidden',
      sidebarWidth
    ]"
  >
    <!-- Header / Logo -->
    <div class="h-[72px] shrink-0 flex items-center max-lg:justify-between max-lg:px-4 border-b border-gray-100 dark:border-dark-border" :class="isCollapsed ? 'px-4 justify-center' : 'px-6 justify-between'">
      <div class="flex items-center gap-3 group cursor-pointer" :class="isCollapsed ? 'justify-center' : ''">
         <div class="w-10 h-10 rounded-sm bg-primary-500 flex items-center justify-center shadow-luxury sidebar-transition group-hover:scale-105 flex-shrink-0">
            <Building class="w-5 h-5 text-white" />
         </div>
         <div v-if="!isCollapsed || menuModal" class="sidebar-text-transition overflow-hidden">
           <span class="text-gray-900 dark:text-white font-bold text-lg tracking-tight block whitespace-nowrap">IMPÉRIO</span>
           <span class="text-[11px] text-gray-400 dark:text-dark-muted font-medium whitespace-nowrap uppercase tracking-wider">Imóveis</span>
         </div>
      </div>
      <button 
        ref="mobileClose" type="button" @click="closeMenu()"
        class="ml-auto inline-flex h-11 w-11 shrink-0 items-center justify-center rounded-lg text-gray-600 hover:bg-gray-100 dark:text-white dark:hover:bg-dark-card lg:hidden"
        aria-label="Fechar menu"
      >
        <X class="h-5 w-5" aria-hidden="true" />
      </button>
      <button
        @click="toggleSidebar"
        class="hidden lg:block p-1.5 rounded-lg text-gray-400 hover:text-primary-500 hover:bg-primary-50 dark:hover:bg-primary-500/10 sidebar-transition"
        :title="isCollapsed ? 'Expandir menu' : 'Recolher menu'"
      >
        <ChevronsLeft v-if="!isCollapsed || menuModal" class="w-4 h-4" />
        <ChevronsRight v-else class="w-4 h-4" />
      </button>
    </div>

    <!-- Navigation -->
    <nav aria-label="Principal" class="flex-1 overflow-y-auto overscroll-contain py-4 lg:py-6 max-lg:px-3" :class="isCollapsed ? 'px-3' : 'px-4'">
      <div v-for="section in navigation" :key="section.name" class="mb-6">
        <h3 
          v-if="!isCollapsed || menuModal"
          class="text-[10px] font-semibold text-gray-400 dark:text-dark-muted uppercase tracking-[0.15em] px-4 mb-3 sidebar-text-transition"
        >
          {{ section.name }}
        </h3>
        <div v-else class="h-px bg-gray-100 dark:bg-dark-border mb-3 mx-2"></div>
        
        <ul class="space-y-1">
          <li v-for="item in section.items" :key="item.name">
            <NuxtLink 
              :to="item.route" 
              :class="[
                'flex items-center rounded-sm text-sm font-medium text-gray-500 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white hover:bg-gray-50/50 dark:hover:bg-white/5 sidebar-transition group relative border-l-2 border-transparent max-lg:min-h-11 max-lg:justify-start max-lg:gap-3 max-lg:px-3',
                isCollapsed ? 'justify-center p-3' : 'gap-3 px-4 py-2.5',
                (item as any).disabled ? 'opacity-50 pointer-events-none cursor-not-allowed' : ''
              ]"
              active-class="!text-primary-500 !border-primary-500 !font-semibold bg-gray-50/20 dark:bg-white/5"
              :title="item.name"
              :aria-label="item.name"
              :aria-disabled="item.disabled || undefined"
              :tabindex="item.disabled ? -1 : undefined"
              @click="menuModal && !item.disabled && closeMenu(false)"
              :target="(item as any).external ? '_blank' : undefined"
            >
              <component 
                :is="item.icon" 
                class="w-[18px] h-[18px] sidebar-transition flex-shrink-0" 
              />
              
              <span v-if="!isCollapsed || menuModal" class="flex-1 sidebar-text-transition">{{ item.name }}</span>

              <!-- Badge -->
              <span 
                v-if="(item as any).badge && (!isCollapsed || menuModal)"
                class="inline bg-primary-500 text-white text-[10px] font-bold px-2 py-0.5 rounded-full shadow-sm"
              >
                {{ (item as any).badge }}
              </span>

              <!-- Collapsed badge dot -->
              <span 
                v-if="(item as any).badge && isCollapsed && !menuModal"
                class="absolute top-1.5 right-1.5 w-2 h-2 bg-primary-500 rounded-full"
              ></span>
            </NuxtLink>
          </li>
        </ul>
      </div>
    </nav>

    <!-- Theme Toggle -->
    <div class="px-4 max-lg:px-4 py-2 border-t border-gray-100 dark:border-dark-border flex" :class="isCollapsed ? 'justify-center' : 'justify-end'">
      <ThemeToggle />
    </div>

    <!-- Footer / User Profile + Collapse -->
    <div class="p-4 max-lg:p-2 border-t border-gray-100 dark:border-dark-border">
      <div 
        :class="[
          'flex items-center rounded-sm hover:bg-gray-50 dark:hover:bg-white/5 sidebar-transition group max-lg:justify-start max-lg:gap-3 max-lg:p-2',
          isCollapsed ? 'justify-center p-2' : 'gap-3 p-3'
        ]"
      >
        <!-- Avatar -->
        <div class="w-9 h-9 rounded-sm bg-primary-50 dark:bg-primary-500/10 border border-primary-100 dark:border-primary-500/20 flex items-center justify-center text-primary-600 dark:text-primary-400 font-bold text-sm flex-shrink-0 uppercase">
          {{ currentUser?.user_metadata?.full_name?.charAt(0) || currentUser?.email?.charAt(0) || 'U' }}
        </div>
        
        <template v-if="!isCollapsed || menuModal">
          <div class="flex-1 min-w-0">
            <p class="text-sm font-semibold text-gray-900 dark:text-white truncate">
              {{ currentUser?.user_metadata?.full_name || currentUser?.email?.split('@')[0] || 'Usuário' }}
            </p>
            <p class="text-xs text-gray-400 dark:text-dark-muted">Admin</p>
          </div>

          <button @click="handleLogout" class="text-gray-400 hover:text-red-500 hover:bg-red-50 dark:hover:bg-red-500/10 p-2 rounded-sm sidebar-transition" title="Sair">
            <LogOut class="w-4 h-4" />
          </button>
        </template>
      </div>
    </div>
  </aside>
</template>

<style scoped>
.sidebar-transition {
  transition: color 0.2s, background-color 0.2s;
}

.sidebar-text-transition {
  transition: opacity 0.15s ease, transform 0.15s ease;
}
</style>
