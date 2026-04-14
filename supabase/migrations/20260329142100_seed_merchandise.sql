-- Seed data for the Merchandise Store
-- To apply this, run it in the Supabase SQL Editor.

INSERT INTO merchandise_items (name, subtitle, category, price_clovers, image_url, description, stock, is_available)
VALUES 
(
    'Camiseta MapHunter Edition', 
    'Edición Limitada 2026', 
    'Ropa', 
    1500, 
    'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?q=80&w=1000&auto=format&fit=crop', 
    'Camiseta de alta calidad con el logo de MapHunter en acabado reflectante neón. Ideal para tus aventuras nocturnas.', 
    50, 
    true
),
(
    'Gorra Cyberpunk', 
    'Ajustable y Transpirable', 
    'Accesorios', 
    800, 
    'https://images.unsplash.com/photo-1588850561407-ed78c282e89b?q=80&w=1000&auto=format&fit=crop', 
    'Gorra con bordado 3D y visera con detalles en fibra de carbono. Talla única.', 
    30, 
    true
),
(
    'Botella Térmica Hunter', 
    'Mantiene 24h Frío / 12h Calor', 
    'Equipamiento', 
    1200, 
    'https://images.unsplash.com/photo-1602143399827-bd95967c7c70?q=80&w=1000&auto=format&fit=crop', 
    'Botella de acero inoxidable con sensor de temperatura LED en la tapa.', 
    20, 
    true
),
(
    'Llavero Metálico Trébol', 
    'Zamak con Baño de Oro', 
    'Coleccionables', 
    500, 
    'https://images.unsplash.com/photo-1544256718-3bcf237f3974?q=80&w=1000&auto=format&fit=crop', 
    'Llavero macizo con la forma del trébol de MapHunter. Un símbolo de suerte para tus búsquedas.', 
    100, 
    true
);
