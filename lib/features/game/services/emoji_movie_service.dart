import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:map_hunter/features/game/models/emoji_movie_problem.dart';

class EmojiMovieService {
  final SupabaseClient _supabase;

  EmojiMovieService(this._supabase);

  static const List<EmojiMovieProblem> _fallbackMovies = [
    EmojiMovieProblem(emojis: "🦁👑", validAnswers: ["El Rey León", "The Lion King"]),
    EmojiMovieProblem(emojis: "🚢🧊", validAnswers: ["Titanic"]),
    EmojiMovieProblem(emojis: "🕷️🕸️", validAnswers: ["Spider-Man", "El Hombre Araña"]),
    EmojiMovieProblem(emojis: "🤡🃏", validAnswers: ["Joker", "El Bromista"]),
    EmojiMovieProblem(emojis: "🎈🏠", validAnswers: ["Up", "Up: Una aventura de altura"]),
    EmojiMovieProblem(emojis: "🐠🌊", validAnswers: ["Buscando a Nemo", "Finding Nemo"]),
    EmojiMovieProblem(emojis: "🤠🚀", validAnswers: ["Toy Story"]),
    EmojiMovieProblem(emojis: "🕶️💊", validAnswers: ["Matrix", "The Matrix"]),
    EmojiMovieProblem(emojis: "⚔️🌌", validAnswers: ["Star Wars", "La Guerra de las Galaxias"]),
    EmojiMovieProblem(emojis: "🦖🌴", validAnswers: ["Jurassic Park", "Parque Jurásico"]),
    EmojiMovieProblem(emojis: "🦇🌃", validAnswers: ["Batman", "El Caballero de la Noche"]),
    EmojiMovieProblem(emojis: "❄️🏰", validAnswers: ["Frozen"]),
    EmojiMovieProblem(emojis: "🌊⛵", validAnswers: ["Moana"]),
    EmojiMovieProblem(emojis: "🧞‍♂️🌳", validAnswers: ["Avatar"]),
    EmojiMovieProblem(emojis: "⚡👓", validAnswers: ["Harry Potter"]),
    EmojiMovieProblem(emojis: "🏎️🔥", validAnswers: ["Rápido y Furioso", "Fast & Furious"]),
    EmojiMovieProblem(emojis: "👻🚫", validAnswers: ["Los Cazafantasmas", "Ghostbusters"]),
    EmojiMovieProblem(emojis: "🏴‍☠️🛳️", validAnswers: ["Piratas del Caribe", "Pirates of the Caribbean"]),
    EmojiMovieProblem(emojis: "🌀💤", validAnswers: ["Inception", "El Origen"]),
    EmojiMovieProblem(emojis: "👹🏰", validAnswers: ["Shrek"]),
    EmojiMovieProblem(emojis: "🏜️🚘", validAnswers: ["Mad Max"]),
    EmojiMovieProblem(emojis: "🏐🏝️", validAnswers: ["Náufrago", "Cast Away"]),
    EmojiMovieProblem(emojis: "🦈🏊", validAnswers: ["Tiburón", "Jaws"]),
    EmojiMovieProblem(emojis: "🚿🔪", validAnswers: ["Psicosis", "Psycho"]),
    EmojiMovieProblem(emojis: "🔫🍔", validAnswers: ["Pulp Fiction"]),
    EmojiMovieProblem(emojis: "🏃🍫", validAnswers: ["Forrest Gump"]),
    EmojiMovieProblem(emojis: "👽🚀", validAnswers: ["Alien"]),
    EmojiMovieProblem(emojis: "⚔️🛡️", validAnswers: ["Gladiador", "Gladiator"]),
    EmojiMovieProblem(emojis: "🐆👑", validAnswers: ["Black Panther", "Pantera Negra"]),
    EmojiMovieProblem(emojis: "🦸‍♂️🦸‍♀️", validAnswers: ["The Avengers", "Los Vengadores"]),
    EmojiMovieProblem(emojis: "🐀👨‍🍳", validAnswers: ["Ratatouille"]),
    EmojiMovieProblem(emojis: "🎸💀", validAnswers: ["Coco"]),
    EmojiMovieProblem(emojis: "🧠✨", validAnswers: ["Intensa-Mente", "Inside Out"]),
    EmojiMovieProblem(emojis: "🎩🌹", validAnswers: ["El Padrino", "The Godfather"]),
    EmojiMovieProblem(emojis: "👩‍🦰🗡️", validAnswers: ["Kill Bill"]),
    EmojiMovieProblem(emojis: "🏠🪜", validAnswers: ["Parasite", "Parásitos"]),
    EmojiMovieProblem(emojis: "🦸‍♂️⚡💨", validAnswers: ["The Incredibles", "Los Increíbles"]),
    EmojiMovieProblem(emojis: "👤🟡🍌", validAnswers: ["Mi Villano Favorito", "Despicable Me"]),
    EmojiMovieProblem(emojis: "🐼🥋🥟", validAnswers: ["Kung Fu Panda"]),
    EmojiMovieProblem(emojis: "👹🚪👧", validAnswers: ["Monsters Inc", "Monsters, Inc."]),
    EmojiMovieProblem(emojis: "🐟🌊❓", validAnswers: ["Buscando a Dory", "Finding Dory"]),
    EmojiMovieProblem(emojis: "🤖🌱🚀", validAnswers: ["Wall-E", "Wall-E"]),
    EmojiMovieProblem(emojis: "🌹👹👸", validAnswers: ["La Bella y la Bestia", "Beauty and the Beast"]),
    EmojiMovieProblem(emojis: "🧞‍♂️🕌✨", validAnswers: ["Aladdin", "Aladino"]),
    EmojiMovieProblem(emojis: "👠🎃🏰", validAnswers: ["Cinderella", "Cenicienta"]),
    EmojiMovieProblem(emojis: "🧜‍♀️🐚🌊", validAnswers: ["La Sirenita", "The Little Mermaid"]),
    EmojiMovieProblem(emojis: "🐉🏮⚔️", validAnswers: ["Mulan", "Mulán"]),
    EmojiMovieProblem(emojis: "🏹🐻🌲", validAnswers: ["Brave", "Valiente"]),
    EmojiMovieProblem(emojis: "🐲👦⚔️", validAnswers: ["Cómo entrenar a tu dragón", "How to Train Your Dragon"]),
    EmojiMovieProblem(emojis: "🦁❄️🚪", validAnswers: ["Las Crónicas de Narnia", "The Chronicles of Narnia"]),
    EmojiMovieProblem(emojis: "☂️👜🎶", validAnswers: ["Mary Poppins"]),
    EmojiMovieProblem(emojis: "🏔️🎶👧", validAnswers: ["La Novicia Rebelde", "The Sound of Music"]),
    EmojiMovieProblem(emojis: "☔💃🎶", validAnswers: ["Cantando bajo la lluvia", "Singin' in the Rain"]),
    EmojiMovieProblem(emojis: "👠🌪️🦁", validAnswers: ["El Mago de Oz", "The Wizard of Oz"]),
    EmojiMovieProblem(emojis: "🏭🍫🎩", validAnswers: ["Charlie y la Fábrica de Chocolate", "Charlie and the Chocolate Factory"]),
    EmojiMovieProblem(emojis: "🐰🍵🃏", validAnswers: ["Alicia en el país de las maravillas", "Alice in Wonderland"]),
  ];

  /// Fetches a list of random movies from the database and merges with fallback list.
  Future<List<EmojiMovieProblem>> fetchAllMovies() async {
    List<EmojiMovieProblem> dbMovies = [];
    try {
      final response = await _supabase
          .from('minigame_emoji_movies')
          .select('emojis, valid_answers');

      final List<dynamic> data = response;
      dbMovies = data.map((json) {
        return EmojiMovieProblem(
          emojis: json['emojis'] as String,
          validAnswers: List<String>.from(json['valid_answers'] as List),
        );
      }).toList();
    } catch (e) {
      print("Error fetching emoji movies from DB: $e");
    }

    // Merge lists, avoid exact duplicates by emojis
    final allMovies = [...dbMovies];
    for (var fallback in _fallbackMovies) {
      if (!allMovies.any((m) => m.emojis == fallback.emojis)) {
        allMovies.add(fallback);
      }
    }

    return allMovies;
  }
}
