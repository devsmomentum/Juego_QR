-- Migration: Expose pago_pago_order_id, gateway and fiat_amount_ves in user_activity_feed
-- So Flutter can identify pago_movil orders, open the validation widget,
-- and display the correct VES amount.

DROP VIEW IF EXISTS "public"."user_activity_feed";

CREATE VIEW "public"."user_activity_feed" AS
 SELECT (wl.id)::text AS id,
    wl.user_id,
    (wl.amount)::integer AS clover_quantity,
    COALESCE(tp.price, co_fk.amount, co_meta.amount, ((wl.metadata ->> 'amount_usd'::text))::numeric, ((wl.metadata ->> 'price_usd'::text))::numeric, (0)::numeric) AS fiat_amount,
    NULL::numeric AS fiat_amount_ves,
        CASE
            WHEN (wl.amount >= (0)::numeric) THEN 'deposit'::text
            ELSE 'withdrawal'::text
        END AS type,
    'completed'::text AS status,
    wl.created_at,
    COALESCE(wl.description,
        CASE
            WHEN (wl.amount >= (0)::numeric) THEN 'Recarga'::text
            ELSE 'Retiro'::text
        END) AS description,
    NULL::text AS payment_url,
    NULL::text AS pago_pago_order_id,
    NULL::text AS gateway
   FROM (((public.wallet_ledger wl
     LEFT JOIN public.transaction_plans tp ON (((wl.metadata ->> 'plan_id'::text) IS NOT NULL) AND (((wl.metadata ->> 'plan_id'::text))::uuid = tp.id)))
     LEFT JOIN public.clover_orders co_fk ON (wl.order_id = co_fk.id))
     LEFT JOIN public.clover_orders co_meta ON (((wl.metadata ->> 'order_id'::text) IS NOT NULL) AND (((wl.metadata ->> 'order_id'::text) = co_meta.pago_pago_order_id) OR ((wl.metadata ->> 'order_id'::text) = (co_meta.id)::text))))
UNION ALL
 SELECT (co.id)::text AS id,
    co.user_id,
    COALESCE(tp.amount, ((co.extra_data ->> 'clovers_amount'::text))::integer, ((co.extra_data ->> 'clovers_quantity'::text))::integer, 0) AS clover_quantity,
    COALESCE(tp.price, ((co.extra_data ->> 'price_usd'::text))::numeric, ((co.extra_data ->> 'amount_usd'::text))::numeric, co.amount) AS fiat_amount,
    ((co.extra_data ->> 'amount_ves_total'::text))::numeric AS fiat_amount_ves,
    'deposit'::text AS type,
    co.status,
    co.created_at,
    'Compra de Tréboles'::text AS description,
    co.payment_url,
    co.pago_pago_order_id,
    co.gateway
   FROM (public.clover_orders co
     LEFT JOIN public.transaction_plans tp ON ((co.plan_id = tp.id)))
  WHERE (co.status <> ALL (ARRAY['success'::text, 'paid'::text]));
