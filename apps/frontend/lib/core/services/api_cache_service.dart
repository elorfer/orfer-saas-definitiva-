import '../models/song_model.dart';

/// Servicio de caché en memoria para resultados de búsquedas API
/// Optimiza las llamadas repetidas a endpoints de búsqueda por género/artista
class ApiCacheService {
  static final ApiCacheService _instance = ApiCacheService._internal();
  factory ApiCacheService() => _instance;
  ApiCacheService._internal();

  // ✅ CACHE DE RESULTADOS: Map<clave, (resultados, timestamp)>
  final Map<String, _CacheEntry<List<Song>>> _genreCache = {};
  final Map<String, _CacheEntry<List<Song>>> _artistCache = {};
  final Map<String, _CacheEntry<List<Song>>> _featuredCache = {};
  
  // TTL (Time To Live) para cada tipo de cache
  static const Duration _genreCacheTTL = Duration(minutes: 10); // Géneros cambian poco
  static const Duration _artistCacheTTL = Duration(minutes: 15); // Artistas cambian poco
  static const Duration _featuredCacheTTL = Duration(minutes: 5); // Featured cambia más frecuentemente
  
  // Límite de entradas en cache (evitar crecimiento infinito)
  static const int _maxCacheEntries = 50;

  /// Obtener canciones por género desde cache o null si no está cacheado/válido
  List<Song>? getGenreSongs(String genre) {
    final key = _normalizeKey(genre);
    final entry = _genreCache[key];
    
    if (entry == null) return null;
    
    // Verificar si el cache expiró
    final age = DateTime.now().difference(entry.timestamp);
    if (age > _genreCacheTTL) {
      _genreCache.remove(key);
      return null;
    }
    
    return entry.data;
  }

  /// Guardar canciones por género en cache
  void setGenreSongs(String genre, List<Song> songs) {
    final key = _normalizeKey(genre);
    
    // ✅ LIMPIEZA AUTOMÁTICA: Si el cache está lleno, eliminar la entrada más antigua
    if (_genreCache.length >= _maxCacheEntries && !_genreCache.containsKey(key)) {
      _removeOldestEntry(_genreCache);
    }
    
    _genreCache[key] = _CacheEntry(songs, DateTime.now());
  }

  /// Obtener canciones por artista desde cache o null si no está cacheado/válido
  List<Song>? getArtistSongs(String artistId) {
    final key = _normalizeKey(artistId);
    final entry = _artistCache[key];
    
    if (entry == null) return null;
    
    // Verificar si el cache expiró
    final age = DateTime.now().difference(entry.timestamp);
    if (age > _artistCacheTTL) {
      _artistCache.remove(key);
      return null;
    }
    
    return entry.data;
  }

  /// Guardar canciones por artista en cache
  void setArtistSongs(String artistId, List<Song> songs) {
    final key = _normalizeKey(artistId);
    
    // ✅ LIMPIEZA AUTOMÁTICA: Si el cache está lleno, eliminar la entrada más antigua
    if (_artistCache.length >= _maxCacheEntries && !_artistCache.containsKey(key)) {
      _removeOldestEntry(_artistCache);
    }
    
    _artistCache[key] = _CacheEntry(songs, DateTime.now());
  }

  /// Obtener canciones destacadas desde cache o null si no está cacheado/válido
  List<Song>? getFeaturedSongs() {
    const key = 'featured';
    final entry = _featuredCache[key];
    
    if (entry == null) return null;
    
    // Verificar si el cache expiró
    final age = DateTime.now().difference(entry.timestamp);
    if (age > _featuredCacheTTL) {
      _featuredCache.remove(key);
      return null;
    }
    
    return entry.data;
  }

  /// Guardar canciones destacadas en cache
  void setFeaturedSongs(List<Song> songs) {
    const key = 'featured';
    
    // ✅ LIMPIEZA AUTOMÁTICA: Si el cache está lleno, eliminar la entrada más antigua
    if (_featuredCache.length >= _maxCacheEntries && !_featuredCache.containsKey(key)) {
      _removeOldestEntry(_featuredCache);
    }
    
    _featuredCache[key] = _CacheEntry(songs, DateTime.now());
  }

  /// Limpiar cache expirado (llamar periódicamente)
  void clearExpired() {
    _clearExpiredCache(_genreCache, _genreCacheTTL);
    _clearExpiredCache(_artistCache, _artistCacheTTL);
    _clearExpiredCache(_featuredCache, _featuredCacheTTL);
  }

  /// Limpiar todo el cache
  void clearAll() {
    _genreCache.clear();
    _artistCache.clear();
    _featuredCache.clear();
  }

  /// ✅ PREFETCHING: Precargar canciones por género en background
  /// Útil para precargar géneros comunes antes de que se necesiten
  Future<void> prefetchGenreSongs(String genre, Future<List<Song>> Function() fetchFunction) async {
    final key = _normalizeKey(genre);
    
    // Si ya está en cache y válido, no hacer prefetch
    if (_genreCache.containsKey(key)) {
      final entry = _genreCache[key]!;
      final age = DateTime.now().difference(entry.timestamp);
      if (age < _genreCacheTTL) {
        return; // Ya está cacheado y válido
      }
    }
    
    // Precargar en background sin bloquear
    try {
      final songs = await fetchFunction();
      if (songs.isNotEmpty) {
        setGenreSongs(genre, songs);
      }
    } catch (e) {
      // Ignorar errores de prefetch (no crítico)
    }
  }

  /// ✅ PREFETCHING: Precargar canciones por artista en background
  Future<void> prefetchArtistSongs(String artistId, Future<List<Song>> Function() fetchFunction) async {
    final key = _normalizeKey(artistId);
    
    // Si ya está en cache y válido, no hacer prefetch
    if (_artistCache.containsKey(key)) {
      final entry = _artistCache[key]!;
      final age = DateTime.now().difference(entry.timestamp);
      if (age < _artistCacheTTL) {
        return; // Ya está cacheado y válido
      }
    }
    
    // Precargar en background sin bloquear
    try {
      final songs = await fetchFunction();
      if (songs.isNotEmpty) {
        setArtistSongs(artistId, songs);
      }
    } catch (e) {
      // Ignorar errores de prefetch (no crítico)
    }
  }

  /// Normalizar clave para cache (lowercase, trim)
  String _normalizeKey(String key) {
    return key.toLowerCase().trim();
  }

  /// Eliminar la entrada más antigua del cache
  void _removeOldestEntry(Map<String, _CacheEntry<List<Song>>> cache) {
    if (cache.isEmpty) return;
    
    String? oldestKey;
    DateTime? oldestTime;
    
    cache.forEach((key, entry) {
      if (oldestTime == null || entry.timestamp.isBefore(oldestTime!)) {
        oldestTime = entry.timestamp;
        oldestKey = key;
      }
    });
    
    if (oldestKey != null) {
      cache.remove(oldestKey);
    }
  }

  /// Limpiar entradas expiradas de un cache
  void _clearExpiredCache(
    Map<String, _CacheEntry<List<Song>>> cache,
    Duration ttl,
  ) {
    final now = DateTime.now();
    final keysToRemove = <String>[];
    
    cache.forEach((key, entry) {
      if (now.difference(entry.timestamp) > ttl) {
        keysToRemove.add(key);
      }
    });
    
    for (final key in keysToRemove) {
      cache.remove(key);
    }
  }
}

/// Entrada de cache con timestamp
class _CacheEntry<T> {
  final T data;
  final DateTime timestamp;

  _CacheEntry(this.data, this.timestamp);
}

