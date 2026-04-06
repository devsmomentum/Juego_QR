-- Create the merchandise_items table
CREATE TABLE IF NOT EXISTS merchandise_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    subtitle TEXT,
    category TEXT NOT NULL,
    price_clovers INTEGER NOT NULL CHECK (price_clovers >= 0),
    image_url TEXT,
    description TEXT,
    stock INTEGER DEFAULT 0,
    is_available BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create the merchandise_redemptions table
CREATE TABLE IF NOT EXISTS merchandise_redemptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    item_id UUID REFERENCES merchandise_items(id) ON DELETE CASCADE NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('pending', 'approved', 'shipped', 'delivered', 'cancelled', 'rejected')) DEFAULT 'pending',
    pts_paid INTEGER NOT NULL,
    admin_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE merchandise_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE merchandise_redemptions ENABLE ROW LEVEL SECURITY;

-- Item Policies
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Public can view available items') THEN
        CREATE POLICY "Public can view available items" ON merchandise_items
            FOR SELECT USING (is_available = true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Admins have full access to merchandise_items') THEN
        CREATE POLICY "Admins have full access to merchandise_items" ON merchandise_items
            FOR ALL TO authenticated
            USING (EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin'));
    END IF;
END $$;

-- Redemption Policies
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can view their own redemptions') THEN
        CREATE POLICY "Users can view their own redemptions" ON merchandise_redemptions
            FOR SELECT TO authenticated
            USING (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can create their own redemptions') THEN
        CREATE POLICY "Users can create their own redemptions" ON merchandise_redemptions
            FOR INSERT TO authenticated
            WITH CHECK (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Admins have full access to merchandise_redemptions') THEN
        CREATE POLICY "Admins have full access to merchandise_redemptions" ON merchandise_redemptions
            FOR ALL TO authenticated
            USING (EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin'));
    END IF;
END $$;

-- RPC to perform redemption safely
CREATE OR REPLACE FUNCTION redeem_merchandise_item(p_item_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_item_price INTEGER;
    v_user_clovers INTEGER;
    v_item_name TEXT;
    v_item_stock INTEGER;
BEGIN
    -- 1. Obtener detalles del producto y verificar disponibilidad
    SELECT name, price_clovers, stock 
    INTO v_item_name, v_item_price, v_item_stock
    FROM merchandise_items
    WHERE id = p_item_id AND is_available = true;

    IF v_item_name IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Producto no encontrado o no disponible');
    END IF;

    IF v_item_stock <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'Lo sentimos, este producto se ha agotado');
    END IF;

    -- 2. Obtener y verificar el saldo de Tréboles del usuario
    SELECT clovers INTO v_user_clovers
    FROM profiles
    WHERE id = v_user_id;

    IF v_user_clovers < v_item_price THEN
        RETURN jsonb_build_object('success', false, 'message', 'Saldo insuficiente. ¡Sigue jugando para ganar más!');
    END IF;

    -- 3. ACTUALIZACIONES ATÓMICAS (Todo o nada)
    -- Descontar stock
    UPDATE merchandise_items
    SET stock = stock - 1
    WHERE id = p_item_id;

    -- Descontar Tréboles del perfil
    UPDATE profiles
    SET clovers = clovers - v_item_price
    WHERE id = v_user_id;

    -- Registrar la solicitud de canje
    INSERT INTO merchandise_redemptions (user_id, item_id, pts_paid, status)
    VALUES (v_user_id, p_item_id, v_item_price, 'pending');

    -- Registrar en el historial de transacciones (wallet_ledger)
    INSERT INTO wallet_ledger (user_id, amount, description, metadata)
    VALUES (
        v_user_id, 
        -v_item_price, 
        'Canje de producto: ' || v_item_name, 
        jsonb_build_object(
            'item_id', p_item_id, 
            'type', 'merchandise_redemption'
        )
    );

    RETURN jsonb_build_object(
        'success', true, 
        'message', '✅ ¡Solicitud enviada! Un administrador revisará tu canje pronto.'
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', 'Error interno al procesar el canje: ' || SQLERRM);
END;
$$;
