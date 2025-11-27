/// Versión optimizada del contexto de reproducción
/// Mejoras: Performance, memoria, algoritmos y arquitectura
library;

import 'dart:math' as math;

/// Tipos de contexto de reproducción (sin cambios)
enum PlaybackContextType {
  featuredSongs,
  playlist,
  featuredArtist,
  album,
  queue,
}

/// Extensión optimizada con cache de propiedades
extension PlaybackContextTypeExtension on PlaybackContextType {
  static final Map<PlaybackContextType, String> _displayNameCache = {
    PlaybackContextType.featuredSongs: 'Canciones Destacadas',
    PlaybackContextType.playlist: 'Playlist',
    PlaybackContextType.featuredArtist: 'Artista',
    PlaybackContextType.album: 'Álbum',
    PlaybackContextType.queue: 'Cola de Reproducción',
  };

  static final Map<PlaybackContextType, bool> _shuffleSupportCache = {
    PlaybackContextType.featuredSongs: false,
    PlaybackContextType.playlist: true,
    PlaybackContextType.featuredArtist: true,
    PlaybackContextType.album: true,
    PlaybackContextType.queue: true,
  };

  static final Map<PlaybackContextType, bool> _repeatSupportCache = {
    PlaybackContextType.featuredSongs: false,
    PlaybackContextType.playlist: true,
    PlaybackContextType.featuredArtist: true,
    PlaybackContextType.album: true,
    PlaybackContextType.queue: true,
  };

  String get displayName => _displayNameCache[this]!;
  bool get supportsShuffleMode => _shuffleSupportCache[this]!;
  bool get supportsRepeatMode => _repeatSupportCache[this]!;
}

/// Gestión optimizada del historial de shuffle
class ShuffleHistory {
  static const int _maxHistorySize = 50;
  static const int _defaultHistorySize = 10;

  final List<int> _history;
  final int _maxSize;

  ShuffleHistory._(this._history, this._maxSize);

  factory ShuffleHistory({int maxSize = _defaultHistorySize}) {
    return ShuffleHistory._([], math.min(maxSize, _maxHistorySize));
  }

  factory ShuffleHistory.fromList(List<int> history, {int maxSize = _defaultHistorySize}) {
    final trimmedHistory = history.length > maxSize 
        ? history.sublist(history.length - maxSize)
        : List<int>.from(history);
    return ShuffleHistory._(trimmedHistory, maxSize);
  }

  void add(int index) {
    if (_history.contains(index)) return;
    
    _history.add(index);
    if (_history.length > _maxSize) {
      _history.removeAt(0);
    }
  }

  bool contains(int index) => _history.contains(index);
  int get length => _history.length;
  bool get isEmpty => _history.isEmpty;
  bool get isNotEmpty => _history.isNotEmpty;
  int? get last => _history.isEmpty ? null : _history.last;
  List<int> get items => List.unmodifiable(_history);

  void clear() => _history.clear();

  ShuffleHistory copy() => ShuffleHistory.fromList(_history, maxSize: _maxSize);
}

/// Generador optimizado de índices aleatorios
class ShuffleGenerator {
  final math.Random _random;

  ShuffleGenerator(int? seed) : _random = seed != null ? math.Random(seed) : math.Random();

  /// Genera índice aleatorio excluyendo ciertos valores (optimizado)
  int? getRandomIndex(int totalItems, List<int> excludedIndices) {
    if (totalItems <= 0) return null;
    if (excludedIndices.length >= totalItems) return null;

    // Para listas pequeñas, usar algoritmo directo
    if (totalItems <= 20) {
      return _getRandomIndexDirect(totalItems, excludedIndices);
    }

    // Para listas grandes, usar algoritmo optimizado
    return _getRandomIndexOptimized(totalItems, excludedIndices);
  }

  int? _getRandomIndexDirect(int totalItems, List<int> excludedIndices) {
    final availableIndices = <int>[];
    for (int i = 0; i < totalItems; i++) {
      if (!excludedIndices.contains(i)) {
        availableIndices.add(i);
      }
    }
    
    if (availableIndices.isEmpty) return null;
    return availableIndices[_random.nextInt(availableIndices.length)];
  }

  int? _getRandomIndexOptimized(int totalItems, List<int> excludedIndices) {
    // Usar sampling rejection para listas grandes
    const maxAttempts = 50;
    final excludedSet = Set<int>.from(excludedIndices);
    
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final candidate = _random.nextInt(totalItems);
      if (!excludedSet.contains(candidate)) {
        return candidate;
      }
    }
    
    // Fallback al método directo si no encontramos en maxAttempts
    return _getRandomIndexDirect(totalItems, excludedIndices);
  }
}

/// Contexto de reproducción optimizado
class PlaybackContextOptimized {
  // Propiedades inmutables
  final PlaybackContextType type;
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final List<String> songIds;
  final int currentIndex;
  final bool shuffle;
  final bool repeat;
  
  // Componentes optimizados
  final ShuffleHistory _shuffleHistory;
  final ShuffleGenerator? _shuffleGenerator;
  
  // Cache de propiedades calculadas (no final para permitir lazy loading)
  String? _cachedProgressInfo;
  String? _cachedDisplayDescription;
  bool? _cachedIsValid;
  int? _cachedHashCode;

  PlaybackContextOptimized._({
    required this.type,
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.songIds,
    this.currentIndex = 0,
    this.shuffle = false,
    this.repeat = false,
    required ShuffleHistory shuffleHistory,
    ShuffleGenerator? shuffleGenerator,
  }) : _shuffleHistory = shuffleHistory,
       _shuffleGenerator = shuffleGenerator;

  /// Factory optimizado para canciones destacadas
  factory PlaybackContextOptimized.featuredSongs({
    required String currentSongId,
    String? name,
  }) {
    if (currentSongId.trim().isEmpty) {
      throw ArgumentError('currentSongId no puede estar vacío');
    }
    
    return PlaybackContextOptimized._(
      type: PlaybackContextType.featuredSongs,
      id: 'featured_songs',
      name: name ?? 'Canciones Destacadas',
      description: 'Reproducción de canciones destacadas con siguiente automática',
      songIds: [currentSongId],
      shuffleHistory: ShuffleHistory(),
    );
  }

  /// Factory optimizado para playlist
  factory PlaybackContextOptimized.playlist({
    required String playlistId,
    required String name,
    String? description,
    String? imageUrl,
    required List<String> songIds,
    int startIndex = 0,
    bool shuffle = false,
    bool repeat = false,
  }) {
    _validatePlaylistParams(playlistId, name, songIds, startIndex);
    
    final shuffleGenerator = shuffle 
        ? ShuffleGenerator(DateTime.now().millisecondsSinceEpoch)
        : null;
    
    return PlaybackContextOptimized._(
      type: PlaybackContextType.playlist,
      id: playlistId,
      name: name,
      description: description,
      imageUrl: imageUrl,
      songIds: List.unmodifiable(songIds),
      currentIndex: startIndex,
      shuffle: shuffle,
      repeat: repeat,
      shuffleHistory: ShuffleHistory(),
      shuffleGenerator: shuffleGenerator,
    );
  }

  /// Factory optimizado para artista
  factory PlaybackContextOptimized.featuredArtist({
    required String artistId,
    required String artistName,
    String? imageUrl,
    required List<String> songIds,
    int startIndex = 0,
    bool shuffle = false,
  }) {
    _validateArtistParams(artistId, artistName, songIds, startIndex);
    
    final shuffleGenerator = shuffle 
        ? ShuffleGenerator(DateTime.now().millisecondsSinceEpoch)
        : null;
    
    return PlaybackContextOptimized._(
      type: PlaybackContextType.featuredArtist,
      id: artistId,
      name: artistName,
      description: 'Todas las canciones de $artistName',
      imageUrl: imageUrl,
      songIds: List.unmodifiable(songIds),
      currentIndex: startIndex,
      shuffle: shuffle,
      repeat: false,
      shuffleHistory: ShuffleHistory(),
      shuffleGenerator: shuffleGenerator,
    );
  }

  /// Factory optimizado para álbum
  factory PlaybackContextOptimized.album({
    required String albumId,
    required String albumName,
    String? artistName,
    String? imageUrl,
    required List<String> songIds,
    int startIndex = 0,
  }) {
    _validateAlbumParams(albumId, albumName, songIds, startIndex);
    
    return PlaybackContextOptimized._(
      type: PlaybackContextType.album,
      id: albumId,
      name: albumName,
      description: artistName != null ? 'Álbum de $artistName' : null,
      imageUrl: imageUrl,
      songIds: List.unmodifiable(songIds),
      currentIndex: startIndex,
      shuffle: false,
      repeat: false,
      shuffleHistory: ShuffleHistory(),
    );
  }

  /// Validaciones estáticas optimizadas
  static void _validatePlaylistParams(String playlistId, String name, List<String> songIds, int startIndex) {
    if (playlistId.trim().isEmpty) throw ArgumentError('playlistId no puede estar vacío');
    if (name.trim().isEmpty) throw ArgumentError('name no puede estar vacío');
    if (songIds.isEmpty) throw ArgumentError('songIds no puede estar vacío para playlists');
    if (startIndex < 0 || startIndex >= songIds.length) {
      throw ArgumentError('startIndex debe estar entre 0 y ${songIds.length - 1}');
    }
  }

  static void _validateArtistParams(String artistId, String artistName, List<String> songIds, int startIndex) {
    if (artistId.trim().isEmpty) throw ArgumentError('artistId no puede estar vacío');
    if (artistName.trim().isEmpty) throw ArgumentError('artistName no puede estar vacío');
    if (songIds.isEmpty) throw ArgumentError('songIds no puede estar vacío para artistas');
    if (startIndex < 0 || startIndex >= songIds.length) {
      throw ArgumentError('startIndex debe estar entre 0 y ${songIds.length - 1}');
    }
  }

  static void _validateAlbumParams(String albumId, String albumName, List<String> songIds, int startIndex) {
    if (albumId.trim().isEmpty) throw ArgumentError('albumId no puede estar vacío');
    if (albumName.trim().isEmpty) throw ArgumentError('albumName no puede estar vacío');
    if (songIds.isEmpty) throw ArgumentError('songIds no puede estar vacío para álbumes');
    if (startIndex < 0 || startIndex >= songIds.length) {
      throw ArgumentError('startIndex debe estar entre 0 y ${songIds.length - 1}');
    }
  }

  /// CopyWith optimizado (solo crea nuevo objeto si hay cambios)
  PlaybackContextOptimized copyWith({
    PlaybackContextType? type,
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    List<String>? songIds,
    int? currentIndex,
    bool? shuffle,
    bool? repeat,
    ShuffleHistory? shuffleHistory,
    ShuffleGenerator? shuffleGenerator,
  }) {
    // Verificar si realmente hay cambios
    final hasChanges = type != null && type != this.type ||
                      id != null && id != this.id ||
                      name != null && name != this.name ||
                      description != this.description ||
                      imageUrl != this.imageUrl ||
                      songIds != null ||
                      currentIndex != null && currentIndex != this.currentIndex ||
                      shuffle != null && shuffle != this.shuffle ||
                      repeat != null && repeat != this.repeat ||
                      shuffleHistory != null ||
                      shuffleGenerator != null;

    if (!hasChanges) return this;

    final newSongIds = songIds ?? this.songIds;
    final newCurrentIndex = currentIndex ?? this.currentIndex;
    
    // Validar nuevo índice si cambió la lista
    if (newSongIds.isNotEmpty && (newCurrentIndex < 0 || newCurrentIndex >= newSongIds.length)) {
      throw ArgumentError('currentIndex debe estar entre 0 y ${newSongIds.length - 1}');
    }

    // Limpiar cache al crear nueva instancia
    return PlaybackContextOptimized._(
      type: type ?? this.type,
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      songIds: newSongIds,
      currentIndex: newCurrentIndex,
      shuffle: shuffle ?? this.shuffle,
      repeat: repeat ?? this.repeat,
      shuffleHistory: shuffleHistory ?? _shuffleHistory.copy(),
      shuffleGenerator: shuffleGenerator ?? _shuffleGenerator,
    );
  }

  /// Obtener siguiente índice (optimizado)
  int? getNextIndex() {
    if (songIds.isEmpty && type != PlaybackContextType.featuredSongs) {
      return null;
    }
    
    switch (type) {
      case PlaybackContextType.featuredSongs:
        return null; // Se obtiene dinámicamente
      
      case PlaybackContextType.playlist:
      case PlaybackContextType.featuredArtist:
      case PlaybackContextType.album:
      case PlaybackContextType.queue:
        return shuffle ? _getNextShuffleIndex() : _getNextSequentialIndex();
    }
  }

  int? _getNextSequentialIndex() {
    final nextIndex = currentIndex + 1;
    if (nextIndex < songIds.length) {
      return nextIndex;
    } else if (repeat) {
      return 0;
    } else {
      return null;
    }
  }

  int? _getNextShuffleIndex() {
    if (songIds.length <= 1) {
      return repeat ? 0 : null;
    }
    
    if (_shuffleGenerator == null) return null;

    // Si hemos reproducido todas las canciones
    if (_shuffleHistory.length >= songIds.length) {
      if (repeat) {
        _shuffleHistory.clear();
        return _shuffleGenerator!.getRandomIndex(songIds.length, [currentIndex]);
      } else {
        return null;
      }
    }
    
    // Obtener siguiente canción excluyendo historial + actual
    final excludedIndices = [..._shuffleHistory.items, currentIndex];
    return _shuffleGenerator!.getRandomIndex(songIds.length, excludedIndices);
  }

  /// Obtener índice anterior (optimizado)
  int? getPreviousIndex() {
    if (songIds.isEmpty && type != PlaybackContextType.featuredSongs) {
      return null;
    }
    
    switch (type) {
      case PlaybackContextType.featuredSongs:
        return null;
      
      case PlaybackContextType.playlist:
      case PlaybackContextType.featuredArtist:
      case PlaybackContextType.album:
      case PlaybackContextType.queue:
        return shuffle ? _getPreviousShuffleIndex() : _getPreviousSequentialIndex();
    }
  }

  int? _getPreviousSequentialIndex() {
    final prevIndex = currentIndex - 1;
    if (prevIndex >= 0) {
      return prevIndex;
    } else if (repeat) {
      return songIds.length - 1;
    } else {
      return null;
    }
  }

  int? _getPreviousShuffleIndex() {
    if (songIds.length <= 1) {
      return repeat ? 0 : null;
    }
    
    if (_shuffleHistory.isNotEmpty) {
      return _shuffleHistory.last;
    }
    
    if (repeat) {
      return songIds.length - 1;
    }
    
    return null;
  }

  /// Mover a índice (optimizado con actualización de historial)
  PlaybackContextOptimized moveToIndex(int newIndex) {
    if (newIndex < 0 || newIndex >= songIds.length) {
      throw ArgumentError('Índice $newIndex fuera de rango [0, ${songIds.length - 1}]');
    }
    
    if (newIndex == currentIndex) return this;

    // Actualizar historial si shuffle está activado
    final newHistory = _shuffleHistory.copy();
    if (shuffle && !newHistory.contains(currentIndex)) {
      newHistory.add(currentIndex);
    }
    
    return copyWith(
      currentIndex: newIndex,
      shuffleHistory: newHistory,
    );
  }

  /// Reiniciar historial de shuffle
  PlaybackContextOptimized resetShuffleHistory() {
    final newGenerator = shuffle 
        ? ShuffleGenerator(DateTime.now().millisecondsSinceEpoch)
        : null;
    
    return copyWith(
      shuffleHistory: ShuffleHistory(),
      shuffleGenerator: newGenerator,
    );
  }

  /// Propiedades calculadas con cache
  bool get canAutoAdvance {
    switch (type) {
      case PlaybackContextType.featuredSongs:
        return true;
      case PlaybackContextType.playlist:
      case PlaybackContextType.featuredArtist:
      case PlaybackContextType.album:
      case PlaybackContextType.queue:
        return getNextIndex() != null;
    }
  }

  bool get canGoPrevious {
    switch (type) {
      case PlaybackContextType.featuredSongs:
        return false;
      case PlaybackContextType.playlist:
      case PlaybackContextType.featuredArtist:
      case PlaybackContextType.album:
      case PlaybackContextType.queue:
        return getPreviousIndex() != null;
    }
  }

  String? get currentSongId {
    if (songIds.isEmpty || currentIndex < 0 || currentIndex >= songIds.length) {
      return null;
    }
    return songIds[currentIndex];
  }

  int get totalSongs => songIds.length;
  bool get isEmpty => songIds.isEmpty && type != PlaybackContextType.featuredSongs;

  /// Validación con cache
  bool get isValid {
    return _cachedIsValid ??= _computeIsValid();
  }

  bool _computeIsValid() {
    try {
      if (id.trim().isEmpty || name.trim().isEmpty) return false;
      if (type != PlaybackContextType.featuredSongs && songIds.isEmpty) return false;
      if (songIds.isNotEmpty && (currentIndex < 0 || currentIndex >= songIds.length)) return false;
      if (shuffle && !type.supportsShuffleMode) return false;
      if (repeat && !type.supportsRepeatMode) return false;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Información de progreso con cache
  String get progressInfo {
    return _cachedProgressInfo ??= _computeProgressInfo();
  }

  String _computeProgressInfo() {
    if (type == PlaybackContextType.featuredSongs) {
      return 'Reproducción continua';
    }
    
    if (songIds.isEmpty) {
      return 'Sin canciones';
    }
    
    return '${currentIndex + 1} de ${songIds.length}';
  }

  /// Descripción con cache
  String get displayDescription {
    return _cachedDisplayDescription ??= _computeDisplayDescription();
  }

  String _computeDisplayDescription() {
    final baseDescription = switch (type) {
      PlaybackContextType.featuredSongs => 'Canciones destacadas',
      PlaybackContextType.playlist => 'Playlist • $name',
      PlaybackContextType.featuredArtist => 'Artista • $name',
      PlaybackContextType.album => 'Álbum • $name',
      PlaybackContextType.queue => 'Cola de reproducción',
    };
    
    final modes = <String>[];
    if (shuffle && type.supportsShuffleMode) modes.add('Aleatorio');
    if (repeat && type.supportsRepeatMode) modes.add('Repetir');
    
    if (modes.isNotEmpty) {
      return '$baseDescription • ${modes.join(' • ')}';
    }
    
    return baseDescription;
  }

  /// Serialización optimizada
  Map<String, dynamic> toJson() {
    return {
      'version': 2, // Versionado para compatibilidad futura
      'type': type.name,
      'id': id,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'songIds': songIds,
      'currentIndex': currentIndex,
      'shuffle': shuffle,
      'repeat': repeat,
      'shuffleHistory': _shuffleHistory.items,
    };
  }

  /// Deserialización optimizada con manejo de versiones
  factory PlaybackContextOptimized.fromJson(Map<String, dynamic> json) {
    final version = json['version'] as int? ?? 1;
    
    if (version > 2) {
      throw ArgumentError('Versión de contexto no soportada: $version');
    }

    final typeStr = json['type'] as String;
    final type = PlaybackContextType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => throw ArgumentError('Tipo de contexto desconocido: $typeStr'),
    );
    
    final shuffleHistoryData = json['shuffleHistory'] as List?;
    final shuffleHistory = shuffleHistoryData != null
        ? ShuffleHistory.fromList(List<int>.from(shuffleHistoryData))
        : ShuffleHistory();

    final shuffle = json['shuffle'] as bool? ?? false;
    final shuffleGenerator = shuffle 
        ? ShuffleGenerator(DateTime.now().millisecondsSinceEpoch)
        : null;
    
    return PlaybackContextOptimized._(
      type: type,
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      songIds: List<String>.from(json['songIds'] as List),
      currentIndex: json['currentIndex'] as int? ?? 0,
      shuffle: shuffle,
      repeat: json['repeat'] as bool? ?? false,
      shuffleHistory: shuffleHistory,
      shuffleGenerator: shuffleGenerator,
    );
  }

  @override
  String toString() {
    final modes = <String>[];
    if (shuffle) modes.add('shuffle');
    if (repeat) modes.add('repeat');
    final modeStr = modes.isNotEmpty ? ' [${modes.join(', ')}]' : '';
    
    return 'PlaybackContextOptimized(type: $type, id: $id, name: $name, songs: ${songIds.length}, index: $currentIndex$modeStr)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlaybackContextOptimized &&
        other.type == type &&
        other.id == id &&
        other.currentIndex == currentIndex &&
        other.shuffle == shuffle &&
        other.repeat == repeat;
  }

  @override
  int get hashCode {
    return _cachedHashCode ??= Object.hash(type, id, currentIndex, shuffle, repeat);
  }
}
