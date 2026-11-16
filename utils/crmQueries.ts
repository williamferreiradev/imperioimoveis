export const leadPageColumns = 'id,name,phone,stage,stage_id,agent_active,created_at'
export const qualifiedStages = ['negociacao', 'agendamento', 'visita', 'fechado']

// PostgREST logical filters use quotes for punctuation and escapes inside quoted values.
export function searchLeadColumns(term: string, columns = ['name', 'phone']) {
  const pattern = term.trim().replace(/[\\%_*"]/g, (char) => '\\' + char)
  return columns.map(column => `${column}.ilike."%${pattern}%"`).join(',')
}

export function saoPauloDate(date = new Date()) {
  const values = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'America/Sao_Paulo', year: 'numeric', month: '2-digit', day: '2-digit',
  }).formatToParts(date)
  const part = (type: string) => values.find(value => value.type === type)?.value
  return `${part('year')}-${part('month')}-${part('day')}`
}

export function addCalendarDays(date: string, amount: number) {
  const day = new Date(`${date}T12:00:00Z`)
  day.setUTCDate(day.getUTCDate() + amount)
  return day.toISOString().slice(0, 10)
}

export function startOfSaoPauloDay(date: string) {
  return `${date}T00:00:00-03:00`
}

export function currentWeekStart() {
  const date = saoPauloDate()
  const weekday = new Date(`${date}T12:00:00Z`).getUTCDay()
  return addCalendarDays(date, -((weekday + 6) % 7))
}

export function isLeadId(value: string) {
  return /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(value)
}
