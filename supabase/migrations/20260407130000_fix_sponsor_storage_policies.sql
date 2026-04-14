-- ============================================================================
-- Fix: Sponsor Assets storage policies
-- The existing INSERT policy uses auth.role() = 'authenticated' which is
-- too broad (any user) and still fails in some configurations.
-- Replace with admin-only full access (INSERT, UPDATE, DELETE) matching the
-- pattern used for events-images.
-- ============================================================================

-- Drop the old restrictive INSERT-only policy
DROP POLICY IF EXISTS "Sponsor Assets Admin Upload" ON "storage"."objects";

-- Admin full access: INSERT, UPDATE, DELETE
CREATE POLICY "Sponsor Assets Admin Full Access"
ON "storage"."objects"
AS permissive
FOR ALL
TO public
USING (
    bucket_id = 'sponsor-assets'
    AND EXISTS (
        SELECT 1 FROM public.profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role = 'admin'
    )
)
WITH CHECK (
    bucket_id = 'sponsor-assets'
    AND EXISTS (
        SELECT 1 FROM public.profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role = 'admin'
    )
);

-- Keep public read (already exists, but ensure it's there)
-- DROP + recreate to be idempotent
DROP POLICY IF EXISTS "Sponsor Assets Public Read" ON "storage"."objects";

CREATE POLICY "Sponsor Assets Public Read"
ON "storage"."objects"
AS permissive
FOR SELECT
TO public
USING (bucket_id = 'sponsor-assets');
