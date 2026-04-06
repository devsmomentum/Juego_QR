-- Migration: Add invoice_url to clover_orders
-- Adds a field to store the PDF link of the Stripe invoice for each transaction.

ALTER TABLE public.clover_orders
ADD COLUMN IF NOT EXISTS invoice_url TEXT;

COMMENT ON COLUMN public.clover_orders.invoice_url IS 'URL del PDF de la factura generada por Stripe';
