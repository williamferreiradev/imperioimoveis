export interface WeeklyReportRow {
  semana_inicio: string
  semana_fim: string
  total_leads: number
  leads_novos_parados: number
  qualificados: number
  agendamentos: number
  convertidos: number
  taxa_conversao: number
  receita: number
}

const dateLabel = new Intl.DateTimeFormat('pt-BR', { day: '2-digit', month: 'short', timeZone: 'UTC' })
export const formatWeek = (start: string, end: string) =>
  dateLabel.format(new Date(start + 'T12:00:00Z')) + ' – ' + dateLabel.format(new Date(end + 'T12:00:00Z'))
export const formatReportCurrency = (value: number) =>
  new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(value)

export function summarizeWeek(row: WeeklyReportRow) {
  const destaques = []
  if (row.qualificados) destaques.push(row.qualificados + ' leads desta semana estão em negociação, visita ou fechamento.')
  if (row.convertidos) destaques.push(row.convertidos + ' leads desta semana estão na etapa Venda Fechada.')
  if (row.agendamentos) destaques.push(row.agendamentos + ' agendamentos criados na semana que seguem sem cancelamento.')
  return {
    title: 'Semana ' + formatWeek(row.semana_inicio, row.semana_fim),
    resumo: row.total_leads
      ? 'Foram cadastrados ' + row.total_leads + ' leads nesta semana. Qualificação, fechamento e valor previsto refletem a etapa atual desses leads.'
      : 'Nenhum lead foi cadastrado nesta semana.',
    destaques,
    conselhos: [],
    alertas: [],
  }
}
