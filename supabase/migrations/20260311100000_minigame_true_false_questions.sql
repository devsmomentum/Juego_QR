-- ============================================================
-- Migración: 100 preguntas adicionales para Verdadero o Falso
-- Tabla: minigame_tf_statements (statement TEXT, is_true BOOL, correction TEXT)
-- Nota: el GameProvider lee esta tabla via loadMinigameData()
-- ============================================================

-- Asegurar que la tabla existe con la estructura correcta
CREATE TABLE IF NOT EXISTS minigame_tf_statements (
  id         BIGSERIAL PRIMARY KEY,
  statement  TEXT    NOT NULL,
  is_true    BOOLEAN NOT NULL,
  correction TEXT    NOT NULL DEFAULT ''
);

-- Eliminar filas duplicadas (conserva la de menor id)
DELETE FROM minigame_tf_statements
WHERE id NOT IN (
  SELECT MIN(id) FROM minigame_tf_statements GROUP BY statement
);

-- Agregar constraint UNIQUE si no existe (por si la tabla ya existía sin él)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'minigame_tf_statements_statement_key'
      AND conrelid = 'minigame_tf_statements'::regclass
  ) THEN
    ALTER TABLE minigame_tf_statements ADD CONSTRAINT minigame_tf_statements_statement_key UNIQUE (statement);
  END IF;
END
$$;

INSERT INTO minigame_tf_statements (statement, is_true, correction) VALUES

-- CIENCIA Y NATURALEZA
('El corazón humano late aproximadamente 100 000 veces al día.', true, ''),
('La Luna produce su propia luz.', false, 'La Luna refleja la luz del Sol.'),
('El ADN tiene forma de doble hélice.', true, ''),
('Los canguros son originarios de Africa.', false, 'Son originarios de Australia.'),
('El oxígeno es el elemento más abundante en la corteza terrestre.', true, ''),
('La mayoría de los tiburones son animales de sangre fría.', true, ''),
('El ser humano tiene 32 dientes permanentes.', true, ''),
('La velocidad del sonido es mayor en el agua que en el aire.', true, ''),
('El nervio más largo del cuerpo es el nervio femoral.', false, 'Es el nervio ciático.'),
('La fotosíntesis produce oxígeno como subproducto.', true, ''),
('El cerebro humano usa el 10% de su capacidad.', false, 'Es un mito; usamos prácticamente todo el cerebro.'),
('Los camellos almacenan agua en sus jorobas.', false, 'Almacenan grasa, no agua.'),
('La frecuencia del sonido se mide en hercios (Hz).', true, ''),
('El planeta más cercano al Sol es Mercurio.', true, ''),
('Las arañas son insectos.', false, 'Son arácnidos, con 8 patas.'),
('El cuerpo humano tiene más bacterias que células propias.', true, ''),
('El hielo es más denso que el agua líquida.', false, 'El hielo es menos denso, por eso flota.'),
('La gravedad de la Luna es 1/6 la de la Tierra.', true, ''),
('Los elefantes son los únicos animales que no pueden saltar.', false, 'Los hipopótamos tampoco pueden saltar.'),
('El volcán más alto del Sistema Solar está en Marte.', true, ''),

-- GEOGRAFÍA
('El idioma más hablado en Brasil es el español.', false, 'Es el portugués.'),
('Groenlandia pertenece a Dinamarca.', true, ''),
('El lago más profundo del mundo es el lago Baikal.', true, ''),
('Los Alpes están en América del Sur.', false, 'Están en Europa central.'),
('El océano Ártico es el más pequeño del mundo.', true, ''),
('La ciudad más poblada de América Latina es Buenos Aires.', false, 'Es Ciudad de México.'),
('Suiza tiene cuatro idiomas oficiales.', true, ''),
('El desierto de Atacama es el más seco del mundo.', true, ''),
('Finlandia tiene más de 100 000 lagos.', true, ''),
('El Monte Kilimanjaro está en Nigeria.', false, 'Está en Tanzania.'),
('Portugal fue el primer país europeo en abolir la esclavitud.', true, ''),
('La ciudad de Venecia está construida sobre islas.', true, ''),
('El río más largo de Europa es el Danubio.', false, 'Es el río Volga.'),
('Bolivia no tiene salida al mar.', true, ''),
('Monaco es el país más pequeño por población.', false, 'El Vaticano es el más pequeño.'),
('Taiwán es reconocida como estado independiente por la ONU.', false, 'La ONU reconoce la posición de China sobre Taiwán.'),
('La Gran Barrera de Coral está frente a la costa de Australia.', true, ''),
('El pico más alto de África es el Kilimanjaro.', true, ''),
('La Torre de Pisa está en Florencia.', false, 'Está en Pisa.'),
('Turquía tiene territorio en dos continentes.', true, ''),

-- HISTORIA Y CULTURA
('Napoleon Bonaparte era francés de nacimiento.', true, 'Nació en Córcega un año después de que la isla pasara a ser francesa (1768).'),
('La Guerra de los Cien Años duró exactamente 100 años.', false, 'Duró 116 años (1337-1453).'),
('El Imperio Romano de Occidente cayó en el año 476.', true, ''),
('La Biblia es el libro más vendido de la historia.', true, ''),
('El Coliseo Romano fue construido para albergar carreras de caballos.', false, 'Se usaba principalmente para gladiadores y espectáculos.'),
('Alejandro Magno murió a los 32 años.', true, ''),
('El primer presidente de los Estados Unidos fue George Washington.', true, ''),
('Las pirámides de Giza fueron construidas por esclavos.', false, 'Evidencias arqueológicas sugieren que fueron obreros pagados.'),
('La Revolución Industrial comenzó en Alemania.', false, 'Comenzó en Gran Bretaña.'),
('El Machu Picchu fue construido por los aztecas.', false, 'Fue construido por los incas.'),
('William Shakespeare nació y murió el mismo día del año.', true, ''),
('La primera bomba atómica se lanzó sobre Hiroshima.', true, ''),
('El Imperio Mongol fue el más grande de la historia.', true, ''),
('Marco Polo nació en Venecia.', true, ''),
('El juego del ajedrez fue inventado en China.', false, 'Se originó en la India, aproximadamente en el siglo VI.'),
('Cleopatra vivió más cerca en el tiempo del iPhone que de la construcción de las pirámides.', true, ''),
('La primera vuelta al mundo fue comandada por Cristóbal Colón.', false, 'Fue comandada por Fernando de Magallanes y completada por Elcano.'),
('La Estatua de la Libertad fue un regalo de Francia a EE.UU.', true, ''),
('Los mayas desarrollaron de forma independiente el concepto del número cero.', true, ''),
('La tinta china fue inventada en Egipto.', false, 'Se originó en China.'),

-- CIENCIA Y TECNOLOGÍA
('El primer smartphone fue el iPhone de Apple.', false, 'El IBM Simon (1992) fue el primer smartphone.'),
('La web (WWW) fue inventada por Tim Berners-Lee.', true, ''),
('El láser emite luz coherente y monocromática.', true, ''),
('El transistor fue inventado antes que el circuito integrado.', true, ''),
('Python es un lenguaje de programación compilado.', false, 'Es interpretado.'),
('El satélite Sputnik fue el primero en orbitar la Tierra.', true, ''),
('Neil Armstrong fue el primer hombre en caminar en la Luna.', true, ''),
('La luz visible solo representa una pequeña fracción del espectro electromagnético.', true, ''),
('El acero es una mezcla de hierro y aluminio.', false, 'El acero es una aleación de hierro y carbono.'),
('El primer videojuego comercial fue Pong.', false, 'Fue Computer Space (1971); Pong llegó en 1972.'),
('Los rayos X son más energéticos que las ondas de radio.', true, ''),
('El ordenador Deep Blue venció a Garry Kasparov en ajedrez en 1997.', true, ''),
('La batería fue inventada por Michael Faraday.', false, 'Fue inventada por Alessandro Volta.'),
('El GPS funciona gracias a satélites en órbita.', true, ''),
('Internet fue inicialmente una red militar llamada ARPANET.', true, ''),

-- ENTRETENIMIENTO Y CULTURA POP
('Harry Potter fue publicado por primera vez en 1997.', true, ''),
('La película más taquillera de la historia es Avengers: Endgame.', false, 'Avatar (2009) sigue siendo la más taquillera ajustada por tickets.'),
('Mickey Mouse fue el primer personaje de Disney con sonido sincronizado.', true, ''),
('Los Beatles eran originarios de Liverpool.', true, ''),
('El personaje de Sherlock Holmes fue creado por Arthur Conan Doyle.', true, ''),
('La saga Star Wars comenzó con el Episodio I.', false, 'La saga comenzó con el Episodio IV en 1977.'),
('Minecraft fue creado por Notch (Markus Persson).', true, ''),
('El rey León está basado en la obra de Shakespeare Hamlet.', true, ''),
('Taylor Swift comenzó su carrera como cantante de rap.', false, 'Comenzó como cantante de country.'),
('El juego de Mesa Cluedo se llama Clue en North America.', true, '')

ON CONFLICT ON CONSTRAINT minigame_tf_statements_statement_key DO NOTHING;
