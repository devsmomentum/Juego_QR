-- ============================================================
-- Migración: preguntas para Verdadero o Falso
-- Tabla: minigame_true_false
-- ============================================================

-- Asegurar que la tabla existe con la estructura correcta
-- CREATE TABLE IF NOT EXISTS minigame_true_false (
--   id         uuid    DEFAULT extensions.uuid_generate_v4() PRIMARY KEY,
--   statement  TEXT    NOT NULL UNIQUE,
--   is_true    BOOLEAN NOT NULL,
--   correction TEXT    NOT NULL DEFAULT ''
-- );

ALTER TABLE minigame_true_false ADD CONSTRAINT unique_statement UNIQUE (statement);

INSERT INTO minigame_true_false (statement, is_true, correction) VALUES

-- CIENCIA Y NATURALEZA
('El sol es una estrella de tipo G2V (enana amarilla).', true, ''),
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
('El Imperio Británico fue el más extenso de la historia por superficie total.', true, 'El Mongol fue el más grande de tierras contiguas.'),
('Marco Polo nació en Venecia.', true, ''),
('El juego del ajedrez fue inventado en India.', true, 'Se originó en la India, aproximadamente en el siglo VI.'),
('Cleopatra vivió más cerca en el tiempo del iPhone que de la construcción de las pirámides.', true, ''),
('La primera vuelta al mundo fue comandada por Cristóbal Colón.', false, 'Fue comandada por Fernando de Magallanes y completada por Elcano.'),
('La Estatua de la Libertad fue un regalo de Francia a EE.UU.', true, ''),
('Los mayas desarrollaron de forma independiente el concepto del número cero.', true, ''),
('La tinta china fue inventada en Egipto.', false, 'Se originó en China.'),
('Juana de Arco fue quemada en la hoguera por cargos de herejía.', true, 'Aunque se le asoció con brujería, el cargo formal fue el de herejía.'),

-- CIENCIA Y TECNOLOGÍA
('El primer smartphone fue el IBM Simon (1992).', true, ''),
('La web (WWW) fue inventada por Tim Berners-Lee.', true, ''),
('El láser emite luz coherente y monocromática.', true, ''),
('El transistor fue inventado antes que el circuito integrado.', true, ''),
('Python es un lenguaje de programación interpretado.', true, ''),
('El satélite Sputnik fue el primero en orbitar la Tierra.', true, ''),
('Neil Armstrong fue el primer hombre en caminar en la Luna.', true, ''),
('La luz visible representa la mayoría del espectro electromagnético.', false, 'Solo representa una pequeña fracción.'),
('El acero es una mezcla de hierro y carbono.', true, ''),
('El primer videojuego comercial fue Pong.', false, 'Fue Computer Space (1971).'),
('Los rayos X son más energéticos que las ondas de radio.', true, ''),
('El ordenador Deep Blue venció a Garry Kasparov en ajedrez en 1997.', true, ''),
('La batería fue inventada por Alessandro Volta.', true, ''),
('Internet fue inicialmente una red militar llamada ARPANET.', true, ''),

-- ENTRETENIMIENTO Y CULTURA POP
('Harry Potter fue publicado por primera vez en 1997.', true, ''),
('Avatar (2009) es la película más taquillera de la historia.', true, ''),
('Mickey Mouse fue el primer personaje animado con sonido sincronizado.', true, ''),
('Los Beatles eran originarios de Liverpool.', true, ''),
('El personaje de Sherlock Holmes fue creado por Arthur Conan Doyle.', true, ''),
('La saga Star Wars comenzó con el Episodio IV en 1977.', true, ''),
('Minecraft fue creado por Notch (Markus Persson).', true, ''),
('El rey León está basado en la obra de Shakespeare Hamlet.', true, ''),
('Taylor Swift comenzó su carrera como cantante de country.', true, ''),
('El juego de mesa Cluedo se llama Clue en Norteamérica.', true, '')

ON CONFLICT (statement) DO UPDATE 
SET is_true = EXCLUDED.is_true, 
    correction = EXCLUDED.correction;
