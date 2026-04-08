BEGIN;

DROP POLICY IF EXISTS "Solo admins pueden actualizar game_players" ON public.game_players;
CREATE POLICY "Solo admins pueden actualizar game_players"
  ON public.game_players
  FOR UPDATE
  TO public
  USING (public.is_admin(auth.uid()))
  WITH CHECK (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Enable read access for event participants" ON public.game_players;
CREATE POLICY "Enable read access for event participants"
  ON public.game_players
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING (
    (event_id IN (SELECT public.get_my_event_ids() AS get_my_event_ids))
    OR public.is_admin(auth.uid())
  );

COMMIT;
