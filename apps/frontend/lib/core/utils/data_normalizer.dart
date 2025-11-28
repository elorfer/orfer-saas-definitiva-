import 'url_normalizer.dart';

/// Utilidad centralizada para normalizar datos entre camelCase y snake_case
/// Elimina duplicación de código en múltiples servicios
/// 
/// Este normalizador maneja la conversión entre diferentes formatos de datos
/// que vienen del backend (camelCase) y los formatos esperados por los modelos
/// del frontend (snake_case o camelCase según el modelo).
class DataNormalizer {
  // Constantes para valores por defecto
  static const String _defaultSongTitle = 'Sin título';
  static const String _defaultUserRole = 'user';
  static const String _defaultSubscriptionStatus = 'FREE';
  static const String _defaultPlaylistName = '';
  static const int _defaultNumericValue = 0;

  /// Convertir camelCase a snake_case
  /// Ejemplo: "stageName" -> "stage_name"
  static String camelToSnake(String input) {
    return input.replaceAllMapped(RegExp(r'[A-Z]'), (match) {
      final index = match.start;
      return index > 0 ? '_${match.group(0)!.toLowerCase()}' : match.group(0)!.toLowerCase();
    });
  }

  /// Normalizar un Map convirtiendo todas las claves camelCase a snake_case
  /// Mantiene las claves que ya están en snake_case
  static Map<String, dynamic> normalizeKeys(Map<String, dynamic> data) {
    final normalized = <String, dynamic>{};
    
    data.forEach((key, value) {
      final normalizedKey = key.contains('_') ? key : camelToSnake(key);
      
      if (value is Map<String, dynamic>) {
        normalized[normalizedKey] = normalizeKeys(value);
      } else if (value is List) {
        normalized[normalizedKey] = value.map((item) {
          return item is Map<String, dynamic> ? normalizeKeys(item) : item;
        }).toList();
      } else {
        normalized[normalizedKey] = value;
      }
    });
    
    return normalized;
  }

  /// Helper: Obtener valor de campo con múltiples variantes posibles
  /// Busca el valor en diferentes variantes del nombre del campo
  static dynamic _getFieldValue(
    Map<String, dynamic> data,
    List<String> variants,
  ) {
    for (final variant in variants) {
      final value = data[variant];
      if (value != null) return value;
    }
    return null;
  }

  /// Helper: Normalizar URL de imagen (portada)
  /// Maneja múltiples variantes del nombre del campo y normaliza la URL
  static String? _normalizeImageUrlField(
    Map<String, dynamic> data,
    List<String> fieldVariants,
    String targetField,
  ) {
    final imageUrl = _getFieldValue(data, fieldVariants);
    
    if (imageUrl == null || imageUrl is! String || imageUrl.trim().isEmpty) {
      return null;
    }

    final normalizedUrl = UrlNormalizer.normalizeImageUrl(imageUrl);
    return normalizedUrl ?? imageUrl; // Fallback al valor original si falla
  }

  /// Helper: Limpiar campos duplicados de un mapa
  static void _removeDuplicateFields(Map<String, dynamic> data, List<String> fieldsToRemove) {
    for (final field in fieldsToRemove) {
      data.remove(field);
    }
  }

  /// Helper: Asegurar valor por defecto si es null
  static void _ensureDefaultValue<T>(
    Map<String, dynamic> data,
    String key,
    T defaultValue,
  ) {
    data[key] ??= defaultValue;
  }

  /// Helper: Normalizar valor booleano desde diferentes tipos
  static bool _normalizeBoolean(dynamic value) {
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    if (value is num) return value != 0;
    return false;
  }

  /// Normalizar datos de artista
  /// Convierte campos comunes de camelCase a snake_case
  static Map<String, dynamic> normalizeArtist(Map<String, dynamic> data) {
    final normalized = <String, dynamic>{};
    
    // Mapeo de campos comunes
    const fieldMapping = {
      'id': 'id',
      'name': 'stage_name',
      'stageName': 'stage_name',
      'stage_name': 'stage_name',
      'userId': 'user_id',
      'user_id': 'user_id',
      'profilePhotoUrl': 'profile_photo_url',
      'profile_photo_url': 'profile_photo_url',
      'coverPhotoUrl': 'cover_photo_url',
      'cover_photo_url': 'cover_photo_url',
      'websiteUrl': 'website_url',
      'website_url': 'website_url',
      'socialLinks': 'social_links',
      'social_links': 'social_links',
      'verificationStatus': 'verification_status',
      'verification_status': 'verification_status',
      'totalStreams': 'total_streams',
      'total_streams': 'total_streams',
      'totalFollowers': 'total_followers',
      'total_followers': 'total_followers',
      'monthlyListeners': 'monthly_listeners',
      'monthly_listeners': 'monthly_listeners',
      'bio': 'bio',
      'biography': 'bio',
      'nationalityCode': 'nationality_code',
      'nationality_code': 'nationality_code',
      'featured': 'featured',
      'is_featured': 'featured',
      'isFeatured': 'featured',
      'createdAt': 'created_at',
      'created_at': 'created_at',
      'updatedAt': 'updated_at',
      'updated_at': 'updated_at',
    };
    
    // Mapear campos conocidos
    data.forEach((key, value) {
      final mappedKey = fieldMapping[key] ?? camelToSnake(key);
      
      if (value is Map<String, dynamic>) {
        normalized[mappedKey] = key == 'user' 
            ? normalizeUser(value) 
            : normalizeKeys(value);
      } else {
        normalized[mappedKey] = value;
      }
    });
    
    // Manejar avatarUrl del SongMapper (formato simplificado del backend)
    if (data.containsKey('avatarUrl') && !normalized.containsKey('profile_photo_url')) {
      normalized['profile_photo_url'] = data['avatarUrl'];
    }
    
    // Asegurar que siempre haya un stage_name
    if (!normalized.containsKey('stage_name') || normalized['stage_name'] == null || normalized['stage_name'].toString().isEmpty) {
      if (normalized.containsKey('name') && normalized['name'] != null) {
        normalized['stage_name'] = normalized['name'];
      } else if (data.containsKey('stageName') && data['stageName'] != null) {
        normalized['stage_name'] = data['stageName'];
      } else {
        normalized['stage_name'] = 'Artista desconocido';
      }
    }
    
    // Asegurar valores por defecto
    _ensureDefaultValue(normalized, 'verification_status', false);
    _ensureDefaultValue(normalized, 'total_streams', _defaultNumericValue);
    _ensureDefaultValue(normalized, 'total_followers', _defaultNumericValue);
    _ensureDefaultValue(normalized, 'monthly_listeners', _defaultNumericValue);
    
    return normalized;
  }

  /// Normalizar datos de canción
  /// Convierte campos comunes de camelCase a snake_case
  static Map<String, dynamic> normalizeSong(Map<String, dynamic> data) {
    final normalized = <String, dynamic>{};
    
    // Mapeo de campos comunes
    const fieldMapping = {
      'id': 'id',
      'title': 'title',
      'duration': 'duration',
      'artistId': 'artist_id',
      'artist_id': 'artist_id',
      'albumId': 'album_id',
      'album_id': 'album_id',
      'fileUrl': 'file_url',
      'file_url': 'file_url',
      'coverArtUrl': 'cover_art_url',
      'cover_art_url': 'cover_art_url',
      'coverImageUrl': 'cover_art_url',
      'cover_image_url': 'cover_art_url',
      'genreId': 'genre_id',
      'genre_id': 'genre_id',
      'trackNumber': 'track_number',
      'track_number': 'track_number',
      'isExplicit': 'is_explicit',
      'is_explicit': 'is_explicit',
      'releaseDate': 'release_date',
      'release_date': 'release_date',
      'totalStreams': 'total_streams',
      'total_streams': 'total_streams',
      'totalLikes': 'total_likes',
      'total_likes': 'total_likes',
      'totalShares': 'total_shares',
      'total_shares': 'total_shares',
      'status': 'status',
      'lyrics': 'lyrics',
      'genres': 'genres', // Array de géneros musicales
      'createdAt': 'created_at',
      'created_at': 'created_at',
      'updatedAt': 'updated_at',
      'updated_at': 'updated_at',
    };
    
    // Mapear campos conocidos
    data.forEach((key, value) {
      final mappedKey = fieldMapping[key] ?? camelToSnake(key);
      
      if (value is Map<String, dynamic>) {
        if (key == 'artist') {
          // Normalizar artista específicamente
          final normalizedArtist = normalizeArtist(value);
          normalized[mappedKey] = normalizedArtist;
          // Asegurar que stageName también esté disponible en camelCase para compatibilidad
          if (normalizedArtist['stage_name'] != null && normalizedArtist['stageName'] == null) {
            normalizedArtist['stageName'] = normalizedArtist['stage_name'];
          }
        } else {
          normalized[mappedKey] = normalizeKeys(value);
        }
      } else if (key == 'genres') {
        // Manejar géneros que pueden venir como List, String (separado por comas), o null
        if (value is List) {
          // Si es una lista, convertir a lista de strings
          normalized[mappedKey] = value
              .where((item) => item != null && item.toString().trim().isNotEmpty)
              .map((item) => item.toString().trim())
              .toList();
        } else if (value is String && value.isNotEmpty) {
          // Si es un string (simple-array de TypeORM), dividir por comas
          normalized[mappedKey] = value
              .split(',')
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList();
        } else {
          // Si es null o vacío, dejar como null
          normalized[mappedKey] = null;
        }
      } else {
        normalized[mappedKey] = value;
      }
    });
    
    // Normalizar URL de portada de la canción
    final coverArtUrl = _normalizeImageUrlField(
      {...data, ...normalized},
      ['cover_art_url', 'coverArtUrl', 'coverImageUrl', 'cover_image_url'],
      'cover_art_url',
    );
    normalized['cover_art_url'] = coverArtUrl;
    
    // IMPORTANTE: También mantener coverArtUrl en camelCase para compatibilidad con el modelo Song
    normalized['coverArtUrl'] = coverArtUrl;
    
    // Asegurar campos requeridos con valores por defecto
    _ensureDefaultValue(normalized, 'title', _defaultSongTitle);
    _ensureDefaultValue(normalized, 'duration', _defaultNumericValue);
    _ensureDefaultValue(normalized, 'status', 'published');
    _ensureDefaultValue(normalized, 'id', '');
    
    // file_url puede venir de diferentes campos
    final fileUrlValue = data['file_url'] ?? data['fileUrl'] ?? '';
    normalized['file_url'] = fileUrlValue;
    
    // IMPORTANTE: También mantener fileUrl en camelCase para compatibilidad con el modelo Song
    normalized['fileUrl'] = fileUrlValue;
    
    return normalized;
  }

  /// Normalizar datos de usuario
  /// Convierte campos comunes de camelCase a snake_case
  static Map<String, dynamic> normalizeUser(Map<String, dynamic> data) {
    final normalized = <String, dynamic>{};
    
    // Mapeo de campos comunes
    const fieldMapping = {
      'id': 'id',
      'email': 'email',
      'username': 'username',
      'firstName': 'first_name',
      'first_name': 'first_name',
      'lastName': 'last_name',
      'last_name': 'last_name',
      'avatarUrl': 'avatar_url',
      'avatar_url': 'avatar_url',
      'role': 'role',
      'subscriptionStatus': 'subscription_status',
      'subscription_status': 'subscription_status',
      'isVerified': 'is_verified',
      'is_verified': 'is_verified',
      'isActive': 'is_active',
      'is_active': 'is_active',
      'lastLoginAt': 'last_login_at',
      'last_login_at': 'last_login_at',
      'createdAt': 'created_at',
      'created_at': 'created_at',
      'updatedAt': 'updated_at',
      'updated_at': 'updated_at',
    };
    
    // Mapear campos conocidos
    data.forEach((key, value) {
      final mappedKey = fieldMapping[key] ?? camelToSnake(key);
      normalized[mappedKey] = value;
    });
    
    // Asegurar campos requeridos con valores por defecto
    _ensureDefaultValue(normalized, 'role', _defaultUserRole);
    _ensureDefaultValue(normalized, 'subscription_status', _defaultSubscriptionStatus);
    _ensureDefaultValue(normalized, 'id', '');
    _ensureDefaultValue(normalized, 'email', '');
    _ensureDefaultValue(normalized, 'username', '');
    
    // Normalizar valores de role y subscription_status
    _normalizeRole(normalized);
    _normalizeSubscriptionStatus(normalized);
    
    return normalized;
  }

  /// Helper: Normalizar valor de role
  static void _normalizeRole(Map<String, dynamic> data) {
    if (data['role'] == null) return;
    
    final roleValue = data['role'].toString().toLowerCase();
    const validRoles = {'user', 'artist', 'admin'};
    data['role'] = validRoles.contains(roleValue) ? roleValue : _defaultUserRole;
  }

  /// Helper: Normalizar valor de subscription_status
  static void _normalizeSubscriptionStatus(Map<String, dynamic> data) {
    if (data['subscription_status'] == null) return;
    
    final subStatusValue = data['subscription_status'].toString().toUpperCase();
    const validStatuses = {'FREE', 'PREMIUM', 'VIP', 'INACTIVE'};
    
    if (validStatuses.contains(subStatusValue)) {
      data['subscription_status'] = subStatusValue == 'INACTIVE' ? 'inactive' : subStatusValue;
    } else {
      data['subscription_status'] = _defaultSubscriptionStatus;
    }
  }

  /// Normalizar datos de playlist
  /// El modelo Playlist espera camelCase (no snake_case)
  /// Solo normalizamos las relaciones (user, playlistSongs) y URLs de imágenes
  static Map<String, dynamic> normalizePlaylist(Map<String, dynamic> data) {
    final normalized = Map<String, dynamic>.from(data);
    
    // Normalizar campos básicos
    _normalizePlaylistBasicFields(normalized);
    
    // Normalizar URL de portada
    _normalizePlaylistCoverUrl(normalized);
    
    // Normalizar relaciones
    _normalizePlaylistRelations(normalized);
    
    return normalized;
  }

  /// Helper: Normalizar campos básicos de playlist
  static void _normalizePlaylistBasicFields(Map<String, dynamic> normalized) {
    // ID
    if (normalized['id'] == null || normalized['id'] == '') {
      normalized['id'] = '';
    }
    
    // Nombre: normalizar y limpiar
    if (normalized['name'] != null && normalized['name'] is String) {
      final nameValue = normalized['name'].toString().trim();
      normalized['name'] = (nameValue.isEmpty || nameValue.toLowerCase() == 'sin nombre')
          ? _defaultPlaylistName
          : nameValue;
    } else {
      normalized['name'] = _defaultPlaylistName;
    }
    
    // Valores por defecto
    _ensureDefaultValue(normalized, 'isPublic', true);
    _ensureDefaultValue(normalized, 'totalTracks', _defaultNumericValue);
    _ensureDefaultValue(normalized, 'totalFollowers', _defaultNumericValue);
    _ensureDefaultValue(normalized, 'totalDuration', _defaultNumericValue);
    
    // Normalizar isFeatured
    _normalizePlaylistFeatured(normalized);
  }

  /// Helper: Normalizar campo isFeatured de playlist
  static void _normalizePlaylistFeatured(Map<String, dynamic> normalized) {
    if (normalized['isFeatured'] == null) {
      normalized['isFeatured'] = _getFieldValue(
        normalized,
        ['is_featured', 'featured'],
      ) ?? false;
      
      // Limpiar campos duplicados
      _removeDuplicateFields(normalized, ['is_featured', 'featured']);
    }
    
    // Asegurar que sea boolean
    if (normalized['isFeatured'] is! bool) {
      normalized['isFeatured'] = _normalizeBoolean(normalized['isFeatured']);
    }
  }

  /// Helper: Normalizar URL de portada de playlist
  static void _normalizePlaylistCoverUrl(Map<String, dynamic> normalized) {
    final coverArtUrl = _normalizeImageUrlField(
      normalized,
      ['coverArtUrl', 'cover_art_url', 'coverImageUrl', 'cover_image_url'],
      'coverArtUrl',
    );
    
    normalized['coverArtUrl'] = coverArtUrl;
    
    // Limpiar campos duplicados
    _removeDuplicateFields(normalized, ['cover_art_url', 'coverImageUrl', 'cover_image_url']);
  }

  /// Helper: Normalizar relaciones de playlist (user, playlistSongs)
  static void _normalizePlaylistRelations(Map<String, dynamic> normalized) {
    // Normalizar user si existe
    if (normalized['user'] is Map<String, dynamic>) {
      normalized['user'] = normalizeUser(normalized['user'] as Map<String, dynamic>);
    }
    
    // Normalizar playlistSongs si existen
    final playlistSongsData = normalized['playlistSongs'] ?? normalized['playlist_songs'];
    if (playlistSongsData is List) {
      normalized['playlistSongs'] = _normalizePlaylistSongs(playlistSongsData);
      normalized.remove('playlist_songs'); // Limpiar campo duplicado
    }
  }

  /// Helper: Normalizar lista de playlistSongs
  static List<Map<String, dynamic>> _normalizePlaylistSongs(List<dynamic> playlistSongsData) {
    return playlistSongsData
        .whereType<Map<String, dynamic>>()
        .where((item) => item['song'] != null)
        .map((item) {
          final normalizedItem = Map<String, dynamic>.from(item);
          
          // Asegurar campos requeridos de PlaylistSong en camelCase
          _ensureDefaultValue(normalizedItem, 'id', '');
          _ensureDefaultValue(normalizedItem, 'position', _defaultNumericValue);
          
          normalizedItem['playlistId'] ??= item['playlistId'] ?? item['playlist_id'] ?? '';
          normalizedItem['songId'] ??= item['songId'] ?? item['song_id'] ?? '';
          
          // Normalizar la canción dentro del playlistSong
          if (normalizedItem['song'] is Map<String, dynamic>) {
            normalizedItem['song'] = normalizeSong(
              normalizedItem['song'] as Map<String, dynamic>,
            );
          }
          
          return normalizedItem;
        })
        .toList();
  }
}
