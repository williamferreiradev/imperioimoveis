BEGIN;

CREATE OR REPLACE FUNCTION public.crm_chat_content_text(payload jsonb, depth integer DEFAULT 0)
RETURNS text
LANGUAGE plpgsql STABLE STRICT
SET search_path = pg_catalog
AS $function$
DECLARE
  body text;
  extracted text[];
BEGIN
  IF depth > 8 THEN
    RETURN NULL;
  END IF;

  CASE jsonb_typeof(payload)
    WHEN 'string' THEN
      body := NULLIF(btrim(payload #>> '{}', E' \t\r\n'), '');
      IF left(body, 3) = repeat(chr(96), 3) AND right(body, 3) = repeat(chr(96), 3) THEN
        body := btrim(regexp_replace(left(body, -3), '^' || repeat(chr(96), 3) || '(json)?[[:space:]]*', '', 'i'), E' \t\r\n');
      END IF;
      IF left(body, 1) IN ('{', '[') THEN
        IF pg_input_is_valid(body, 'jsonb') THEN
          RETURN public.crm_chat_content_text(body::jsonb, depth + 1);
        END IF;
        -- Recover complete text fields even if the surrounding envelope is malformed.
        IF body ~ '^\{\s*"(type|content|output|text)"\s*:' THEN
          extracted := regexp_match(body, $pattern$"(?:content|text)"\s*:\s*("(?:[^"\\]|\\.)*")$pattern$);
          IF pg_input_is_valid(extracted[1], 'jsonb') THEN
            RETURN public.crm_chat_content_text(extracted[1]::jsonb, depth + 1);
          END IF;
          RETURN NULL;
        END IF;
      END IF;
      RETURN body;
    WHEN 'array' THEN
      SELECT string_agg(public.crm_chat_content_text(value, depth + 1), E'\n' ORDER BY position)
      INTO body
      FROM jsonb_array_elements(payload) WITH ORDINALITY AS parts(value, position);
      RETURN body;
    WHEN 'object' THEN
      RETURN COALESCE(
        public.crm_chat_content_text(payload -> 'output', depth + 1),
        public.crm_chat_content_text(payload -> 'content', depth + 1),
        public.crm_chat_content_text(payload -> 'text', depth + 1),
        public.crm_chat_content_text(payload -> 'contentText', depth + 1),
        public.crm_chat_content_text(payload -> 'data', depth + 1),
        public.crm_chat_content_text(payload -> 'buttonsMessage', depth + 1),
        public.crm_chat_content_text(payload -> 'hydratedTemplate', depth + 1),
        public.crm_chat_content_text(payload -> 'hydratedContentText', depth + 1)
      );
    ELSE RETURN NULL;
  END CASE;
END;
$function$;

CREATE OR REPLACE FUNCTION public.crm_chat_message(payload jsonb)
RETURNS TABLE (sender text, body text)
LANGUAGE plpgsql STABLE STRICT
ROWS 1
SET search_path = pg_catalog
AS $function$
DECLARE
  entry jsonb := payload;
  message_type text;
  tool_calls jsonb;
  tool_name text;
BEGIN
  IF jsonb_typeof(payload) = 'string' AND pg_input_is_valid(payload #>> '{}', 'jsonb') THEN
    entry := (payload #>> '{}')::jsonb;
  END IF;

  message_type := lower(COALESCE(entry ->> 'type', entry #>> '{data,type}',
    entry #>> '{kwargs,type}', entry -> 'id' ->> -1, 'human'));
  sender := CASE
    WHEN message_type IN ('ai', 'assistant', 'aimessage', 'aimessagechunk') THEN 'assistant'
    WHEN message_type IN ('system', 'systemmessage', 'tool', 'toolmessage', 'function', 'functionmessage') THEN 'system'
    ELSE 'contact'
  END;

  IF message_type IN ('tool', 'toolmessage', 'function', 'functionmessage') THEN
    tool_name := COALESCE(entry ->> 'name', entry #>> '{data,name}', entry #>> '{kwargs,name}');
    body := COALESCE('Executou ' || replace(NULLIF(tool_name, ''), '_', ' '), 'Executou uma ferramenta');
    RETURN NEXT;
    RETURN;
  END IF;

  body := public.crm_chat_content_text(COALESCE(entry -> 'kwargs', entry));
  IF sender = 'assistant' THEN
    IF body LIKE 'Calling %with input:%' THEN
      tool_name := split_part(split_part(body, ' with input:', 1), 'Calling ', 2);
      body := NULL;
    END IF;
    IF body IS NULL AND tool_name IS NULL THEN
      tool_calls := COALESCE(entry -> 'tool_calls', entry #> '{data,tool_calls}',
        entry #> '{kwargs,tool_calls}', entry #> '{additional_kwargs,tool_calls}');
      IF jsonb_typeof(tool_calls) = 'array' THEN
        SELECT string_agg(COALESCE(value #>> '{function,name}', value ->> 'name', 'ferramenta'), ', ' ORDER BY position)
        INTO tool_name
        FROM jsonb_array_elements(tool_calls) WITH ORDINALITY AS calls(value, position);
      END IF;
    END IF;
    IF body IS NULL AND tool_name IS NOT NULL THEN
      sender := 'system';
      body := 'Chamou ' || replace(tool_name, '_', ' ');
    END IF;
  END IF;
  RETURN NEXT;
END;
$function$;

CREATE OR REPLACE VIEW public.crm_chat_messages
WITH (security_invoker = true) AS
SELECT h.id, h.session_id, visible.sender, visible.body
FROM public.n8n_chat_histories h
CROSS JOIN LATERAL public.crm_chat_message(h.message) visible;

CREATE OR REPLACE VIEW public.crm_chat_directory
WITH (security_invoker = true) AS
SELECT l.id, l.name, l.phone, l.stage, l.stage_id, l.agent_active, l.created_at,
       latest.id AS last_message_id, left(latest.body, 180) AS preview,
       latest.sender = 'assistant' AS from_agent
FROM public.leads l
LEFT JOIN LATERAL (
  SELECT m.id, m.body, m.sender
  FROM public.crm_chat_messages m
  WHERE m.session_id = l.id::text AND m.sender IN ('contact', 'assistant') AND m.body IS NOT NULL
  ORDER BY m.id DESC LIMIT 1
) latest ON true;

REVOKE ALL ON FUNCTION public.crm_chat_content_text(jsonb, integer), public.crm_chat_message(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.crm_chat_content_text(jsonb, integer), public.crm_chat_message(jsonb) TO authenticated, service_role;
REVOKE ALL ON public.crm_chat_messages FROM PUBLIC, anon;
GRANT SELECT ON public.crm_chat_messages TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';
COMMIT;
