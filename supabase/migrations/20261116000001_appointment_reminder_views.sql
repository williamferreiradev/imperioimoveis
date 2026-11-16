BEGIN;

CREATE OR REPLACE VIEW public.vw_lembretes_1_dia
WITH (security_invoker = true) AS
SELECT a.id, l.phone, l.name, a.appointment_date, a.start_time, a.about
FROM public.appointments a
JOIN public.leads l ON l.id = a.lead_id
WHERE a.status = 'agendado'
  AND a.lembrete_1dia_enviado = false
  AND (a.appointment_date || ' ' || a.start_time)::timestamp
    <= (now() AT TIME ZONE 'America/Sao_Paulo') + interval '24 hours'
  AND (a.appointment_date || ' ' || a.start_time)::timestamp
    > (now() AT TIME ZONE 'America/Sao_Paulo') + interval '2 hours';

CREATE OR REPLACE VIEW public.vw_lembretes_2_horas
WITH (security_invoker = true) AS
SELECT a.id, l.phone, l.name, a.appointment_date, a.start_time, a.about
FROM public.appointments a
JOIN public.leads l ON l.id = a.lead_id
WHERE a.status = 'agendado'
  AND a.lembrete_2horas_enviado = false
  AND (a.appointment_date || ' ' || a.start_time)::timestamp
    <= (now() AT TIME ZONE 'America/Sao_Paulo') + interval '2 hours'
  AND (a.appointment_date || ' ' || a.start_time)::timestamp
    > (now() AT TIME ZONE 'America/Sao_Paulo');

REVOKE ALL ON public.vw_lembretes_1_dia, public.vw_lembretes_2_horas
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.vw_lembretes_1_dia, public.vw_lembretes_2_horas TO service_role;

NOTIFY pgrst, 'reload schema';
COMMIT;
