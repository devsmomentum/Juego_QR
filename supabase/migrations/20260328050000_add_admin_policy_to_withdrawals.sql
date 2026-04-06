-- Add Admin Policy to withdrawal_requests
-- Allows Admins and Staff to view and manage all withdrawal requests

-- 1. Policy for Admins to SELECT all requests
DROP POLICY IF EXISTS withdrawal_requests_admin_select ON public.withdrawal_requests;
CREATE POLICY withdrawal_requests_admin_select
  ON public.withdrawal_requests
  FOR SELECT
  USING (public.is_admin_or_staff(auth.uid()));

-- 2. Policy for Admins to UPDATE requests (to confirm/reject)
DROP POLICY IF EXISTS withdrawal_requests_admin_update ON public.withdrawal_requests;
CREATE POLICY withdrawal_requests_admin_update
  ON public.withdrawal_requests
  FOR UPDATE
  USING (public.is_admin_or_staff(auth.uid()))
  WITH CHECK (public.is_admin_or_staff(auth.uid()));
