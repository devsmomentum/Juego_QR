-- ============================================================
-- Migración: ~100 país-capital para el minijuego Capitales
-- Tabla: minigame_capitals (flag TEXT = nombre del país, capital TEXT)
-- El campo "flag" en el código guarda el nombre del país (legacy naming)
-- ============================================================

CREATE TABLE IF NOT EXISTS minigame_capitals (
  id      BIGSERIAL PRIMARY KEY,
  flag    TEXT NOT NULL,
  capital TEXT NOT NULL
);

-- Eliminar filas duplicadas (UUID-safe: usa DISTINCT ON)
DELETE FROM minigame_capitals
WHERE id NOT IN (
  SELECT id FROM (
    SELECT DISTINCT ON (flag) id
    FROM minigame_capitals
    ORDER BY flag
  ) sub
);

-- Agregar constraint UNIQUE si no existe
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'minigame_capitals_flag_key'
      AND conrelid = 'minigame_capitals'::regclass
  ) THEN
    ALTER TABLE minigame_capitals ADD CONSTRAINT minigame_capitals_flag_key UNIQUE (flag);
  END IF;
END
$$;

INSERT INTO minigame_capitals (flag, capital) VALUES

-- EUROPA
('España', 'Madrid'),
('Francia', 'París'),
('Italia', 'Roma'),
('Alemania', 'Berlín'),
('Portugal', 'Lisboa'),
('Reino Unido', 'Londres'),
('Países Bajos', 'Ámsterdam'),
('Bélgica', 'Bruselas'),
('Suiza', 'Berna'),
('Austria', 'Viena'),
('Suecia', 'Estocolmo'),
('Noruega', 'Oslo'),
('Dinamarca', 'Copenhague'),
('Finlandia', 'Helsinki'),
('Polonia', 'Varsovia'),
('Hungría', 'Budapest'),
('República Checa', 'Praga'),
('Rumanía', 'Bucarest'),
('Grecia', 'Atenas'),
('Turquía', 'Ankara'),
('Ucrania', 'Kiev'),
('Croacia', 'Zagreb'),
('Serbia', 'Belgrado'),
('Bulgaria', 'Sofía'),
('Irlanda', 'Dublín'),
('Escocia', 'Edimburgo'),
('Luxemburgo', 'Luxemburgo'),
('Mónaco', 'Mónaco'),
('Islandia', 'Reikiavik'),
('Eslovenia', 'Liubliana'),

-- AMÉRICAS
('México', 'Ciudad de México'),
('Estados Unidos', 'Washington D.C.'),
('Canadá', 'Ottawa'),
('Brasil', 'Brasilia'),
('Argentina', 'Buenos Aires'),
('Chile', 'Santiago'),
('Perú', 'Lima'),
('Colombia', 'Bogotá'),
('Venezuela', 'Caracas'),
('Ecuador', 'Quito'),
('Bolivia', 'La Paz'),
('Paraguay', 'Asunción'),
('Uruguay', 'Montevideo'),
('Cuba', 'La Habana'),
('Guatemala', 'Ciudad de Guatemala'),
('Honduras', 'Tegucigalpa'),
('El Salvador', 'San Salvador'),
('Nicaragua', 'Managua'),
('Costa Rica', 'San José'),
('Panamá', 'Ciudad de Panamá'),
('República Dominicana', 'Santo Domingo'),
('Jamaica', 'Kingston'),
('Trinidad y Tobago', 'Puerto España'),
('Guyana', 'Georgetown'),
('Surinam', 'Paramaribo'),

-- ASIA
('Japón', 'Tokio'),
('China', 'Pekín'),
('Corea del Sur', 'Seúl'),
('India', 'Nueva Delhi'),
('Rusia', 'Moscú'),
('Indonesia', 'Yakarta'),
('Tailandia', 'Bangkok'),
('Vietnam', 'Hanói'),
('Filipinas', 'Manila'),
('Malasia', 'Kuala Lumpur'),
('Singapur', 'Singapur'),
('Pakistán', 'Islamabad'),
('Bangladesh', 'Daca'),
('Irán', 'Teherán'),
('Iraq', 'Bagdad'),
('Arabia Saudita', 'Riad'),
('Israel', 'Jerusalén'),
('Jordania', 'Amán'),
('Emiratos Árabes Unidos', 'Abu Dabi'),
('Afganistán', 'Kabul'),
('Nepal', 'Katmandú'),
('Sri Lanka', 'Colombo'),
('Myanmar', 'Naipyidó'),
('Camboya', 'Nom Pen'),
('Mongolia', 'Ulán Bator'),

-- AFRICA
('Egipto', 'El Cairo'),
('Sudáfrica', 'Pretoria'),
('Nigeria', 'Abuja'),
('Kenia', 'Nairobi'),
('Etiopía', 'Adís Abeba'),
('Ghana', 'Acra'),
('Marruecos', 'Rabat'),
('Argelia', 'Argel'),
('Túnez', 'Túnez'),
('Senegal', 'Dakar'),
('Tanzania', 'Dodoma'),
('Uganda', 'Kampala'),
('Zimbabue', 'Harare'),
('Angola', 'Luanda'),
('Mozambique', 'Maputo'),

-- OCEANÍA
('Australia', 'Canberra'),
('Nueva Zelanda', 'Wellington'),
('Papúa Nueva Guinea', 'Port Moresby'),
('Fiji', 'Suva'),
('Samoa', 'Apia')

ON CONFLICT ON CONSTRAINT minigame_capitals_flag_key DO NOTHING;
