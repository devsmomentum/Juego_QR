// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// @ts-ignore: Deno is global in Supabase Edge Functions
serve(async (req: Request) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders });
    }

    try {
        const supabaseClient = createClient(
            // @ts-ignore
            Deno.env.get('SUPABASE_URL') ?? '',
            // @ts-ignore
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        );

        // 0. Parse optional body for manual trigger
        let isManualAction = false;
        try {
            const body = await req.json();
            if (body && body.trigger === 'manual') {
                isManualAction = true;
                console.log('Manual trigger detected. Bypassing "enabled" check.');
            }
        } catch (_e) {
            // Ignore if no body
        }

        // 1. Fetch Configuration via RPC
        const { data: config, error: configError } = await supabaseClient
            .rpc('get_auto_event_settings');

        if (configError || !config) {
            console.error('Error fetching auto-event settings:', configError);
            return new Response(JSON.stringify({ error: 'Config not found' }), { status: 500 });
        }

        // Fetch Global Power Defaults
        const { data: globalPowerCostsData } = await supabaseClient
            .from('app_config')
            .select('config_value')
            .eq('config_key', 'power_default_costs')
            .maybeSingle();

        let globalPowerCosts: Record<string, number> = {};
        if (globalPowerCostsData && globalPowerCostsData.config_value) {
            globalPowerCosts = globalPowerCostsData.config_value as Record<string, number>;
        }

        // 2. Check if automation is enabled (Bypass if manual)
        if (config.enabled !== true && !isManualAction) {
            console.log('Automation is disabled and not a manual trigger.');
            return new Response(JSON.stringify({ message: 'Automation disabled' }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200
            });
        }

        // 3. Randomize Parameters based on config with robust fallbacks
        const minPlayers = config.min_players !== undefined ? Number(config.min_players) : 5;
        const maxPlayers = config.max_players !== undefined ? Number(config.max_players) : 60;
        const minGames = config.min_games !== undefined ? Number(config.min_games) : 4;
        const maxGames = config.max_games !== undefined ? Number(config.max_games) : 10;
        const minFee = config.min_fee !== undefined ? Number(config.min_fee) : 0;
        const maxFee = config.max_fee !== undefined ? Number(config.max_fee) : 300;
        const feeStep = config.fee_step !== undefined ? Number(config.fee_step) : 5;
        const pendingWaitMinutes = Number(config.pending_wait_minutes) || 5;
        const intervalMinutes = config.interval_minutes !== undefined ? Number(config.interval_minutes) : 60;

        // Price defaults (same values hardcoded before, now overridable from admin config)
        const hardcodedFallbackPrices: Record<string, number> = {
            black_screen: 75, blur_screen: 75, extra_life: 40,
            return: 90, freeze: 120, shield: 40, life_steal: 120, invisibility: 40
        };

        const defaultPrices: Record<string, number> = { ...hardcodedFallbackPrices, ...globalPowerCosts };
        const configPlayerPrices: Record<string, number> =
            (config.player_prices && typeof config.player_prices === 'object')
                ? config.player_prices as Record<string, number>
                : {};
        const configSpectatorPrices: Record<string, number> =
            (config.spectator_prices && typeof config.spectator_prices === 'object')
                ? config.spectator_prices as Record<string, number>
                : {};

        // 3.5 Mode-based scheduling logic
        // Supports two modes:
        //   "automatic" (default): creates events every `interval_minutes` since the last one.
        //   "scheduled": creates events at fixed VET (UTC-4) hours from `scheduled_hours`.
        // Only one mode is active at a time. Manual triggers bypass both.
        const VET_OFFSET_HOURS = -4; // Venezuela Time = UTC-4 (no DST)
        const mode: string = config.mode || 'automatic';
        const scheduledHours: string[] = Array.isArray(config.scheduled_hours) ? config.scheduled_hours : [];

        // eventDate will be set based on mode; used later for the event's `date` field.
        let eventDate: Date;

        if (mode === 'scheduled' && scheduledHours.length > 0 && !isManualAction) {
            // ── SCHEDULED MODE ─────────────────────────────────────────────
            const now = new Date();
            const pendingMs = pendingWaitMinutes * 60 * 1000;
            let targetDate: Date | null = null;

            for (const hourStr of scheduledHours) {
                const parts = hourStr.split(':');
                const h = parseInt(parts[0], 10);
                const m = parseInt(parts[1] || '0', 10);
                if (isNaN(h) || isNaN(m)) continue;

                // Build today's scheduled time: hours are in VET (UTC-4), convert to UTC
                const utcHour = h - VET_OFFSET_HOURS; // e.g. 15:00 VET → 19:00 UTC
                const scheduled = new Date(Date.UTC(
                    now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), utcHour, m, 0, 0
                ));
                // The trigger fires pending_wait_minutes BEFORE the scheduled hour
                const triggerTime = new Date(scheduled.getTime() - pendingMs);
                const diffMs = now.getTime() - triggerTime.getTime();

                // The event should be created anytime between triggerTime and the scheduled hour.
                // This covers: exact trigger moment, late cron fires, and cases where
                // the admin sets a schedule that's fewer than pending_wait_minutes away.
                // The idempotency check below prevents duplicates across multiple cron ticks.
                if (now.getTime() >= triggerTime.getTime() && now.getTime() < scheduled.getTime()) {
                    targetDate = scheduled;
                    break;
                }

                // Also check tomorrow's occurrence of the same slot
                const scheduledTomorrow = new Date(scheduled.getTime() + 86_400_000);
                const triggerTomorrow = new Date(scheduledTomorrow.getTime() - pendingMs);
                if (now.getTime() >= triggerTomorrow.getTime() && now.getTime() < scheduledTomorrow.getTime()) {
                    targetDate = scheduledTomorrow;
                    break;
                }
            }

            if (!targetDate) {
                console.log(`Scheduled mode: no slot trigger matches current time. Hours: ${scheduledHours.join(', ')}`);
                return new Response(JSON.stringify({
                    message: 'No scheduled slot now',
                    mode: 'scheduled',
                    scheduled_hours: scheduledHours
                }), {
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                    status: 200
                });
            }

            // Idempotency: check no event already exists for this time slot (±2 min window)
            const windowStart = new Date(targetDate.getTime() - 120_000).toISOString();
            const windowEnd = new Date(targetDate.getTime() + 120_000).toISOString();

            const { data: existingEvent } = await supabaseClient
                .from('events')
                .select('id')
                .eq('type', 'online')
                .gte('date', windowStart)
                .lte('date', windowEnd)
                .limit(1)
                .maybeSingle();

            if (existingEvent) {
                console.log(`Scheduled mode: event already exists for slot ${targetDate.toISOString()} (id: ${existingEvent.id})`);
                return new Response(JSON.stringify({
                    message: 'Event already exists for this slot',
                    existing_event_id: existingEvent.id,
                    slot: targetDate.toISOString()
                }), {
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                    status: 200
                });
            }

            eventDate = targetDate;
            console.log(`Scheduled mode: creating event for slot ${targetDate.toISOString()} (trigger window hit)`);

        } else if (!isManualAction) {
            // ── AUTOMATIC MODE (default) ───────────────────────────────────
            const { data: lastEvent, error: lastEventError } = await supabaseClient
                .from('events')
                .select('created_at')
                .eq('type', 'online')
                .order('created_at', { ascending: false })
                .limit(1)
                .maybeSingle();

            if (lastEvent && lastEvent.created_at) {
                const lastCreatedAt = new Date(lastEvent.created_at).getTime();
                const now = Date.now();
                const diffMinutes = (now - lastCreatedAt) / (1000 * 60);

                if (diffMinutes < intervalMinutes) {
                    console.log(`Skipping generation. Only ${diffMinutes.toFixed(1)} mins since last event. Required: ${intervalMinutes} mins.`);
                    return new Response(JSON.stringify({
                        message: 'Interval not reached',
                        minutes_since_last: diffMinutes,
                        required_interval: intervalMinutes
                    }), {
                        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                        status: 200
                    });
                }
            }

            // In automatic mode, event starts after pending_wait_minutes from now
            eventDate = new Date(Date.now() + pendingWaitMinutes * 60 * 1000);
            console.log(`Automatic mode: next event date = ${eventDate.toISOString()}`);

        } else {
            // ── MANUAL TRIGGER ─────────────────────────────────────────────
            eventDate = new Date(Date.now() + pendingWaitMinutes * 60 * 1000);
            console.log(`Manual trigger: event date = ${eventDate.toISOString()}`);
        }

        // Usar exactamente el valor máximo configurado por el admin
        const playerCount = maxPlayers;
        const gameCount = Math.floor(Math.random() * (maxGames - minGames + 1)) + minGames;
        const configuredWinners = playerCount < 6 ? 1 : playerCount < 11 ? 2 : 3;

        // Safe fee calculation
        const feeRangeCount = Math.max(0, Math.floor((maxFee - minFee) / feeStep));
        const entryFee = (Math.floor(Math.random() * (feeRangeCount + 1)) * feeStep) + minFee;

        console.log(`Config: Players(${minPlayers}-${maxPlayers}), Games(${minGames}-${maxGames}), Fee(${minFee}-${maxFee} step ${feeStep})`);
        console.log(`Generated: ${playerCount} players, ${gameCount} games, ${entryFee} entry fee`);

        const easyPool = ['slidingPuzzle', 'trueFalse', 'virusTap', 'flags'];
        const mediumPool = ['memorySequence', 'emojiMovie', 'droneDodge', 'missingOperator', 'capitalCities'];
        const hardPool = ['tetris', 'minesweeper', 'blockFill', 'holographicPanels', 'percentageCalculation', 'drinkMixer'];

        const selectedPuzzles: string[] = [];
        const targetEasy = Math.min(easyPool.length, Math.ceil(gameCount * 0.4));
        const targetMedium = Math.min(mediumPool.length, Math.ceil(gameCount * 0.4));
        const targetHard = Math.min(hardPool.length, gameCount - targetEasy - targetMedium);

        console.log(`Generating ${gameCount} minigames: Easy: ${targetEasy}, Medium: ${targetMedium}, Hard: ${targetHard}`);

        const shuffle = (array: string[]) => [...array].sort(() => Math.random() - 0.5);

        const shuffledEasy = shuffle(easyPool);
        const shuffledMedium = shuffle(mediumPool);
        const shuffledHard = shuffle(hardPool);

        selectedPuzzles.push(...shuffledEasy.slice(0, targetEasy));
        selectedPuzzles.push(...shuffledMedium.slice(0, targetMedium));
        selectedPuzzles.push(...shuffledHard.slice(0, targetHard));

        // Extraer los juegos que sobraron para rellenar huecos sin repetir
        const unusedGames = [
            ...shuffledEasy.slice(targetEasy),
            ...shuffledMedium.slice(targetMedium),
            ...shuffledHard.slice(targetHard)
        ];

        const remainingToFill = gameCount - selectedPuzzles.length;
        if (remainingToFill > 0) {
            selectedPuzzles.push(...shuffle(unusedGames).slice(0, remainingToFill));
        }

        // Si piden más juegos del total disponible, repetir pero sin que salgan pegados y de manera variada
        while (selectedPuzzles.length < gameCount) {
            const allGames = [...easyPool, ...mediumPool, ...hardPool];
            const candidate = allGames[Math.floor(Math.random() * allGames.length)];
            if (selectedPuzzles[selectedPuzzles.length - 1] !== candidate) {
                selectedPuzzles.push(candidate);
            }
        }

        console.log('Selected Puzzles:', selectedPuzzles);

        // 4. Create Event
        // @ts-ignore
        const eventId = crypto.randomUUID();
        const pin = (Math.floor(Math.random() * 900000) + 100000).toString();

        console.log(`Creating event: ${eventId} with PIN: ${pin}`);

        const { data: _eventData, error: eventError } = await supabaseClient
            .from('events')
            .insert({
                id: eventId,
                title: `⚡ Competencia Online #${new Date().getTime().toString().slice(-4)}`,
                description: '¡Demuestra tu habilidad!',
                image_url: 'https://shxbfwdapwbizxspicai.supabase.co/storage/v1/object/public/logos/default_event_logo.png',
                location_name: 'Online',
                latitude: 0,
                longitude: 0,
                // date = eventDate (computed by mode: scheduled hour or now + pendingWaitMinutes)
                date: eventDate.toISOString(),
                max_participants: playerCount,
                pin: pin,
                clue: '🏆 ¡Felicidades! Has completado el circuito online.',
                type: 'online',
                entry_fee: entryFee,
                status: 'pending',   // ← starts pending; activated by auto_start_online_event RPC
                configured_winners: configuredWinners,
                is_automated: true,  // ← no admin intervention needed; auto-starts at countdown end
                spectator_config: Object.keys(configSpectatorPrices).length > 0
                    ? configSpectatorPrices
                    : defaultPrices,
                created_at: new Date().toISOString()
            })
            .select()
            .single();

        if (eventError) {
            console.error('Error creating event:', eventError);
            throw eventError;
        }

        // --- DEBUG: Checking environment variables ---
        const osAppId = Deno.env.get('ONESIGNAL_APP_ID');
        const osApiKey = Deno.env.get('ONESIGNAL_REST_API_KEY');
        console.log(`[OneSignal Debug] APP_ID present: ${!!osAppId} (${osAppId?.slice(0, 5)}...)`);
        console.log(`[OneSignal Debug] API_KEY present: ${!!osApiKey} (${osApiKey?.slice(0, 15)}...)`);

        // --- Push Notification Logic ---
        try {
            const osAppId = Deno.env.get('ONESIGNAL_APP_ID');
            const osApiKey = Deno.env.get('ONESIGNAL_REST_API_KEY');
            const appEnv = Deno.env.get('APP_ENV') || 'dev'; // Por defecto es dev

            if (osAppId && osApiKey) {
                const eventStartTime = eventDate;
                const notificationTime = new Date(eventStartTime.getTime() - (10 * 60 * 1000));
                const now = new Date();

                const notificationBody: any = {
                    app_id: osAppId,
                    headings: { "es": "⚡ ¡Competencia Proxima!", "en": "⚡ Upcoming Event!" },
                    contents: {
                        "es": "La competencia online comienza en 10 minutos. ¡Entra ya!",
                        "en": "The online competition starts in 10 minutes. Join now!"
                    },
                    data: { "event_id": eventId, "type": "event_reminder" }
                };

                // --- SWITCH INTELIGENTE DE AUDIENCIA ---
                if (appEnv === 'prod') {
                    // En producción enviamos a todos
                    notificationBody.included_segments = ["All"];
                    console.log('📢 Target: All users (Production mode)');
                } else {
                    // En desarrollo enviamos SOLO a los marcados como dev
                    notificationBody.filters = [
                        { "field": "tag", "key": "app_env", "relation": "=", "value": "dev" }
                    ];
                    console.log('📢 Target: Dev testers only (Development mode)');
                }

                if (notificationTime.getTime() > now.getTime() + 15000) {
                    notificationBody.send_after = notificationTime.toISOString();
                    console.log(`📅 Scheduled for: ${notificationTime.toISOString()}`);
                }

                const response = await fetch("https://onesignal.com/api/v1/notifications", {
                    method: "POST",
                    headers: {
                        "Content-Type": "application/json; charset=utf-8",
                        "Authorization": `Basic ${osApiKey}`
                    },
                    body: JSON.stringify(notificationBody)
                });

                const result = await response.json();
                console.log(`✅ OneSignal response:`, JSON.stringify(result));
            }
        } catch (error) {
            console.error('⚠️ Notification error (non-critical):', error);
        }

        // 5. Create Clues (Minigames)
        const clues = selectedPuzzles.map((puzzle, index) => ({
            event_id: eventId,
            title: `Minijuego ${index + 1}`,
            description: 'Supera el desafío para avanzar',
            type: 'minigame',
            puzzle_type: puzzle,
            riddle_question: '¡Gana para completar!',
            riddle_answer: 'WIN',
            xp_reward: 50,
            hint: 'Pista Online',
            sequence_index: index + 1,
            latitude: 0,
            longitude: 0
        }));

        console.log(`Inserting ${clues.length} clues for event ${eventId}...`);

        const { data: savedClues, error: cluesError } = await supabaseClient
            .from('clues')
            .insert(clues)
            .select();

        if (cluesError) {
            console.error('❌ Error creating clues:', JSON.stringify(cluesError));
            throw cluesError;
        }

        console.log(`✅ Successfully saved ${savedClues?.length || 0} clues.`);

        // 6. Create Store – use admin-configured player prices, fallback to defaults
        const storeProducts = Object.entries(defaultPrices).map(([id, defaultCost]) => ({
            id,
            cost: configPlayerPrices[id] !== undefined ? Number(configPlayerPrices[id]) : defaultCost
        }));

        console.log(`Creating mall store for event ${eventId}...`);

        const { data: savedStore, error: storeError } = await supabaseClient
            .from('mall_stores')
            .insert({
                event_id: eventId,
                name: 'Tienda de Objetos',
                description: 'Potenciadores para la competencia',
                qr_code_data: `store_${eventId}`,
                products: storeProducts
            })
            .select()
            .single();

        if (storeError) {
            console.error('❌ Error creating mall store:', JSON.stringify(storeError));
            throw storeError;
        }

        console.log('✅ Store created successfully:', savedStore.id);

        return new Response(JSON.stringify({
            success: true,
            eventId,
            pin,
            games: selectedPuzzles,
            cluesSaved: savedClues?.length || 0,
            storeId: savedStore.id
        }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
        });

    } catch (error: any) {
        console.error('Automation error:', error.message);
        return new Response(JSON.stringify({ error: error.message }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 400,
        });
    }
});
