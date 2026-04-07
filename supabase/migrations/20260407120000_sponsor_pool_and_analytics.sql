-- ============================================================================
-- Migration: Sponsor Pool System & Analytics
-- Description: Migrates from 1:1 event-sponsor to N:M pool with weighted
--              rotation and adds impression/click tracking.
-- ============================================================================

-- 1. Table: event_sponsors (many-to-many between events and sponsors)
CREATE TABLE IF NOT EXISTS "public"."event_sponsors" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "event_id" uuid NOT NULL,
    "sponsor_id" uuid NOT NULL,
    "priority" integer DEFAULT 0,
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT now(),
    CONSTRAINT "event_sponsors_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "event_sponsors_event_id_fkey" FOREIGN KEY ("event_id")
        REFERENCES "public"."events"("id") ON DELETE CASCADE,
    CONSTRAINT "event_sponsors_sponsor_id_fkey" FOREIGN KEY ("sponsor_id")
        REFERENCES "public"."sponsors"("id") ON DELETE CASCADE,
    CONSTRAINT "event_sponsors_unique" UNIQUE ("event_id", "sponsor_id")
);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS "idx_event_sponsors_event_id"
    ON "public"."event_sponsors" ("event_id");
CREATE INDEX IF NOT EXISTS "idx_event_sponsors_sponsor_id"
    ON "public"."event_sponsors" ("sponsor_id");

-- 2. Table: sponsor_analytics (impression & click tracking)
CREATE TABLE IF NOT EXISTS "public"."sponsor_analytics" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "event_id" uuid,
    "sponsor_id" uuid NOT NULL,
    "user_id" uuid,
    "type" text NOT NULL,
    "context" text,
    "created_at" timestamp with time zone DEFAULT now(),
    CONSTRAINT "sponsor_analytics_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "sponsor_analytics_sponsor_id_fkey" FOREIGN KEY ("sponsor_id")
        REFERENCES "public"."sponsors"("id") ON DELETE CASCADE,
    CONSTRAINT "sponsor_analytics_event_id_fkey" FOREIGN KEY ("event_id")
        REFERENCES "public"."events"("id") ON DELETE SET NULL,
    CONSTRAINT "sponsor_analytics_user_id_fkey" FOREIGN KEY ("user_id")
        REFERENCES "auth"."users"("id") ON DELETE SET NULL,
    CONSTRAINT "sponsor_analytics_type_check" CHECK ("type" IN ('impression', 'click'))
);

-- Indexes for analytics queries
CREATE INDEX IF NOT EXISTS "idx_sponsor_analytics_sponsor_id"
    ON "public"."sponsor_analytics" ("sponsor_id");
CREATE INDEX IF NOT EXISTS "idx_sponsor_analytics_event_id"
    ON "public"."sponsor_analytics" ("event_id");
CREATE INDEX IF NOT EXISTS "idx_sponsor_analytics_type"
    ON "public"."sponsor_analytics" ("type");
CREATE INDEX IF NOT EXISTS "idx_sponsor_analytics_created_at"
    ON "public"."sponsor_analytics" ("created_at");

-- 3. Add target_url to sponsors table
ALTER TABLE "public"."sponsors"
    ADD COLUMN IF NOT EXISTS "target_url" text;

-- 4. RLS Policies for event_sponsors
ALTER TABLE "public"."event_sponsors" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read active event sponsors"
    ON "public"."event_sponsors"
    FOR SELECT
    USING (true);

CREATE POLICY "Admins can manage event sponsors"
    ON "public"."event_sponsors"
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM "public"."profiles"
            WHERE "profiles"."id" = auth.uid()
            AND "profiles"."role" = 'admin'
        )
    );

-- 5. RLS Policies for sponsor_analytics
ALTER TABLE "public"."sponsor_analytics" ENABLE ROW LEVEL SECURITY;

-- Users can only INSERT their own analytics (no update, no delete)
CREATE POLICY "Users can insert own analytics"
    ON "public"."sponsor_analytics"
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Admins can read all analytics
CREATE POLICY "Admins can read analytics"
    ON "public"."sponsor_analytics"
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM "public"."profiles"
            WHERE "profiles"."id" = auth.uid()
            AND "profiles"."role" = 'admin'
        )
    );

-- 6. RPC: Get sponsor pool for an event (with plan weights)
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
BEGIN
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
END;
$$;

-- 7. RPC: Record a sponsor analytics event (fire-and-forget from client)
CREATE OR REPLACE FUNCTION public.record_sponsor_event(
    p_sponsor_id uuid,
    p_event_id uuid DEFAULT NULL,
    p_type text DEFAULT 'impression',
    p_context text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.sponsor_analytics (sponsor_id, event_id, user_id, type, context)
    VALUES (p_sponsor_id, p_event_id, auth.uid(), p_type, p_context);
END;
$$;

-- 8. Migrate existing sponsor_id from events into event_sponsors
-- This preserves the current 1:1 relationships as pool entries
INSERT INTO public.event_sponsors (event_id, sponsor_id, is_active)
SELECT id, sponsor_id, true
FROM public.events
WHERE sponsor_id IS NOT NULL
ON CONFLICT (event_id, sponsor_id) DO NOTHING;

-- Grant execute on new RPCs
GRANT EXECUTE ON FUNCTION public.get_event_sponsor_pool(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_sponsor_event(uuid, uuid, text, text) TO authenticated;
