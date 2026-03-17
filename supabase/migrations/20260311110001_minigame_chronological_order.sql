-- Migration for Chronological Order Minigame
-- Description: Create table and populate with 50+ historical events

CREATE TABLE IF NOT EXISTS minigame_chronological_order (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_name TEXT NOT NULL UNIQUE,
    year INTEGER NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE minigame_chronological_order ENABLE ROW LEVEL SECURITY;

-- Allow public read access
CREATE POLICY "Allow public read access for chronological order"
ON minigame_chronological_order FOR SELECT
TO public
USING (true);

-- Insert historical events
INSERT INTO minigame_chronological_order (event_name, year, description)
VALUES
    ('Invención de la Rueda', -3500, 'Mesopotamia, inicio de la tecnología de transporte.'),
    ('Escritura Cuneiforme', -3400, 'Primer sistema de escritura conocido en Sumeria.'),
    ('Construcción de la Gran Pirámide de Guiza', -2560, 'Egipto, una de las siete maravillas del mundo antiguo.'),
    ('Código de Hammurabi', -1750, 'Uno de los conjuntos de leyes más antiguos (Ojo por ojo).'),
    ('Caída de Troya', -1184, 'Guerra legendaria narrada por Homero.'),
    ('Fundación de Roma', -753, 'Inicio de la civilización romana.'),
    ('Vida de Buda (Siddhartha Gautama)', -563, 'Fundación del budismo en la India.'),
    ('Construcción de la Gran Muralla (Dinastía Qin)', -221, 'Unificación de China e inicio de la muralla.'),
    ('Asesinato de Julio César', -44, 'Idus de marzo, fin de la República Romana.'),
    ('Nacimiento de Jesús de Nazaret', -4, 'Punto de referencia para el calendario occidental.'),
    ('Caída del Imperio Romano de Occidente', 476, 'Fin de la Edad Antigua e inicio de la Edad Media.'),
    ('Hégira de Mahoma', 622, 'Traslado de La Meca a Medina, inicio del calendario islámico.'),
    ('Batalla de Hastings', 1066, 'Conquista normanda de Inglaterra.'),
    ('Firma de la Carta Magna', 1215, 'Sienta las bases de la democracia moderna.'),
    ('Llegada de la Peste Negra a Europa', 1347, 'Gran epidemia que diezmó la población europea.'),
    ('Invención de la Imprenta (Gutenberg)', 1440, 'Revolución en la difusión del conocimiento.'),
    ('Caída de Constantinopla', 1453, 'Fin del Imperio Bizantino.'),
    ('Llegada de Colón a América', 1492, 'Encuentro de dos mundos.'),
    ('Las 95 Tesis de Martín Lutero', 1517, 'Inicio de la Reforma Protestante.'),
    ('Primera Circunnavegación (Magallanes/Elcano)', 1522, 'Prueba definitiva de la esfericidad de la Tierra.'),
    ('Derrota de la Armada Invencible', 1588, 'Mantuvo la independencia de Inglaterra.'),
    ('Llegada del Mayflower a América', 1620, 'Establecimiento de los colonos en Plymouth.'),
    ('Publicación de Principia Mathematica (Newton)', 1687, 'Leyes de la gravitación universal.'),
    ('Declaración de Independencia de los EE. UU.', 1776, 'Nacimiento de los Estados Unidos.'),
    ('Revolución Francesa', 1789, 'Fin de la monarquía absoluta en Francia.'),
    ('Batalla de Waterloo', 1815, 'Derrota definitiva de Napoleón Bonaparte.'),
    ('Publicación de El Origen de las Especies (Darwin)', 1859, 'Teoría de la evolución.'),
    ('Inicio de la Guerra Civil Estadounidense', 1861, 'Guerra de Secesión.'),
    ('Invención del Teléfono (Alexander Graham Bell)', 1876, 'Revolución en las telecomunicaciones.'),
    ('Invención de la Bombilla (Thomas Edison)', 1879, 'Inicio de la era de la iluminación eléctrica.'),
    ('Primeros Juegos Olímpicos Modernos (Atenas)', 1896, 'Renacimiento del espíritu olímpico.'),
    ('Primer Vuelo de los Hermanos Wright', 1903, 'Inicio de la aviación moderna.'),
    ('Hundimiento del Titanic', 1912, 'Tragedia marítima en el Atlántico Norte.'),
    ('Inicio de la Primera Guerra Mundial', 1914, 'La Gran Guerra.'),
    ('Revolución Rusa', 1917, 'Caída de los zares y ascenso de los bolcheviques.'),
    ('Inicio de la Segunda Guerra Mundial', 1939, 'Invasión de Polonia.'),
    ('Bombardeo Atómico de Hiroshima', 1945, 'Primer uso de armas nucleares en guerra.'),
    ('Fin de la Segunda Guerra Mundial', 1945, 'Rendición de Japón.'),
    ('Fundación de la ONU', 1945, 'Creación de las Naciones Unidas.'),
    ('Lanzamiento del Sputnik 1', 1957, 'Inicio de la era espacial.'),
    ('Crisis de los Misiles en Cuba', 1962, 'Punto crítico de la Guerra Fría.'),
    ('Asesinato de John F. Kennedy', 1963, 'Muerte del presidente en Dallas.'),
    ('Primer Transplante de Corazón (Barnard)', 1967, 'Hito en la medicina moderna.'),
    ('Llegada del Hombre a la Luna', 1969, 'Misión Apolo 11.'),
    ('Invención de la Internet (TCP/IP)', 1983, 'Protocolo base de la red global.'),
    ('Desastre de Chernóbil', 1986, 'Peor accidente nuclear de la historia.'),
    ('Caída del Muro de Berlín', 1989, 'Símbolo del fin de la Guerra Fría.'),
    ('Nelson Mandela liberado', 1990, 'Hacia el fin del Apartheid en Sudáfrica.'),
    ('Disolución de la Unión Soviética', 1991, 'Fin del bloque socialista.'),
    ('Lanzamiento de la World Wide Web (CERN)', 1990, 'Puesta en marcha pública de la Web.'),
    ('Lanzamiento de Windows 95', 1995, 'Masificación del uso de computadoras.'),
    ('Fundación de Google', 1998, 'Revolución en las búsquedas en internet.'),
    ('Ataques del 11 de Septiembre', 2001, 'Atentados contra las Torres Gemelas.'),
    ('Lanzamiento de Facebook', 2004, 'Masificación de las redes sociales.'),
    ('Lanzamiento del Primer iPhone', 2007, 'Revolución de los smartphones.'),
    ('Crisis Financiera Global', 2008, 'Caída de Lehman Brothers.'),
    -- Nuevos eventos para más versatilidad
    ('Construcción de Stonehenge', -3100, 'Monumento megalítico en Inglaterra.'),
    ('Fundación de la Biblioteca de Alejandría', -300, 'Gran centro del saber antiguo.'),
    ('Erupción del Vesubio (Pompeya)', 79, 'Destrucción de la ciudad romana.'),
    ('Coronación de Carlomagno', 800, 'Primer emperador del Sacro Imperio Romano Germánico.'),
    ('Cisma de Oriente', 1054, 'División entre la Iglesia Católica y la Ortodoxa.'),
    ('Viajes de Marco Polo a China', 1271, 'Exploración de la Ruta de la Seda.'),
    ('Expulsión de los Judíos de España', 1492, 'Decreto de los Reyes Católicos.'),
    ('Publicación de Don Quijote de la Mancha', 1605, 'Obra maestra de Miguel de Cervantes.'),
    ('Incendio de Londres', 1666, 'Gran fuego que destruyó la city londinense.'),
    ('Independencia de México', 1810, 'Grito de Dolores e inicio de la insurgencia.'),
    ('Apertura del Canal de Suez', 1869, 'Conexión entre el Mediterráneo y el Mar Rojo.'),
    ('Invención del Cine (Hermanos Lumière)', 1895, 'Primera proyección pública en París.'),
    ('Premio Nobel de Marie Curie (Física)', 1903, 'Primera mujer en ganar un Nobel.'),
    ('Inauguración del Canal de Panamá', 1914, 'Hito de la ingeniería moderna.'),
    ('Descubrimiento de la Penicilina (Fleming)', 1928, 'Inicio de la era de los antibióticos.'),
    ('Lanzamiento del Telescopio Hubble', 1990, 'Nueva ventana al universo profundo.'),
    ('Secuenciación del Genoma Humano', 2003, 'Mapa completo del ADN humano.'),
    ('Primera Imagen de un Agujero Negro', 2019, 'Hito en la astrofísica moderna.'),
    ('Pandemia de COVID-19', 2020, 'Crisis sanitaria global.')
ON CONFLICT (event_name) DO UPDATE SET
    year = EXCLUDED.year,
    description = EXCLUDED.description;
