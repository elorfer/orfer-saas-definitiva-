/// Contextos de reproducción para diferentes tipos de contenido
/// Similar al sistema de Spotify para manejar diferentes fuentes de música
library;

import 'dart:math' as math;
import 'shuffle_optimizer.dart';

/// Tipos de contexto de reproducción
enum PlaybackContextType {
  /// Canciones destacadas individuales con siguiente automática
  featuredSongs,
  /// Playlist completa con reproducción secuencial
  playlist,
  /// Todas las canciones de un artista destacado
  featuredArtist,
  /// Álbum completo
  album,
  /// Cola de reproducción personalizada
  queue,
}

/// Extensión para obtener información adicional del tipo de contexto
extension PlaybackContextTypeExtension on PlaybackContextType {
  /// Nombre legible del tipo de contexto
  String get displayName {
    switch (this) {
      case PlaybackContextType.featuredSongs:
        return 'Canciones Destacadas';
      case PlaybackContextType.playlist:
        return 'Playlist';
      case PlaybackContextType.featuredArtist:
        return 'Artista';
      case PlaybackContextType.album:
        return 'Álbum';
      case PlaybackContextType.queue:
        return 'Cola de Reproducción';
    }
  }

  /// Si este tipo de contexto soporta shuffle
  bool get supportsShuffleMode {
    switch (this) {
      case PlaybackContextType.featuredSongs:
        return false; // Las destacadas usan algoritmo de recomendación
      case PlaybackContextType.playlist:
      case PlaybackContextType.featuredArtist:
      case PlaybackContextType.album:
      case PlaybackContextType.queue:
        return true;
    }
  }

  /// Si este tipo de contexto soporta repetición
  bool get supportsRepeatMode {
    switch (this) {
      case PlaybackContextType.featuredSongs:
        return false; // Las destacadas son infinitas
      case PlaybackContextType.playlist:
      case PlaybackContextType.featuredArtist:
      case PlaybackContextType.album:
      case PlaybackContextType.queue:
        return true;
    }
  }
}

/// Contexto de reproducción que define cómo se debe comportar el reproductor
class PlaybackContext {
  final PlaybackContextType type;
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final List<String> songIds;
  final int currentIndex;
  final bool shuffle;
  final bool repeat;
  
  /// Historial de reproducción para shuffle (evita repetir canciones recientes)
  final List<int> _shuffleHistory;
  
  /// Semilla para el generador de números aleatorios (para shuffle consistente)
  final int? _shuffleSeed;

  const PlaybackContext({
    required this.type,
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.songIds,
    this.currentIndex = 0,
    this.shuffle = false,
    this.repeat = false,
    List<int>? shuffleHistory,
    int? shuffleSeed,
  }) : _shuffleHistory = shuffleHistory ?? const [],
       _shuffleSeed = shuffleSeed,
       assert(currentIndex >= 0, 'currentIndex debe ser mayor o igual a 0');

  /// Crear contexto para canciones destacadas
  factory PlaybackContext.featuredSongs({
    required String currentSongId,
    String? name,
  }) {
    // Validar que el ID de la canción no esté vacío
    if (currentSongId.trim().isEmpty) {
      throw ArgumentError('currentSongId no puede estar vacío');
    }
    
    return PlaybackContext(
      type: PlaybackContextType.featuredSongs,
      id: 'featured_songs',
      name: name ?? 'Canciones Destacadas',
      description: 'Reproducción de canciones destacadas con siguiente automática',
      songIds: [currentSongId], // Solo la canción actual, las siguientes se obtienen dinámicamente
    );
  }

  /// Crear contexto para playlist
  factory PlaybackContext.playlist({
    required String playlistId,
    required String name,
    String? description,
    String? imageUrl,
    required List<String> songIds,
    int startIndex = 0,
    bool shuffle = false,
    bool repeat = false,
  }) {
    // Validaciones
    if (playlistId.trim().isEmpty) {
      throw ArgumentError('playlistId no puede estar vacío');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError('name no puede estar vacío');
    }
    if (songIds.isEmpty) {
      throw ArgumentError('songIds no puede estar vacío para playlists');
    }
    if (startIndex < 0 || startIndex >= songIds.length) {
      throw ArgumentError('startIndex debe estar entre 0 y ${songIds.length - 1}');
    }
    
    return PlaybackContext(
      type: PlaybackContextType.playlist,
      id: playlistId,
      name: name,
      description: description,
      imageUrl: imageUrl,
      songIds: List.unmodifiable(songIds), // Lista inmutable para evitar modificaciones accidentales
      currentIndex: startIndex,
      shuffle: shuffle,
      repeat: repeat,
      shuffleSeed: shuffle ? DateTime.now().millisecondsSinceEpoch : null,
    );
  }

  /// Crear contexto para artista destacado
  factory PlaybackContext.featuredArtist({
    required String artistId,
    required String artistName,
    String? imageUrl,
    required List<String> songIds,
    int startIndex = 0,
    bool shuffle = false,
  }) {
    // Validaciones
    if (artistId.trim().isEmpty) {
      throw ArgumentError('artistId no puede estar vacío');
    }
    if (artistName.trim().isEmpty) {
      throw ArgumentError('artistName no puede estar vacío');
    }
    if (songIds.isEmpty) {
      throw ArgumentError('songIds no puede estar vacío para artistas');
    }
    if (startIndex < 0 || startIndex >= songIds.length) {
      throw ArgumentError('startIndex debe estar entre 0 y ${songIds.length - 1}');
    }
    
    return PlaybackContext(
      type: PlaybackContextType.featuredArtist,
      id: artistId,
      name: artistName,
      description: 'Todas las canciones de $artistName',
      imageUrl: imageUrl,
      songIds: List.unmodifiable(songIds),
      currentIndex: startIndex,
      shuffle: shuffle,
      repeat: false, // Por defecto no repetir artistas
      shuffleSeed: shuffle ? DateTime.now().millisecondsSinceEpoch : null,
    );
  }

  /// Crear contexto para álbum
  factory PlaybackContext.album({
    required String albumId,
    required String albumName,
    String? artistName,
    String? imageUrl,
    required List<String> songIds,
    int startIndex = 0,
  }) {
    // Validaciones
    if (albumId.trim().isEmpty) {
      throw ArgumentError('albumId no puede estar vacío');
    }
    if (albumName.trim().isEmpty) {
      throw ArgumentError('albumName no puede estar vacío');
    }
    if (songIds.isEmpty) {
      throw ArgumentError('songIds no puede estar vacío para álbumes');
    }
    if (startIndex < 0 || startIndex >= songIds.length) {
      throw ArgumentError('startIndex debe estar entre 0 y ${songIds.length - 1}');
    }
    
    return PlaybackContext(
      type: PlaybackContextType.album,
      id: albumId,
      name: albumName,
      description: artistName != null ? 'Álbum de $artistName' : null,
      imageUrl: imageUrl,
      songIds: List.unmodifiable(songIds),
      currentIndex: startIndex,
      shuffle: false, // Álbumes se reproducen en orden por defecto
      repeat: false,
    );
  }

  /// Copiar contexto con nuevos valores
  PlaybackContext copyWith({
    PlaybackContextType? type,
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    List<String>? songIds,
    int? currentIndex,
    bool? shuffle,
    bool? repeat,
    List<int>? shuffleHistory,
    int? shuffleSeed,
  }) {
    final newSongIds = songIds ?? this.songIds;
    final newCurrentIndex = currentIndex ?? this.currentIndex;
    
    // Validar que el nuevo índice sea válido
    if (newSongIds.isNotEmpty && (newCurrentIndex < 0 || newCurrentIndex >= newSongIds.length)) {
      throw ArgumentError('currentIndex debe estar entre 0 y ${newSongIds.length - 1}');
    }
    
    return PlaybackContext(
      type: type ?? this.type,
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      songIds: newSongIds,
      currentIndex: newCurrentIndex,
      shuffle: shuffle ?? this.shuffle,
      repeat: repeat ?? this.repeat,
      shuffleHistory: shuffleHistory ?? _shuffleHistory,
      shuffleSeed: shuffleSeed ?? _shuffleSeed,
    );
  }

  /// Obtener siguiente índice según el contexto
  int? getNextIndex() {
    // Validar que hay canciones disponibles
    if (songIds.isEmpty && type != PlaybackContextType.featuredSongs) {
      return null;
    }
    
    switch (type) {
      case PlaybackContextType.featuredSongs:
        // Para canciones destacadas, no hay siguiente en la lista
        // Se obtiene dinámicamente mediante el algoritmo de recomendación
        return null;
      
      case PlaybackContextType.playlist:
      case PlaybackContextType.featuredArtist:
      case PlaybackContextType.album:
      case PlaybackContextType.queue:
        if (shuffle) {
          return _getNextShuffleIndex();
        } else {
          final nextIndex = currentIndex + 1;
          if (nextIndex < songIds.length) {
            return nextIndex;
          } else if (repeat) {
            return 0; // Volver al inicio
          } else {
            return null; // Fin de la lista
          }
        }
    }
  }

  /// Obtener siguiente índice en modo shuffle (MEJORADO 🎯)
  int? _getNextShuffleIndex() {
    if (songIds.length <= 1) {
      return repeat ? 0 : null;
    }
    
    // Crear generador de números aleatorios con semilla consistente
    final random = _shuffleSeed != null 
        ? math.Random(_shuffleSeed! + _shuffleHistory.length)
        : math.Random();
    
    // Si hemos reproducido todas las canciones, reiniciar si repeat está activado
    if (_shuffleHistory.length >= songIds.length - 1) { // -1 porque no contamos la actual
      if (repeat) {
        // Reiniciar historial pero mantener la canción actual fuera del próximo ciclo
        return _getRandomIndexExcluding([currentIndex], random);
      } else {
        return null; // Fin del shuffle
      }
    }
    
    // Obtener índices ya reproducidos + índice actual
    final excludedIndices = [..._shuffleHistory, currentIndex];
    
    // Validar que tenemos opciones disponibles
    if (excludedIndices.length >= songIds.length) {
      // Si no hay opciones, reiniciar o terminar
      return repeat ? _getRandomIndexExcluding([currentIndex], random) : null;
    }
    
    return _getRandomIndexExcluding(excludedIndices, random);
  }

  /// Obtener índice aleatorio excluyendo ciertos índices (OPTIMIZADO 🚀)
  int? _getRandomIndexExcluding(List<int> excludedIndices, math.Random random) {
    // Usar algoritmo optimizado: O(1) para listas grandes vs O(n) original
    return ShuffleOptimizer.getRandomIndex(songIds.length, excludedIndices, random);
  }

  /// Obtener índice anterior según el contexto
  int? getPreviousIndex() {
    // Validar que hay canciones disponibles
    if (songIds.isEmpty && type != PlaybackContextType.featuredSongs) {
      return null;
    }
    
    switch (type) {
      case PlaybackContextType.featuredSongs:
        // Para canciones destacadas, no hay anterior en la lista
        return null;
      
      case PlaybackContextType.playlist:
      case PlaybackContextType.featuredArtist:
      case PlaybackContextType.album:
      case PlaybackContextType.queue:
        if (shuffle) {
          return _getPreviousShuffleIndex();
        } else {
          final prevIndex = currentIndex - 1;
          if (prevIndex >= 0) {
            return prevIndex;
          } else if (repeat) {
            return songIds.length - 1; // Ir al final
          } else {
            return null; // Inicio de la lista
          }
        }
    }
  }

  /// Obtener índice anterior en modo shuffle usando el historial
  int? _getPreviousShuffleIndex() {
    if (songIds.length <= 1) {
      return repeat ? 0 : null;
    }
    
    // Si hay historial, devolver el último índice reproducido
    if (_shuffleHistory.isNotEmpty) {
      return _shuffleHistory.last;
    }
    
    // Si no hay historial y repeat está activado, ir al final
    if (repeat) {
      return songIds.length - 1;
    }
    
    return null;
  }

  /// Verificar si puede avanzar automáticamente
  bool get canAutoAdvance {
    switch (type) {
      case PlaybackContextType.featuredSongs:
        return true; // Siempre puede buscar siguiente destacada
      case PlaybackContextType.playlist:
      case PlaybackContextType.featuredArtist:
      case PlaybackContextType.album:
      case PlaybackContextType.queue:
        return getNextIndex() != null;
    }
  }

  /// Verificar si puede retroceder
  bool get canGoPrevious {
    switch (type) {
      case PlaybackContextType.featuredSongs:
        return false; // Las destacadas no tienen historial
      case PlaybackContextType.playlist:
      case PlaybackContextType.featuredArtist:
      case PlaybackContextType.album:
      case PlaybackContextType.queue:
        return getPreviousIndex() != null;
    }
  }

  /// Obtener el ID de la canción actual
  String? get currentSongId {
    if (songIds.isEmpty || currentIndex < 0 || currentIndex >= songIds.length) {
      return null;
    }
    return songIds[currentIndex];
  }

  /// Obtener el número total de canciones
  int get totalSongs => songIds.length;

  /// Verificar si el contexto está vacío
  bool get isEmpty => songIds.isEmpty && type != PlaybackContextType.featuredSongs;

  /// Verificar si el contexto es válido
  bool get isValid {
    try {
      // Verificar campos requeridos
      if (id.trim().isEmpty || name.trim().isEmpty) {
        return false;
      }
      
      // Para contextos que no sean destacadas, debe haber canciones
      if (type != PlaybackContextType.featuredSongs && songIds.isEmpty) {
        return false;
      }
      
      // El índice actual debe ser válido
      if (songIds.isNotEmpty && (currentIndex < 0 || currentIndex >= songIds.length)) {
        return false;
      }
      
      // Verificar que shuffle y repeat sean compatibles con el tipo
      if (shuffle && !type.supportsShuffleMode) {
        return false;
      }
      
      if (repeat && !type.supportsRepeatMode) {
        return false;
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Crear una nueva instancia con el índice actualizado y historial de shuffle
  PlaybackContext moveToIndex(int newIndex) {
    if (newIndex < 0 || newIndex >= songIds.length) {
      throw ArgumentError('Índice $newIndex fuera de rango [0, ${songIds.length - 1}]');
    }
    
    // Actualizar historial de shuffle si está activado
    List<int> newHistory = List.from(_shuffleHistory);
    if (shuffle && newIndex != currentIndex) {
      // Agregar el índice actual al historial
      if (!newHistory.contains(currentIndex)) {
        newHistory.add(currentIndex);
      }
      
      // Mantener el historial limitado para evitar uso excesivo de memoria
      const maxHistorySize = 50;
      if (newHistory.length > maxHistorySize) {
        newHistory = newHistory.sublist(newHistory.length - maxHistorySize);
      }
    }
    
    return copyWith(
      currentIndex: newIndex,
      shuffleHistory: newHistory,
    );
  }

  /// Reiniciar el historial de shuffle (útil cuando se reactiva shuffle)
  PlaybackContext resetShuffleHistory() {
    return copyWith(
      shuffleHistory: <int>[],
      shuffleSeed: shuffle ? DateTime.now().millisecondsSinceEpoch : _shuffleSeed,
    );
  }

  /// Obtener información de progreso (canción X de Y)
  String get progressInfo {
    if (type == PlaybackContextType.featuredSongs) {
      return 'Reproducción continua';
    }
    
    if (songIds.isEmpty) {
      return 'Sin canciones';
    }
    
    return '${currentIndex + 1} de ${songIds.length}';
  }

  /// Descripción legible del contexto
  String get displayDescription {
    final baseDescription = switch (type) {
      PlaybackContextType.featuredSongs => 'Canciones destacadas',
      PlaybackContextType.playlist => 'Playlist • $name',
      PlaybackContextType.featuredArtist => 'Artista • $name',
      PlaybackContextType.album => 'Álbum • $name',
      PlaybackContextType.queue => 'Cola de reproducción',
    };
    
    // Agregar información de modo si está activado
    final modes = <String>[];
    if (shuffle && type.supportsShuffleMode) modes.add('Aleatorio');
    if (repeat && type.supportsRepeatMode) modes.add('Repetir');
    
    if (modes.isNotEmpty) {
      return '$baseDescription • ${modes.join(' • ')}';
    }
    
    return baseDescription;
  }

  @override
  String toString() {
    final modes = <String>[];
    if (shuffle) modes.add('shuffle');
    if (repeat) modes.add('repeat');
    final modeStr = modes.isNotEmpty ? ' [${modes.join(', ')}]' : '';
    
    return 'PlaybackContext(type: $type, id: $id, name: $name, songs: ${songIds.length}, index: $currentIndex$modeStr)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlaybackContext &&
        other.type == type &&
        other.id == id &&
        other.currentIndex == currentIndex &&
        other.shuffle == shuffle &&
        other.repeat == repeat;
  }

  @override
  int get hashCode {
    return Object.hash(
      type,
      id,
      currentIndex,
      shuffle,
      repeat,
    );
  }

  /// Convertir a Map para serialización
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'id': id,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'songIds': songIds,
      'currentIndex': currentIndex,
      'shuffle': shuffle,
      'repeat': repeat,
      'shuffleHistory': _shuffleHistory,
      'shuffleSeed': _shuffleSeed,
    };
  }

  /// Crear desde Map para deserialización
  factory PlaybackContext.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String;
    final type = PlaybackContextType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => throw ArgumentError('Tipo de contexto desconocido: $typeStr'),
    );
    
    return PlaybackContext(
      type: type,
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      songIds: List<String>.from(json['songIds'] as List),
      currentIndex: json['currentIndex'] as int? ?? 0,
      shuffle: json['shuffle'] as bool? ?? false,
      repeat: json['repeat'] as bool? ?? false,
      shuffleHistory: json['shuffleHistory'] != null 
          ? List<int>.from(json['shuffleHistory'] as List)
          : null,
      shuffleSeed: json['shuffleSeed'] as int?,
    );
  }
}

