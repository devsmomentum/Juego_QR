-- ============================================================================
-- Migration: Event sponsor selection mode
-- Adds a selective flag and updates sponsor pool RPC to support:
-- - No sponsors
-- - All active sponsors
-- - Only selected sponsors
-- ============================================================================

ALTER TABLE "public"."events"
    ADD COLUMN IF NOT EXISTS "sponsors_selective" boolean DEFAULT false;

-- Preserve legacy behavior: events that already have sponsor rows default to selective
UPDATE "public"."events" e
SET "sponsors_selective" = true
WHERE e."sponsors_enabled" = true
  AND EXISTS (
    SELECT 1
    FROM "public"."event_sponsors" es
    WHERE es."event_id" = e."id"
  );

-- RPC: Get sponsor pool for an event (supports all vs selected)
CREATE OR REPLACE FUNCTION public.get_event_sponsor_pool(p_event_id uuid)
RETURNS TABLE (
    id uuid,
    name text,
    plan_type text,
    logo_url text,
    banner_url text,
    target_url text,
    minigame_asset_url text,
    is_active boolean,
    weight integer
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sponsors_enabled boolean;
    v_sponsors_selective boolean;
BEGIN
    SELECT e."sponsors_enabled", e."sponsors_selective"
    INTO v_sponsors_enabled, v_sponsors_selective
    FROM public.events e
    WHERE e.id = p_event_id;

    IF v_sponsors_enabled IS DISTINCT FROM true THEN
        RETURN;
    END IF;

    IF v_sponsors_selective THEN
        RETURN QUERY
        SELECT
            s.id,
            s.name,
            s.plan_type,
            s.logo_url,
            s.banner_url,
            s.target_url,
            s.minigame_asset_url,
            s.is_active,
            CASE s.plan_type
                WHEN 'oro'    THEN 5
                WHEN 'plata'  THEN 3
                WHEN 'bronce' THEN 1
                ELSE 1
            END AS weight
        FROM public.sponsors s
        INNER JOIN public.event_sponsors es ON es.sponsor_id = s.id
        WHERE es.event_id = p_event_id
          AND es.is_active = true
          AND s.is_active = true;
    ELSE
        RETURN QUERY
        SELECT
            s.id,
            s.name,
            s.plan_type,
            s.logo_url,
            s.banner_url,
            s.target_url,
            s.minigame_asset_url,
            s.is_active,
            CASE s.plan_type
                WHEN 'oro'    THEN 5
                WHEN 'plata'  THEN 3
                WHEN 'bronce' THEN 1
                ELSE 1
            END AS weight
        FROM public.sponsors s
        WHERE s.is_active = true;
    END IF;
END;
$$;
