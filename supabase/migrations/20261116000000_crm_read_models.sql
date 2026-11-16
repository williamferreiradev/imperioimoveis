BEGIN;

CREATE INDEX IF NOT EXISTS leads_created_at_id_idx
  ON public.leads (created_at DESC NULLS LAST, id DESC);
CREATE INDEX IF NOT EXISTS chat_histories_session_id_id_idx
  ON public.n8n_chat_histories (session_id, id DESC);

CREATE OR REPLACE VIEW public.crm_pipeline_leads
WITH (security_invoker = true) AS
SELECT l.id, l.name, l.phone, l.stage, l.stage_id, l.agent_active,
       l.created_at, COALESCE(l.created_at, '-infinity'::timestamptz) AS sort_at,
       COALESCE(s.estagio::text, fallback.estagio::text, 'novo') AS stage_key
FROM public.leads l
LEFT JOIN public.stage s ON s.id = l.stage_id
LEFT JOIN LATERAL (
  SELECT st.estagio
  FROM public.stage st
  WHERE st.estagio::text = CASE WHEN l.stage::text = 'agendamento' THEN 'visita' ELSE l.stage::text END
  ORDER BY st.id LIMIT 1
) fallback ON s.id IS NULL;

CREATE OR REPLACE VIEW public.crm_chat_directory
WITH (security_invoker = true) AS
SELECT l.id, l.name, l.phone, l.stage, l.stage_id, l.agent_active, l.created_at,
       latest.id AS last_message_id,
       CASE WHEN latest.message IS NOT NULL THEN LEFT(COALESCE(
         latest.message #>> '{data,output,content}', latest.message #>> '{output,content}',
         latest.message #>> '{data,content}', latest.message ->> 'content',
         latest.message #>> '{data,text}', latest.message ->> 'text', 'Mensagem'
       ), 180) END AS preview,
       COALESCE(latest.message ->> 'type', latest.message #>> '{data,type}') IN ('ai','assistant') AS from_agent
FROM public.leads l
LEFT JOIN LATERAL (
  SELECT h.id, h.message FROM public.n8n_chat_histories h
  WHERE h.session_id = l.id::text
  ORDER BY h.id DESC LIMIT 1
) latest ON true;

CREATE OR REPLACE VIEW public.crm_weekly_report
WITH (security_invoker = true) AS
WITH grouped_leads AS (
  SELECT date_trunc('week', l.created_at AT TIME ZONE 'America/Sao_Paulo')::date AS week,
         count(*) AS total_leads,
         count(*) FILTER (WHERE p.stage_key = 'novo') AS leads_novos_parados,
         count(*) FILTER (WHERE p.stage_key IN ('negociacao','visita','fechado')) AS qualificados,
         count(*) FILTER (WHERE p.stage_key = 'fechado') AS convertidos,
         COALESCE(sum(l.expected_value) FILTER (WHERE p.stage_key = 'fechado'), 0) AS receita
  FROM public.leads l
  JOIN public.crm_pipeline_leads p ON p.id = l.id
  WHERE l.created_at <= now()
  GROUP BY 1
), grouped_appointments AS (
  SELECT date_trunc('week', created_at AT TIME ZONE 'America/Sao_Paulo')::date AS week,
         count(*) AS agendamentos
  FROM public.appointments
  WHERE created_at <= now() AND status <> 'cancelado'
  GROUP BY 1
), weeks AS (
  SELECT week FROM grouped_leads UNION SELECT week FROM grouped_appointments
  UNION SELECT date_trunc('week', now() AT TIME ZONE 'America/Sao_Paulo')::date
)
SELECT w.week AS semana_inicio, w.week + 6 AS semana_fim,
       COALESCE(l.total_leads, 0) AS total_leads,
       COALESCE(l.leads_novos_parados, 0) AS leads_novos_parados,
       COALESCE(l.qualificados, 0) AS qualificados,
       COALESCE(a.agendamentos, 0) AS agendamentos,
       COALESCE(l.convertidos, 0) AS convertidos,
       COALESCE(round(100.0 * l.convertidos / NULLIF(l.total_leads, 0), 1), 0) AS taxa_conversao,
       COALESCE(l.receita, 0) AS receita
FROM weeks w
LEFT JOIN grouped_leads l USING (week)
LEFT JOIN grouped_appointments a USING (week);

CREATE OR REPLACE VIEW public.crm_report_activity
WITH (security_invoker = true) AS
SELECT 'lead-' || id AS id, created_at, 'lead_new' AS type,
       'Novo lead recebido: ' || COALESCE(name, 'Sem nome') AS text
FROM public.leads WHERE created_at <= now()
UNION ALL
SELECT 'appointment-' || a.id, a.created_at, 'meeting_scheduled',
       'Agendamento registrado: ' || COALESCE(l.name, 'Cliente')
FROM public.appointments a LEFT JOIN public.leads l ON l.id = a.lead_id
WHERE a.created_at <= now();

REVOKE ALL ON public.crm_pipeline_leads, public.crm_chat_directory,
  public.crm_weekly_report, public.crm_report_activity FROM PUBLIC, anon;
GRANT SELECT ON public.crm_pipeline_leads, public.crm_chat_directory,
  public.crm_weekly_report, public.crm_report_activity TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';
COMMIT;
