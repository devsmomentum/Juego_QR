import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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
    // Initialize Supabase client
    // We use the ANON key because these are public endpoints (login/register)
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    );

    const url = new URL(req.url);
    const path = url.pathname.split("/").pop();

    // --- LOGIN ---
    if (path === "login") {
      const { email, password } = await req.json();

      if (!email || !password) {
        throw new Error("Email and password are required");
      }

      const { data, error: loginError } = await supabaseClient.auth.signInWithPassword({
        email,
        password,
      });

      if (loginError) {
        const isUnconfirmed = loginError.message.toLowerCase().includes("confirm") || 
                            loginError.message.toLowerCase().includes("verified");
        
        return new Response(
          JSON.stringify({ 
            error: loginError.message, 
            unverified: isUnconfirmed 
          }),
          {
            status: isUnconfirmed ? 403 : 401,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      // Check if email is confirmed (Login Guard - Server Side, for when Confirm Email is OFF but we want to enforce it via metadata)
      if (
        data?.user?.email_confirmed_at === null ||
        data?.user?.email_confirmed_at === undefined
      ) {
        // Sign out so the session token is invalidated
        await supabaseClient.auth.signOut();
        return new Response(
          JSON.stringify({
            error:
              "Tu cuenta aún no está activa. Por favor, verifica tu correo electrónico.",
            unverified: true,
          }),
          {
            status: 403,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
      }

      // Check if user is banned
      if (data?.user?.id) {
        let profile = null;
        try {
          const { data: fetchedProfile, error: profileError } = await supabaseClient
            .from("profiles")
            .select("status")
            .eq("id", data.user.id)
            .single();

          if (profileError) {
            console.error("Error checking profile status:", profileError);
          }
          profile = fetchedProfile;
        } catch (error: any) {
          console.error("Critical error in edge function:", error);
        }

        if (profile && profile.status === "banned") {
          await supabaseClient.auth.signOut();
          throw new Error("Tu cuenta ha sido suspendida permanentemente.");
        }
      }

      return new Response(JSON.stringify(data), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // --- REGISTER ---
    if (path === "register") {
      const { email, password, name, cedula, phone } = await req.json();

      if (!email || !password || !name) {
        throw new Error("Email, password and name are required");
      }

      if (!name.trim().includes(" ")) {
        throw new Error("Ingresa Nombre y Apellido");
      }

      // Server-side: cedula and phone are REQUIRED
      if (!cedula || !phone) {
        return new Response(
          JSON.stringify({ error: "Cédula y teléfono son obligatorios" }),
          {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
      }

      // Server-side email format validation
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
      if (!emailRegex.test(email)) {
        return new Response(
          JSON.stringify({ error: "Formato de email inválido" }),
          {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
      }

      // Server-side password length validation
      if (password.length < 6) {
        return new Response(
          JSON.stringify({
            error: "La contraseña debe tener al menos 6 caracteres",
          }),
          {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
      }

      // Sanitize inputs removing non-alphanumeric characters (dots, spaces, hyphens, parentheses)
      const sanitize = (val: string) => val.replace(/[.\s\-()]/g, "").trim();
      let sanitizedPhone = sanitize(phone || "");
      const sanitizedCedula = sanitize(cedula || "").toUpperCase();

      // VALIDATIONS
      const cedulaRegex = /^[A-Z0-9]{5,20}$/i; // Más flexible para internacional
      if (sanitizedCedula) {
        if (!cedulaRegex.test(sanitizedCedula)) {
          throw new Error(
            "Formato de identificación inválido. Debe tener entre 5 y 20 caracteres alfanuméricos.",
          );
        }
      }

      // Validar formato de teléfono E.164: +[código país][número local]
      if (sanitizedPhone) {
        // E.164: "+" seguido de 7 a 15 dígitos
        const e164Regex = /^\+\d{7,15}$/;
        // Legacy venezolano: 04XX + 7 dígitos
        const legacyVERegex = /^04(12|14|24|16|26|22)\d{7}$/;

        if (e164Regex.test(sanitizedPhone)) {
          // Ya viene en E.164 — se usa tal cual
        } else if (legacyVERegex.test(sanitizedPhone)) {
          // Convertir formato legacy venezolano a E.164: 04121234567 → +584121234567
          sanitizedPhone = "+58" + sanitizedPhone.substring(1);
        } else {
          throw new Error(
            "Formato de teléfono inválido. Usa formato internacional (+584121234567) o local (04121234567)",
          );
        }
      }

      // ── PRE-FLIGHT AUTH CHECK ──────────────────────────────────────
      const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
      const serviceClient = serviceKey
        ? createClient(Deno.env.get("SUPABASE_URL") ?? "", serviceKey, {
            auth: { persistSession: false },
          })
        : null;

      // Note: We avoid serviceClient.auth.admin.getUserByEmail due to environment issues.
      // We will check for existence in the profiles table first.
      let existingProfile = null;
      if (serviceClient) {
        const { data } = await serviceClient
          .from("profiles")
          .select("id, email")
          .eq("email", email)
          .maybeSingle();
        existingProfile = data;
      }

      // ── PRE-FLIGHT UNIQUENESS CHECKS ────────────────────────────────
      if (serviceClient) {
        if (sanitizedCedula) {
          const query = serviceClient.from("profiles").select("id").eq("dni", sanitizedCedula);
          if (existingProfile) query.neq("id", existingProfile.id);
          const { data: existingCedula } = await query.maybeSingle();

          if (existingCedula) {
            return new Response(
              JSON.stringify({ error: "Esta cédula ya está registrada" }),
              { status: 409, headers: { ...corsHeaders, "Content-Type": "application/json" } },
            );
          }
        }

        if (sanitizedPhone) {
          const query = serviceClient.from("profiles").select("id").eq("phone", sanitizedPhone);
          if (existingProfile) query.neq("id", existingProfile.id);
          const { data: existingPhone } = await query.maybeSingle();

          if (existingPhone) {
            return new Response(
              JSON.stringify({ error: "Este teléfono ya está registrado" }),
              { status: 409, headers: { ...corsHeaders, "Content-Type": "application/json" } },
            );
          }
        }
      }

      // ── HANDLE PENDING VERIFICATION (Smart Resend) ──────────────────
      // If profile exists, we assume user exists in auth.users.
      // We try to resend to check confirmation status and trigger email.
      if (existingProfile) {
        const { error: resendError } = await supabaseClient.auth.resend({
          type: 'signup',
          email: email,
        });

        if (resendError) {
          const resMsg = resendError.message.toLowerCase();
          // If already confirmed, block with error
          if (resMsg.includes("already confirmed") || resMsg.includes("verified")) {
            return new Response(
              JSON.stringify({ error: "Este correo ya está registrado. Intenta iniciar sesión." }),
              { status: 409, headers: { ...corsHeaders, "Content-Type": "application/json" } },
            );
          }
          // If other error (like rate limit), report it
          return new Response(
            JSON.stringify({ error: resendError.message }),
            { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        console.log(`User ${email} exists and is unconfirmed. Updating profile and resent email.`);
        
        if (serviceClient) {
          // Update profile with new data
          await serviceClient.from("profiles").update({
            name,
            dni: sanitizedCedula,
            phone: sanitizedPhone,
          }).eq("id", existingProfile.id);

          // Update auth metadata (defensive check)
          const adminClient = serviceClient?.auth?.admin;
          if (adminClient && typeof adminClient.updateUserById === 'function') {
            await adminClient.updateUserById(existingProfile.id, {
              user_metadata: { name, cedula: sanitizedCedula, phone: sanitizedPhone }
            }).catch(e => console.error("Auth metadata update failed (non-critical):", e));
          }
        }

        return new Response(JSON.stringify({ 
          message: "Se ha reenviado el correo de verificación. Por favor revisa tu bandeja de entrada.",
          user: existingProfile
        }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // ── ATOMIC SIGN-UP ──────────────────────────────────────────────
      // signUp creates the row in auth.users.
      // The DB trigger `handle_new_user` runs INSIDE THE SAME transaction
      // and creates the full profile (with dni, phone, clovers, etc.).
      //
      // If the trigger fails (e.g. duplicate dni/phone constraint), the
      // entire transaction rolls back automatically – NO orphan auth user
      // is ever left behind. No manual retry/rollback logic needed.
      // ────────────────────────────────────────────────────────────────
      let data, error;
      try {
        const signUpResult = await supabaseClient.auth.signUp({
          email,
          password,
          options: {
            data: {
              name,
              cedula: sanitizedCedula,
              phone: sanitizedPhone,
            },
          },
        });
        data = signUpResult.data;
        error = signUpResult.error;
      } catch (signUpError: any) {
        const msg = signUpError?.message ?? "";

        // Duplicate email (race condition between pre-check and signUp)
        if (msg.includes("already registered") || msg.includes("already exists")) {
          return new Response(
            JSON.stringify({ error: "Este correo ya está registrado. Intenta iniciar sesión." }),
            { status: 409, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        // Trigger-originated constraint violations bubble up through signUp
        if (msg.includes("profiles_dni_key") || msg.includes("duplicate key") && msg.includes("dni")) {
          return new Response(
            JSON.stringify({ error: "Esta cédula ya está registrada" }),
            { status: 409, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }
        if (msg.includes("profiles_phone_key") || msg.includes("duplicate key") && msg.includes("phone")) {
          return new Response(
            JSON.stringify({ error: "Este teléfono ya está registrado" }),
            { status: 409, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        // Generic trigger failure fallback
        if (msg.includes("Database error saving new user")) {
          return new Response(
            JSON.stringify({
              error: "No se pudo completar el registro. La cédula o el teléfono ya están en uso por otra cuenta.",
            }),
            { status: 409, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        throw signUpError;
      }

      if (error) {
        const msg = error.message ?? "";

        if (msg.includes("already registered") || msg.includes("already exists") || msg.includes("is invalid")) {
          return new Response(
            JSON.stringify({ error: "Este correo ya está registrado. Intenta iniciar sesión." }),
            { status: 409, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        // Constraint violations from the trigger
        if (msg.includes("profiles_dni_key")) {
          return new Response(
            JSON.stringify({ error: "Esta cédula ya está registrada" }),
            { status: 409, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }
        if (msg.includes("profiles_phone_key")) {
          return new Response(
            JSON.stringify({ error: "Este teléfono ya está registrado" }),
            { status: 409, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        // Generic trigger failure — Supabase Auth wraps constraint violations
        // in "Database error saving new user". The pre-checks above should
        // catch most cases, but this handles race conditions.
        if (msg.includes("Database error saving new user")) {
          return new Response(
            JSON.stringify({
              error: "No se pudo completar el registro. La cédula o el teléfono ya están en uso por otra cuenta.",
            }),
            { status: 409, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }

        throw error;
      }

      // Supabase anti-enumeration: existing user → empty identities array
      if (
        data?.user &&
        (!data.user.identities || data.user.identities.length === 0)
      ) {
        return new Response(
          JSON.stringify({ error: "Este correo ya está registrado. Intenta iniciar sesión." }),
          { status: 409, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      return new Response(JSON.stringify(data), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // --- UPDATE PROFILE ---
    if (path === "update-profile") {
      const { name, phone, email, cedula } = await req.json();

      // Authorization Check
      const authHeader = req.headers.get("Authorization");
      if (!authHeader) {
        throw new Error("Missing Authorization header");
      }

      // Create authenticated client for RLS
      const userSupabase = createClient(
        Deno.env.get("SUPABASE_URL") ?? "",
        Deno.env.get("SUPABASE_ANON_KEY") ?? "",
        {
          global: {
            headers: { Authorization: authHeader },
          },
        },
      );

      const {
        data: { user },
        error: userError,
      } = await userSupabase.auth.getUser();

      if (userError || !user) {
        throw new Error("Invalid or expired session");
      }

      // --- VALIDATIONS (mirror registration rules) ---

      // Banned words for name
      const bannedWords = [
        "admin",
        "root",
        "moderator",
        "tonto",
        "estupido",
        "idiota",
        "groseria",
        "puto",
        "mierda",
      ];

      // Validate name
      if (name !== undefined && name !== null) {
        const trimmedName = String(name).trim();
        if (trimmedName.length === 0) {
          throw new Error("El nombre no puede estar vacío");
        }
        if (trimmedName.length > 50) {
          throw new Error("El nombre no puede exceder 50 caracteres");
        }
        const lowerName = trimmedName.toLowerCase();
        for (const word of bannedWords) {
          if (lowerName.includes(word)) {
            throw new Error("El nombre contiene palabras no permitidas");
          }
        }
      }

      // Validate phone (E.164 international format or legacy Venezuelan)
      let sanitizedPhone: string | undefined = undefined;
      if (phone !== undefined && phone !== null) {
        let phoneValue = String(phone).replace(/[\. \-]/g, "");

        // E.164: "+" seguido de 7 a 15 dígitos
        const e164Regex = /^\+\d{7,15}$/;
        // Legacy venezolano: 04XX + 7 dígitos
        const legacyVERegex = /^04(12|14|24|16|26|22)\d{7}$/;

        if (e164Regex.test(phoneValue)) {
          // Ya viene en E.164 — se usa tal cual
        } else if (legacyVERegex.test(phoneValue)) {
          // Convertir formato legacy venezolano a E.164 (0412...)
          phoneValue = "+58" + phoneValue.substring(1);
        } else if (/^(58)?(412|414|424|416|426|422)\d{7}$/.test(phoneValue)) {
          // Venezuelan number without + but with or without 58 prefix
          if (!phoneValue.startsWith("58")) {
            phoneValue = "+58" + phoneValue;
          } else {
            phoneValue = "+" + phoneValue;
          }
        } else {
          throw new Error(
            "Formato de teléfono inválido. Usa formato internacional (+584121234567) o local (04121234567)",
          );
        }

        // Check uniqueness (excluding current user)
        const { data: existingPhone } = await userSupabase
          .from("profiles")
          .select("id")
          .eq("phone", phoneValue)
          .neq("id", user.id)
          .maybeSingle();

        if (existingPhone) {
          throw new Error("Este teléfono ya está registrado");
        }

        sanitizedPhone = phoneValue;
      }

      // Validate cedula (Venezuelan format)
      let sanitizedCedula: string | undefined = undefined;
      if (cedula !== undefined && cedula !== null) {
        let cleanCedula = String(cedula).replace(/[\.\-\s]/g, "").toUpperCase();
        const cedulaRegex = /^[VE]\d{6,9}$/i;
        if (!cedulaRegex.test(cleanCedula)) {
          throw new Error("Formato de cédula inválido. Usa V12345678 o E12345678");
        }

        // Check uniqueness (excluding current user by joining with auth id)
        const { data: existingCedula } = await userSupabase
          .from("profiles")
          .select("id")
          .eq("dni", cleanCedula)
          .neq("id", user.id)
          .maybeSingle();

        if (existingCedula) {
          throw new Error("Esta cédula ya está registrada");
        }

        sanitizedCedula = cleanCedula;
      }

      // 1. Fetch current profile to check if email is verified
      const { data: currentProfile, error: currentProfileError } = await userSupabase
        .from("profiles")
        .select("email_verified")
        .eq("id", user.id)
        .single();

      if (currentProfileError || !currentProfile) {
        throw new Error("No se pudo cargar el perfil actual");
      }

      const isEmailVerified = currentProfile.email_verified === true;

      // Validate email
      let emailChanged = false;
      if (email !== undefined && email !== null) {
        const trimmedEmail = String(email).trim().toLowerCase();
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
        if (!emailRegex.test(trimmedEmail)) {
          throw new Error("Formato de email inválido");
        }

        // Only process if email actually changed OR if it hasn't been verified yet.
        console.log("Email check:", { trimmedEmail, userEmail: user.email, isEmailVerified });
        if (trimmedEmail !== user.email || !isEmailVerified) {

          const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
          const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

          if (trimmedEmail !== user.email) {
            // --- NEW EMAIL ADDRESS ---
            // Direct call to GoTrue user endpoint with the user's JWT.
            // This triggers the native "Confirm Email Change" email template.
            const response = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
              method: "PUT",
              headers: {
                "Content-Type": "application/json",
                Authorization: authHeader,
                apikey: ANON_KEY,
              },
              body: JSON.stringify({ email: trimmedEmail }),
            });

            const result = await response.json();
            console.log("PUT /auth/v1/user response:", response.status, JSON.stringify(result));

            if (!response.ok) {
              const errMsg = result.msg || result.message || "Error desconocido";
              throw new Error("Error al actualizar el email: " + errMsg);
            }
          } else if (!isEmailVerified) {
            // --- SAME EMAIL, NOT VERIFIED ---
            // Resend the "Confirm Email Change" email
            const response = await fetch(`${SUPABASE_URL}/auth/v1/resend`, {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                apikey: ANON_KEY,
              },
              body: JSON.stringify({ type: "email_change", email: trimmedEmail }),
            });

            if (!response.ok) {
              const result = await response.json();
              console.error("Error resending verification email:", result);
              const errMsg = result.msg || result.message || "Error desconocido";
              throw new Error("Error al reenviar el correo de verificación: " + errMsg);
            }
          }

          // Mark email as unverified in profiles
          await userSupabase
            .from("profiles")
            .update({
              email: trimmedEmail,
              email_verified: false,
            })
            .eq("id", user.id);

          emailChanged = true;
        }
      }

      // Prepare profile table updates (name, phone)
      const profileUpdates: Record<string, unknown> = {};
      if (name !== undefined && name !== null) {
        profileUpdates.name = String(name).trim();
      }
      if (sanitizedPhone !== undefined) {
        profileUpdates.phone = sanitizedPhone;
      }
      if (sanitizedCedula !== undefined) {
        profileUpdates.dni = sanitizedCedula;
      }

      let profileData = null;
      if (Object.keys(profileUpdates).length > 0) {
        const { data, error } = await userSupabase
          .from("profiles")
          .update(profileUpdates)
          .eq("id", user.id)
          .select()
          .single();

        if (error) throw error;
        profileData = data;
      } else if (!emailChanged) {
        throw new Error("No fields to update");
      }

      // If only email changed, fetch profile for response
      if (!profileData) {
        const { data } = await userSupabase
          .from("profiles")
          .select()
          .eq("id", user.id)
          .single();
        profileData = data;
      }

      return new Response(
        JSON.stringify({ ...profileData, emailChanged }),
        {
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        },
      );
    }

    // --- ADD PAYMENT METHOD ---
    if (path === "add-payment-method") {
      const { bank_code } = await req.json();

      // Authorization Check
      const authHeader = req.headers.get("Authorization");
      if (!authHeader) {
        throw new Error("Missing Authorization header");
      }

      // Create authenticated client for RLS
      const userSupabase = createClient(
        Deno.env.get("SUPABASE_URL") ?? "",
        Deno.env.get("SUPABASE_ANON_KEY") ?? "",
        {
          global: {
            headers: { Authorization: authHeader },
          },
        },
      );

      const {
        data: { user },
        error: userError,
      } = await userSupabase.auth.getUser();

      if (userError || !user) {
        throw new Error("Invalid or expired session");
      }

      // 1. Fetch Profile Data (DNI & Phone)
      const { data: profile, error: profileError } = await userSupabase
        .from("profiles")
        .select("dni, phone")
        .eq("id", user.id)
        .single();

      if (profileError || !profile) {
        throw new Error("No se pudo cargar el perfil del usuario.");
      }

      if (!profile.dni || !profile.phone) {
        throw new Error("Perfil incompleto. Falta DNI o Teléfono.");
      }

      // 2. Insert Payment Method
      const { data, error } = await userSupabase
        .from("user_payment_methods")
        .insert({
          user_id: user.id,
          bank_code: bank_code,
          phone_number: profile.phone,
          dni: String(profile.dni),
          is_default: true,
        })
        .select()
        .single();

      if (error) throw error;

      return new Response(JSON.stringify(data), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // --- DELETE ACCOUNT (Self-deletion) ---
    if (path === "delete-account" && req.method === "DELETE") {
      const { password } = await req.json();

      if (!password) {
        throw new Error("Se requiere la contraseña para eliminar la cuenta");
      }

      // Authorization Check
      const authHeader = req.headers.get("Authorization");
      if (!authHeader) {
        throw new Error("Missing Authorization header");
      }

      // Create authenticated client for RLS
      const userSupabase = createClient(
        Deno.env.get("SUPABASE_URL") ?? "",
        Deno.env.get("SUPABASE_ANON_KEY") ?? "",
        {
          global: {
            headers: { Authorization: authHeader },
          },
        },
      );

      const {
        data: { user },
        error: userError,
      } = await userSupabase.auth.getUser();

      if (userError || !user) {
        throw new Error("Sesión inválida o expirada");
      }

      // Verify password by attempting to sign in
      const { error: passwordError } =
        await supabaseClient.auth.signInWithPassword({
          email: user.email!,
          password: password,
        });

      if (passwordError) {
        throw new Error("Contraseña incorrecta");
      }

      // Use service role to delete user data and auth account
      const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
      if (!serviceKey) {
        throw new Error("Missing SUPABASE_SERVICE_ROLE_KEY");
      }

      const serviceClient = createClient(
        Deno.env.get("SUPABASE_URL") ?? "",
        serviceKey,
        { auth: { persistSession: false } },
      );

      // Strategy: Delete from Auth first. 
      // This will trigger 'ON DELETE CASCADE' in the database (profiles table).
      const { error: authDeleteError } =
        await serviceClient.auth.admin.deleteUser(user.id);

      if (authDeleteError) {
        console.error("Error deleting auth user:", authDeleteError);
        // Fallback: Try to delete profile manually if auth delete failed for some reason
        const { error: profileError } = await serviceClient
          .from("profiles")
          .delete()
          .eq("id", user.id);

        if (profileError) {
          throw new Error("Error al eliminar la cuenta de autenticación y el perfil");
        }
        throw new Error("Error al eliminar la cuenta de autenticación");
      }

      return new Response(
        JSON.stringify({ message: "Cuenta eliminada correctamente" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // --- DELETE USER ADMIN (Administrative deletion) ---
    if (path === "delete-user-admin" && req.method === "DELETE") {
      const { user_id } = await req.json();

      if (!user_id) {
        throw new Error("User ID is required");
      }

      // Authorization Check (Must be an Admin)
      const authHeader = req.headers.get("Authorization");
      if (!authHeader) {
        throw new Error("Missing Authorization header");
      }

      const userSupabase = createClient(
        Deno.env.get("SUPABASE_URL") ?? "",
        Deno.env.get("SUPABASE_ANON_KEY") ?? "",
        {
          global: {
            headers: { Authorization: authHeader },
          },
        },
      );

      const {
        data: { user: adminUser },
        error: userError,
      } = await userSupabase.auth.getUser();

      if (userError || !adminUser) {
        throw new Error("Sesión inválida o expirada");
      }

      // Verify admin role
      const { data: adminProfile, error: adminProfileError } = await userSupabase
        .from("profiles")
        .select("role")
        .eq("id", adminUser.id)
        .single();

      if (adminProfileError || adminProfile?.role !== "admin") {
        throw new Error("No tienes permisos suficientes para esta acción");
      }

      // Use service role to delete user
      const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
      if (!serviceKey) {
        throw new Error("Missing SUPABASE_SERVICE_ROLE_KEY");
      }

      const serviceClient = createClient(
        Deno.env.get("SUPABASE_URL") ?? "",
        serviceKey,
        { auth: { persistSession: false } },
      );

      // Delete from Auth first (leverages CASCADE)
      const { error: authDeleteError } =
        await serviceClient.auth.admin.deleteUser(user_id);

      if (authDeleteError) {
        console.error("Error admin-deleting auth user:", authDeleteError);
        // Fallback: Try manual profile deletion
        await serviceClient.from("profiles").delete().eq("id", user_id);
        throw new Error("Error al eliminar la cuenta de autenticación");
      }

      return new Response(
        JSON.stringify({ message: "Usuario eliminado correctamente" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(JSON.stringify({ error: "Not Found" }), {
      status: 404,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error: any) {
    console.error("Critical error in edge function:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
