-- ============================================================
-- Migración: ~100 películas para el minijuego Adivina la Película
-- Tabla: minigame_emoji_movies (emojis TEXT, valid_answers TEXT[])
-- El campo valid_answers es un array de respuestas aceptadas
-- ============================================================

CREATE TABLE IF NOT EXISTS minigame_emoji_movies (
  id            BIGSERIAL PRIMARY KEY,
  emojis        TEXT   NOT NULL,
  valid_answers TEXT[] NOT NULL
);

-- Eliminar filas duplicadas (UUID-safe: usa DISTINCT ON)
DELETE FROM minigame_emoji_movies
WHERE id NOT IN (
  SELECT id FROM (
    SELECT DISTINCT ON (emojis) id
    FROM minigame_emoji_movies
    ORDER BY emojis
  ) sub
);

-- Agregar constraint UNIQUE si no existe
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'minigame_emoji_movies_emojis_key'
      AND conrelid = 'minigame_emoji_movies'::regclass
  ) THEN
    ALTER TABLE minigame_emoji_movies ADD CONSTRAINT minigame_emoji_movies_emojis_key UNIQUE (emojis);
  END IF;
END
$$;

INSERT INTO minigame_emoji_movies (emojis, valid_answers) VALUES

-- CLÁSICOS ANIMADOS
('🦁👑', ARRAY['el rey leon', 'the lion king', 'rey leon']),
('🐠🔍', ARRAY['buscando a nemo', 'finding nemo', 'nemo']),
('👧🏠🌪️', ARRAY['el mago de oz', 'wizard of oz', 'mago de oz']),
('🧊❄️👸', ARRAY['frozen', 'frozen el reino del hielo']),
('🐻🏠🍯', ARRAY['winnie the pooh', 'pooh']),
('🧜‍♀️🌊🏰', ARRAY['la sirenita', 'the little mermaid', 'sirenita']),
('🐘✈️🎪', ARRAY['dumbo']),
('🦌❄️🎅', ARRAY['bambi']),
('🐕‍🦺🍝', ARRAY['la dama y el vagabundo', 'lady and the tramp']),
('🧚‍♀️👦🌟', ARRAY['peter pan']),
('🤖❤️🌱', ARRAY['wall-e', 'walle']),
('🐀👨‍🍳🍽️', ARRAY['ratatouille']),
('👾🎮🏆', ARRAY['ralph el demoledor', 'wreck it ralph', 'ralph']),
('🦈💧🏊', ARRAY['tiburon', 'jaws']),
('🐝🌻🏆', ARRAY['bee movie']),

-- ACCIÓN Y AVENTURA
('💍🌋🧙', ARRAY['el senor de los anillos', 'lord of the rings']),
('🚢🧊💔', ARRAY['titanic']),
('🕷️🏙️🕸️', ARRAY['spiderman', 'spider-man', 'el hombre arana']),
('🪄⚡🏰', ARRAY['harry potter']),
('🦇🌆🔦', ARRAY['batman']),
('🦁🐯🦅⚡', ARRAY['wakanda', 'black panther', 'pantera negra']),
('⚒️🌈🔨', ARRAY['thor']),
('🐜🔬⚗️', ARRAY['ant-man', 'antman', 'hombre hormiga']),
('👁️💚🟢', ARRAY['hulk', 'el increible hulk']),
('🎯🏹💜', ARRAY['hawkeye', 'ojo de halcon']),
('🚀👨‍🚀🌌', ARRAY['guardians of the galaxy', 'guardianes de la galaxia']),
('🌀🔮✨', ARRAY['doctor strange', 'doctor extrano']),
('🏎️💨🏁', ARRAY['cars']),
('🔱🌊🏙️', ARRAY['aquaman']),
('🕊️🛡️⭐', ARRAY['capitan america', 'captain america']),

-- TERROR Y SUSPENSO
('🔪🚿🏨', ARRAY['psicosis', 'psycho']),
('👻🏠💀', ARRAY['paranormal activity']),
('🤡🎈😱', ARRAY['it', 'eso']),
('🎃🔪🌙', ARRAY['halloween']),
('👁️👁️🌽', ARRAY['hijos del maiz', 'children of the corn']),
('🪓🏠❄️', ARRAY['el resplandor', 'the shining']),
('🐍⛵', ARRAY['anaconda']),
('🎭🔪', ARRAY['scream', 'grito']),
('😈🌹💀', ARRAY['la bella y la bestia', 'beauty and the beast']),
('🧟‍♂️🏻🌆', ARRAY['resident evil']),

-- COMEDIA
('🏠😴💤👀', ARRAY['mi pobre angelito', 'home alone', 'solo en casa']),
('🐷✈️🏃', ARRAY['babe el cerdito valiente', 'babe']),
('💼📱🤑', ARRAY['el diablo viste a la moda', 'devil wears prada']),
('🤵💣🔫', ARRAY['mr bean']),
('🐔🏡', ARRAY['chicken run', 'pollitos en fuga']),
('🧓🏠🎈🏔️', ARRAY['up', 'arriba']),
('👶💼', ARRAY['un jefe en panales', 'boss baby']),
('🕵️🔍🐟', ARRAY['buscando a dory', 'finding dory']),
('🎮🏆💥', ARRAY['pixels']),
('🤖🏠🌎♻️', ARRAY['wall-e']),

-- CIENCIA FICCIÓN
('👾🛸🌍', ARRAY['la guerra de los mundos', 'war of the worlds']),
('🤖🦾🚗', ARRAY['transformers']),
('⭐🚀🔫', ARRAY['star wars', 'la guerra de las galaxias']),
('🌌🕳️', ARRAY['agujero negro', 'interstellar']),
('👽📞🏠', ARRAY['e.t.']),
('🕶️💊🔴🔵', ARRAY['matrix', 'the matrix']),
('🦕🏝️', ARRAY['jurassic park', 'parque jurasico']),
('♻️🌍🤖', ARRAY['wall-e']),
('🚀🌙👨‍🚀', ARRAY['apollo 13']),
('🧬🔬💀', ARRAY['jurassic world']),
('🤖👦🏠', ARRAY['chappie']),
('🌌🚀🐛', ARRAY['dune']),
('🧲💻🌐', ARRAY['el juego de la imitacion', 'the imitation game']),
('🚀💫🌌', ARRAY['gravity', 'gravedad']),
('🤖❤️', ARRAY['her']),

-- DRAMA Y ROMANCE
('💌📬🌹', ARRAY['usted tiene un mensaje', 'youve got mail']),
('🦋✉️🌊', ARRAY['el cartero y pablo neruda', 'il postino']),
('👫✈️🌎', ARRAY['vicky cristina barcelona']),
('🌹🥂💔', ARRAY['romeo y julieta', 'romeo and juliet']),
('🎶🌉🚗', ARRAY['la la land']),
('💃🕺🏫', ARRAY['dirty dancing']),
('🎤🎸🎸', ARRAY['bohemian rhapsody']),
('🐎🌅🎠', ARRAY['el caballo de guerra', 'war horse']),
('📚🍬❄️', ARRAY['la ladrona de libros', 'the book thief']),
('⛵🌊🏝️', ARRAY['cast away', 'naufrago']),

-- ANIMACIÓN MODERNA
('🌈🦄✨', ARRAY['mi pequeño pony', 'my little pony']),
('🕵️🦊🐰', ARRAY['zootropolis', 'zootopia']),
('🌎🌋🦴🐕', ARRAY['isle of dogs', 'isla de perros']),
('🐲🏔️🍜', ARRAY['mulan']),
('🕯️🌹🍽️', ARRAY['la bella y la bestia', 'beauty and the beast']),
('🏄🌊🐢', ARRAY['lilo y stitch']),
('👁️🏙️💡', ARRAY['minions']),
('🧒👴🏠🎸', ARRAY['coco']),
('🎪🤹‍♂️🦁', ARRAY['sing']),
('🧟‍♀️💃🏰', ARRAY['corpse bride', 'la novia cadaver'])

ON CONFLICT ON CONSTRAINT minigame_emoji_movies_emojis_key DO NOTHING;
