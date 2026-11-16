<script setup lang="ts">
import { Eye, MessageCircle, Lock, Bot } from 'lucide-vue-next'
import type { Cliente, CrmStatus } from '@/types/crm'

defineProps<{
  leads: Cliente[]
  page: number
  pageSize: number
  total: number
  loading: boolean
}>()

const emit = defineEmits<{
  (e: 'change-page', page: number): void
  (e: 'view-details', lead: Cliente): void
  (e: 'open-chat', leadId: string): void
}>()

const statusConfig: Record<string, { label: string; color: string }> = {
  novo: { label: 'Novo', color: 'bg-primary-50 dark:bg-primary-500/10 text-primary-600 dark:text-primary-400' },
  em_atendimento: { label: 'Em Atendimento', color: 'bg-violet-50 text-violet-700 dark:bg-violet-500/10 dark:text-violet-300' },
  negociacao: { label: 'Em Negociação', color: 'bg-amber-50 text-amber-700 dark:bg-amber-500/10 dark:text-amber-300' },
  visita: { label: 'Visita', color: 'bg-teal-50 text-teal-700 dark:bg-teal-500/10 dark:text-teal-300' },
  agendamento: { label: 'Agendamento', color: 'bg-teal-50 text-teal-700 dark:bg-teal-500/10 dark:text-teal-300' },
  fechado: { label: 'Venda Fechada', color: 'bg-green-50 text-green-700 dark:bg-green-500/10 dark:text-green-300' },
  em_contato: { label: 'Em Contato', color: 'bg-amber-50 dark:bg-amber-500/10 text-amber-600 dark:text-amber-400' },
  qualificado: { label: 'Qualificado', color: 'bg-emerald-50 dark:bg-emerald-500/10 text-emerald-600 dark:text-emerald-400' },
  convertido: { label: 'Convertido', color: 'bg-emerald-50 dark:bg-emerald-500/10 text-emerald-600 dark:text-emerald-400' },
  perdido: { label: 'Perdido', color: 'bg-red-50 dark:bg-red-500/10 text-red-600 dark:text-red-400' },
}
</script>

<template>
  <div class="bg-white/80 dark:bg-dark-surface/80 backdrop-blur-xl border border-gray-100/50 dark:border-dark-border/50 rounded-sm overflow-hidden h-full flex flex-col shadow-card hover:shadow-card-hover transition-all duration-300">
    <div class="overflow-auto flex-1">
      <table class="block w-full text-left border-collapse xl:table">
        <thead class="hidden xl:sticky xl:top-0 xl:z-10 xl:table-header-group">
          <tr class="border-b border-gray-100 dark:border-dark-border text-gray-400 dark:text-dark-muted text-xs uppercase tracking-wider bg-gray-50/80 dark:bg-dark-card/80 backdrop-blur-sm">
            <th class="px-3 py-4 text-right font-medium">Contagem</th>
            <th class="px-6 py-4 font-medium">Nome</th>
            <th class="px-6 py-4 font-medium">Telefone</th>
            <th class="px-6 py-4 font-medium">Status (CRM)</th>
            <th class="px-6 py-4 font-medium">Cód. Imóvel</th>
            <th class="px-6 py-4 font-medium">Modo</th>
            <th class="px-6 py-4 font-medium text-right">Ações</th>
          </tr>
        </thead>
        <tbody class="block divide-y xl:table-row-group divide-gray-50 dark:divide-dark-border">
          <tr v-if="!leads.length && !loading" class="block xl:table-row"><td colspan="7" class="block xl:table-cell p-8 text-center text-gray-500">Nenhum lead encontrado.</td></tr>
          <tr v-for="(lead, index) in leads" :key="lead.id" class="group grid grid-cols-[auto_minmax(0,1fr)_auto] items-center gap-x-2 gap-y-2 px-3 py-3 xl:table-row xl:p-0 hover:bg-gray-50/50 dark:hover:bg-white/[0.02] transition-colors">
            <td class="px-0 py-1 xl:px-3 xl:py-4 text-sm tabular-nums text-right text-gray-600 dark:text-dark-muted">{{ (page - 1) * pageSize + index + 1 }}</td>
            <!-- Nome -->
            <td class="min-w-0 px-0 py-0 xl:px-6 xl:py-4">
              <div class="flex items-center gap-3">
                 <div v-if="lead.media_url" class="w-9 h-9 rounded-sm flex-shrink-0 overflow-hidden border border-gray-100 dark:border-dark-border">
                    <img :src="lead.media_url" :alt="lead.name || 'Avatar'" class="w-full h-full object-cover" />
                 </div>
                 <div v-else class="w-9 h-9 rounded-sm bg-primary-50 dark:bg-primary-500/10 flex items-center justify-center text-xs font-bold text-primary-600 dark:text-primary-400 border border-primary-100 dark:border-primary-500/20">
                    {{ (lead.name || 'D').charAt(0).toUpperCase() }}
                 </div>
                 <span class="min-w-0 break-words font-medium text-gray-900 dark:text-white text-sm">{{ lead.name || 'Desconhecido' }}</span>
              </div>
            </td>

            <!-- Telefone -->
            <td class="col-start-2 row-start-2 min-w-0 px-0 py-0 xl:px-6 xl:py-4">
               <span class="text-gray-400 dark:text-dark-muted break-all text-xs font-mono xl:text-sm">{{ lead.phone || lead.remotejid || '—' }}</span>
            </td>

            <!-- Status -->
            <td class="col-span-2 row-start-3 min-w-0 px-0 py-0 xl:px-6 xl:py-4">
              <span :class="['inline-flex items-center gap-2 px-3 py-1 rounded-sm text-xs font-medium', statusConfig[(lead.stage || lead.situacao_nome || lead.estagiokanbam) as CrmStatus]?.color || 'bg-gray-100 dark:bg-dark-card text-gray-500']">
                {{ statusConfig[(lead.stage || lead.situacao_nome || lead.estagiokanbam) as CrmStatus]?.label || lead.stage || lead.situacao_nome || lead.estagiokanbam || 'Novo' }}
              </span>
            </td>

            <!-- Código Imóvel -->
            <td class="col-span-2 row-start-4 min-w-0 break-words text-xs xl:px-6 xl:py-4 xl:text-sm text-gray-400 dark:text-dark-muted font-mono">
              <span class="xl:hidden">Imóvel </span>{{ lead.metadata?.propertyCode || 'N/A' }}
            </td>

             <!-- Modo -->
            <td class="col-start-3 row-start-3 xl:px-6 xl:py-4 text-sm">
               <span v-if="!lead.agent_active" class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-sm text-xs font-medium bg-amber-50 dark:bg-amber-500/10 text-amber-600 dark:text-amber-500">
                  <Lock class="w-3 h-3" /> Desativado
               </span>
               <span v-else class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-sm text-xs font-medium bg-primary-50 dark:bg-primary-500/10 text-primary-600 dark:text-primary-400">
                  <Bot class="w-3 h-3" /> Ativado
               </span>
            </td>

            <!-- Ações -->
            <td class="col-start-3 row-span-2 row-start-1 text-right xl:px-6 xl:py-4">
               <div class="flex items-center justify-end gap-0 xl:gap-1 xl:opacity-60 group-hover:opacity-100 transition-opacity">
                 <button 
                   @click="emit('open-chat', lead.id)"
                   class="inline-flex h-11 w-11 items-center justify-center xl:h-8 xl:w-8 text-gray-500 hover:text-primary-500 hover:bg-primary-50 dark:hover:bg-primary-500/10 rounded-sm transition-all"
                   aria-label="Abrir conversa"
                 >
                   <MessageCircle class="w-4 h-4" />
                 </button>
                 <button 
                   @click="emit('view-details', lead)"
                   class="inline-flex h-11 w-11 items-center justify-center xl:h-8 xl:w-8 text-gray-500 hover:text-primary-500 hover:bg-primary-50 dark:hover:bg-primary-500/10 rounded-sm transition-all"
                   aria-label="Ver detalhes"
                 >
                   <Eye class="w-4 h-4" />
                 </button>
               </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    <CrmPagination :page="page" :page-size="pageSize" :total="total" :loading="loading" label="leads" @change="emit('change-page', $event)" />
  </div>
</template>
