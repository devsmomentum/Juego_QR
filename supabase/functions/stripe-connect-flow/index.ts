import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@14.25.0?target=deno";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY") ?? "";

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) throw new Error("No authorization header");

    const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user }, error: authError } = await supabaseClient.auth.getUser();
    if (authError || !user) throw new Error("Unauthorized");

    const stripe = new Stripe(stripeSecretKey, {
      apiVersion: "2024-06-20",
      httpClient: Stripe.createFetchHttpClient(),
    });

    const body = await req.json();
    const { action } = body;

    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

    // Default redirect URLs for the app
    const refreshUrl = "io.supabase.maphunter://stripe-onboarding-refresh";
    const returnUrl = "io.supabase.maphunter://stripe-onboarding-return";

    if (action === "create_account") {
      // Check if user already has an account id
      const { data: profile } = await supabaseAdmin
        .from("profiles")
        .select("stripe_connect_id")
        .eq("id", user.id)
        .single();

      let accountId = profile?.stripe_connect_id;

      if (!accountId) {
        console.log(`Creating new Stripe Connect Express account for user ${user.id}`);
        const account = await stripe.accounts.create({
          type: "express",
          metadata: { supabase_user_id: user.id },
          capabilities: {
            transfers: { requested: true },
          },
        });
        accountId = account.id;

        const { error: updateError } = await supabaseAdmin
          .from("profiles")
          .update({ stripe_connect_id: accountId })
          .eq("id", user.id);

        if (updateError) throw new Error(`Error updating profile: ${updateError.message}`);
      }

      return new Response(JSON.stringify({ success: true, account_id: accountId }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (action === "create_link") {
      const { data: profile } = await supabaseAdmin
        .from("profiles")
        .select("stripe_connect_id")
        .eq("id", user.id)
        .single();

      if (!profile?.stripe_connect_id) {
        throw new Error("User has no Stripe Connect ID. Call create_account first.");
      }

      console.log(`Generating onboarding link for account ${profile.stripe_connect_id}`);
      const accountLink = await stripe.accountLinks.create({
        account: profile.stripe_connect_id,
        refresh_url: refreshUrl,
        return_url: returnUrl,
        type: "account_onboarding",
      });

      return new Response(JSON.stringify({ success: true, url: accountLink.url }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (action === "get_status") {
      const { data: profile } = await supabaseAdmin
        .from("profiles")
        .select("stripe_connect_id, stripe_onboarding_completed")
        .eq("id", user.id)
        .single();

      if (!profile?.stripe_connect_id) {
        return new Response(JSON.stringify({ success: true, status: "not_started" }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const account = await stripe.accounts.retrieve(profile.stripe_connect_id);
      
      // An account is ready if details are submitted and it's enabled for payouts
      const isReady = account.details_submitted && account.payouts_enabled;

      if (isReady !== profile.stripe_onboarding_completed) {
        await supabaseAdmin
          .from("profiles")
          .update({ stripe_onboarding_completed: isReady })
          .eq("id", user.id);
      }

      return new Response(JSON.stringify({
        success: true,
        status: isReady ? "completed" : "pending",
        details_submitted: account.details_submitted,
        payouts_enabled: account.payouts_enabled,
        requirements: account.requirements,
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    throw new Error(`Unsupported action: ${action}`);

  } catch (error) {
    console.error(`[stripe-connect-flow] Error: ${error.message}`);
    return new Response(JSON.stringify({ error: error.message, success: false }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});
