import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import '../models/artist_model.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart';
import 'http_cache_service.dart';
import '../utils/logger.dart';
import '../utils/url_normalizer.dart';

class HomeService {
  static final HomeService _instance = HomeService._internal();
  factory HomeService() => _instance;
  HomeService._internal();

  late final Dio _dio;
  late final FlutterSecureStorage _storage;

  /// Inicializar el servicio
  Future<void> initialize() async {
    AppLogger.info('[HomeService] Inicializando HomeService...');
    AppLogger.config('[HomeService] URL base configurada: ${ApiConfig.baseUrl}');
    
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        // Configurar validateStatus globalmente para aceptar todos los códigos
        // Esto previene excepciones por errores 500 que no son críticos
        validateStatus: (status) => status != null && status < 600,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
      ),
    );
    _storage = const FlutterSecureStorage();
    _setupInterceptors();
    AppLogger.success('[HomeService] HomeService inicializado correctamente');
    
    // Test de conexión básico (no bloqueante)
    Future.microtask(() async {
      try {
        AppLogger.debug('[HomeService] Probando conexión al backend...');
        final testResponse = await _dio.get('/health', 
          options: Options(
            receiveTimeout: const Duration(seconds: 5),
            sendTimeout: const Duration(seconds: 5),
          ),
        );
        AppLogger.success('[HomeService] Conexión exitosa! Status: ${testResponse.statusCode}');
      } catch (e) {
        AppLogger.warning('[HomeService] No se pudo conectar al backend: $e');
        AppLogger.warning('[HomeService] Verifica que el backend esté corriendo en: ${ApiConfig.baseUrl.replaceAll('/api/v1', '')}');
        if (e is DioException) {
          AppLogger.warning('[HomeService] Error de conexión: ${e.type} - ${e.message}');
          AppLogger.warning('[HomeService] URL intentada: ${e.requestOptions.uri}');
        }
      }
    });
  }

  /// Configurar interceptores
  void _setupInterceptors() {
    _dio.interceptors.clear(); // Limpiar interceptores existentes
    
    // Agregar caché HTTP si está disponible
    if (HttpCacheService.cacheOptions != null) {
      _dio.interceptors.add(
        DioCacheInterceptor(options: HttpCacheService.cacheOptions!),
      );
    }
    
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Agregar headers por defecto
          options.headers.addAll(ApiConfig.defaultHeaders);
          
          // Agregar token de autenticación
          final token = await _storage.read(key: 'auth_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          
          handler.next(options);
        },
        onError: (error, handler) {
          // No loguear errores - ya se manejan en cada método individualmente
          // Esto evita logs innecesarios que causan lag en el main thread
          handler.next(error);
        },
      ),
    );

    // LogInterceptor deshabilitado para mejor rendimiento
  }

  /// Obtener artistas destacados
  /// - Normaliza claves camelCase/snake_case
  /// - Aplica cache-busting y fuerza refresh del caché HTTP
  /// - Tolera respuestas en arreglo plano o con wrapper { artists: [] }
  Future<List<FeaturedArtist>> getFeaturedArtists({int limit = 6}) async {
    try {
      final url = '/public/featured/artists';
      AppLogger.debug('[HomeService] Obteniendo artistas destacados desde: ${ApiConfig.baseUrl}$url');
      
      final response = await _dio.get(
        url,
        queryParameters: {
          'limit': limit,
          '_t': DateTime.now().millisecondsSinceEpoch,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
          extra: {
            'dio_cache_force_refresh': true,
          },
        ),
      );
      
      AppLogger.success('[HomeService] Respuesta recibida: ${response.statusCode}');
      AppLogger.data('[HomeService] Datos recibidos: ${response.data}');

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> data = response.data is List
            ? (response.data as List)
            : ((response.data['artists'] as List?) ?? const []);

        AppLogger.data('[HomeService] Total de artistas recibidos: ${data.length}');

        if (data.isEmpty) {
          AppLogger.warning('[HomeService] No hay artistas destacados en la respuesta');
          return const [];
        }

        final result = <FeaturedArtist>[];
        for (var i = 0; i < data.length; i++) {
          final item = data[i];
          if (item is! Map<String, dynamic>) {
            AppLogger.warning('[HomeService] Item $i no es un Map: ${item.runtimeType}');
            continue;
          }

          AppLogger.artist('[HomeService] Procesando artista $i: ${item['name'] ?? item['stageName'] ?? item['stage_name'] ?? 'Sin nombre'}');
          
          final normalized = _normalizeArtistMap(item);
          AppLogger.data('[HomeService] Datos normalizados: ${normalized.keys.toList()}');

          // Imagen preferida - buscar en múltiples lugares
          final rawImage = (item['profilePhotoUrl'] as String?) ??
              (item['profile_photo_url'] as String?) ??
              (item['coverPhotoUrl'] as String?) ??
              (item['cover_photo_url'] as String?) ??
              (normalized['profile_photo_url'] as String?) ??
              (normalized['cover_photo_url'] as String?);

          AppLogger.media('[HomeService] Imagen raw encontrada: $rawImage');
          AppLogger.data('[HomeService] Item keys: ${item.keys.toList()}');
          
          final normalizedImage = UrlNormalizer.normalizeImageUrl(rawImage, enableLogging: true);
          AppLogger.media('[HomeService] Imagen normalizada: $normalizedImage');

          try {
            final artist = Artist.fromJson(normalized);
            AppLogger.success('[HomeService] Artista parseado correctamente: ${artist.stageName ?? artist.id}');
            AppLogger.media('[HomeService] profilePhotoUrl del artista: ${artist.profilePhotoUrl}');
            AppLogger.media('[HomeService] coverPhotoUrl del artista: ${artist.coverPhotoUrl}');
            
            // Usar la imagen normalizada o la del artista parseado
            final finalImageUrl = normalizedImage ?? 
                (artist.profilePhotoUrl != null ? UrlNormalizer.normalizeImageUrl(artist.profilePhotoUrl) : null) ??
                (artist.coverPhotoUrl != null ? UrlNormalizer.normalizeImageUrl(artist.coverPhotoUrl) : null);
            
            AppLogger.media('[HomeService] URL final de imagen para FeaturedArtist: $finalImageUrl');
            
            result.add(
              FeaturedArtist(
                artist: artist,
                featuredReason: 'Destacado',
                rank: i + 1,
                imageUrl: finalImageUrl,
              ),
            );
          } catch (e, stackTrace) {
            AppLogger.error('[HomeService] Error al parsear artista $i: $e', e, stackTrace);
            AppLogger.data('[HomeService] Datos que fallaron: $normalized');
          }
        }

        AppLogger.success('[HomeService] Total de artistas procesados exitosamente: ${result.length}');
        return result;
      } else {
        AppLogger.warning('[HomeService] Respuesta vacía o inválida: ${response.statusCode}');
        return [];
      }
    } on DioException catch (e) {
      AppLogger.error('[HomeService] Error DioException al obtener artistas destacados:');
      AppLogger.network('  - Tipo: ${e.type}');
      AppLogger.network('  - Mensaje: ${e.message}');
      AppLogger.network('  - Error: ${e.error}');
      AppLogger.network('  - URL completa: ${e.requestOptions.uri}');
      AppLogger.network('  - Base URL: ${e.requestOptions.baseUrl}');
      AppLogger.network('  - Path: ${e.requestOptions.path}');
      if (e.response != null) {
        AppLogger.network('  - Status: ${e.response?.statusCode}');
        AppLogger.network('  - Data: ${e.response?.data}');
      } else {
        AppLogger.warning('  - Sin respuesta del servidor (posible problema de conexión)');
        AppLogger.warning('  - Verifica que el backend esté corriendo en: http://10.0.2.2:3001');
      }
      AppLogger.error('[HomeService] StackTrace: ${e.stackTrace}', e, e.stackTrace);
      return [];
    } catch (e, stackTrace) {
      AppLogger.error('[HomeService] Error inesperado al obtener artistas destacados: $e', e, stackTrace);
      return [];
    }
  }

  Map<String, dynamic> _normalizeArtistMap(Map<String, dynamic> raw) {
    final normalized = <String, dynamic>{};
    
    // Mapear campos comunes
    raw.forEach((key, value) {
      switch (key) {
        case 'id':
          normalized['id'] = value;
          break;
        case 'name':
          // Si viene 'name' del backend, usarlo como stage_name si no hay stageName
          if (!normalized.containsKey('stage_name') && value != null) {
            normalized['stage_name'] = value;
          }
          normalized['name'] = value; // Mantener también name por si acaso
          break;
        case 'stageName':
        case 'stage_name':
          normalized['stage_name'] = value;
          break;
        case 'userId':
        case 'user_id':
          normalized['user_id'] = value;
          break;
        case 'profilePhotoUrl':
        case 'profile_photo_url':
          normalized['profile_photo_url'] = value;
          break;
        case 'coverPhotoUrl':
        case 'cover_photo_url':
          normalized['cover_photo_url'] = value;
          break;
        case 'websiteUrl':
        case 'website_url':
          normalized['website_url'] = value;
          break;
        case 'socialLinks':
        case 'social_links':
          normalized['social_links'] = value;
          break;
        case 'verificationStatus':
        case 'verification_status':
          normalized['verification_status'] = value ?? false;
          break;
        case 'totalStreams':
        case 'total_streams':
          normalized['total_streams'] = value ?? 0;
          break;
        case 'totalFollowers':
        case 'total_followers':
          normalized['total_followers'] = value ?? 0;
          break;
        case 'monthlyListeners':
        case 'monthly_listeners':
          normalized['monthly_listeners'] = value ?? 0;
          break;
        case 'bio':
        case 'biography':
          normalized['bio'] = value;
          break;
        case 'nationalityCode':
        case 'nationality_code':
          normalized['nationality_code'] = value;
          break;
        case 'featured':
        case 'is_featured':
        case 'isFeatured':
          normalized['featured'] = value ?? false;
          break;
        case 'createdAt':
        case 'created_at':
          normalized['created_at'] = value;
          break;
        case 'updatedAt':
        case 'updated_at':
          normalized['updated_at'] = value;
          break;
        default:
          // Si ya está en snake_case, mantenerlo
          if (key.contains('_')) {
            normalized[key] = value;
          } else {
            // Convertir camelCase a snake_case automáticamente
            final snakeKey = _camelToSnake(key);
            normalized[snakeKey] = value;
          }
      }
    });
    
    // Asegurar que siempre haya un stage_name
    if (!normalized.containsKey('stage_name') && normalized.containsKey('name')) {
      normalized['stage_name'] = normalized['name'];
    }
    
    // Asegurar valores por defecto
    normalized['verification_status'] ??= false;
    normalized['total_streams'] ??= 0;
    normalized['total_followers'] ??= 0;
    normalized['monthly_listeners'] ??= 0;
    
    return normalized;
  }
  
  /// Convertir camelCase a snake_case
  String _camelToSnake(String input) {
    return input.replaceAllMapped(RegExp(r'[A-Z]'), (match) {
      return '_${match.group(0)!.toLowerCase()}';
    });
  }

  /// Obtener canciones destacadas desde el admin
  /// Estas son las canciones que el administrador ha marcado como destacadas
  Future<List<FeaturedSong>> getFeaturedSongs({int limit = 20, bool forceRefresh = false}) async {
    try {
      final url = '/public/featured/songs';
      AppLogger.debug('[HomeService] Obteniendo canciones destacadas desde: ${ApiConfig.baseUrl}$url');
      
      // Agregar timestamp para evitar caché si se fuerza el refresh
      final queryParams = <String, dynamic>{
        'limit': limit,
      };
      
      if (forceRefresh) {
        queryParams['_t'] = DateTime.now().millisecondsSinceEpoch;
      }
      
      final response = await _dio.get(
        url,
        queryParameters: queryParams,
      );

        if (response.statusCode == 200 && response.data != null) {
          final List<dynamic> data = response.data is List 
              ? response.data 
              : (response.data['songs'] ?? []);
          
          if (data.isEmpty) {
            return [];
          }

        final featuredSongs = <FeaturedSong>[];
        
          for (var i = 0; i < data.length; i++) {
          try {
            final songData = data[i] as Map<String, dynamic>;
            
            // Asegurar que el artista se parsee correctamente
            Song song;
            if (songData.containsKey('artist') && songData['artist'] != null) {
              try {
                final artistData = songData['artist'] as Map<String, dynamic>;
                
                // Normalizar los datos del artista para manejar tanto camelCase como snake_case
                final normalizedArtistData = <String, dynamic>{};
                artistData.forEach((key, value) {
                  if (key == 'stageName') {
                    normalizedArtistData['stage_name'] = value;
                  } else if (key == 'userId') {
                    normalizedArtistData['user_id'] = value;
                  } else if (key == 'verificationStatus') {
                    normalizedArtistData['verification_status'] = value;
                  } else if (key == 'totalStreams') {
                    normalizedArtistData['total_streams'] = value;
                  } else if (key == 'totalFollowers') {
                    normalizedArtistData['total_followers'] = value;
                  } else if (key == 'monthlyListeners') {
                    normalizedArtistData['monthly_listeners'] = value;
                  } else if (key == 'websiteUrl') {
                    normalizedArtistData['website_url'] = value;
                  } else if (key == 'socialLinks') {
                    normalizedArtistData['social_links'] = value;
                  } else if (key == 'createdAt') {
                    normalizedArtistData['created_at'] = value;
                  } else if (key == 'updatedAt') {
                    normalizedArtistData['updated_at'] = value;
                  } else {
                    normalizedArtistData[key] = value;
                  }
                });
                
                final artist = Artist.fromJson(normalizedArtistData);
                final tempSong = Song.fromJson(songData);
                
                final rawCoverUrl = tempSong.coverArtUrl ?? 
                                   songData['cover_art_url'] as String? ?? 
                                   songData['coverArtUrl'] as String? ??
                                   songData['coverImageUrl'] as String? ??
                                   songData['cover_image_url'] as String?;
                
                final normalizedCoverUrl = UrlNormalizer.normalizeImageUrl(rawCoverUrl);
                
                song = Song(
                  id: tempSong.id,
                  artistId: tempSong.artistId,
                  albumId: tempSong.albumId,
                  title: tempSong.title,
                  duration: tempSong.duration,
                  fileUrl: tempSong.fileUrl,
                  coverArtUrl: normalizedCoverUrl,
                  lyrics: tempSong.lyrics,
                  genreId: tempSong.genreId,
                  trackNumber: tempSong.trackNumber,
                  status: tempSong.status,
                  isExplicit: tempSong.isExplicit,
                  releaseDate: tempSong.releaseDate,
                  totalStreams: tempSong.totalStreams,
                  totalLikes: tempSong.totalLikes,
                  totalShares: tempSong.totalShares,
                  createdAt: tempSong.createdAt,
                  updatedAt: tempSong.updatedAt,
                  artist: artist,
                );
              } catch (e) {
                final tempSong = Song.fromJson(songData);
                final rawCoverUrl = tempSong.coverArtUrl ?? 
                                   songData['cover_art_url'] as String? ?? 
                                   songData['coverArtUrl'] as String? ??
                                   songData['coverImageUrl'] as String? ??
                                   songData['cover_image_url'] as String?;
                final normalizedCoverUrl = UrlNormalizer.normalizeImageUrl(rawCoverUrl);
                song = Song(
                  id: tempSong.id,
                  artistId: tempSong.artistId,
                  albumId: tempSong.albumId,
                  title: tempSong.title,
                  duration: tempSong.duration,
                  fileUrl: tempSong.fileUrl,
                  coverArtUrl: normalizedCoverUrl,
                  lyrics: tempSong.lyrics,
                  genreId: tempSong.genreId,
                  trackNumber: tempSong.trackNumber,
                  status: tempSong.status,
                  isExplicit: tempSong.isExplicit,
                  releaseDate: tempSong.releaseDate,
                  totalStreams: tempSong.totalStreams,
                  totalLikes: tempSong.totalLikes,
                  totalShares: tempSong.totalShares,
                  createdAt: tempSong.createdAt,
                  updatedAt: tempSong.updatedAt,
                  artist: tempSong.artist,
                );
              }
            } else {
              final tempSong = Song.fromJson(songData);
              
              final rawCoverUrl = tempSong.coverArtUrl ?? 
                                 songData['cover_art_url'] as String? ?? 
                                 songData['coverArtUrl'] as String? ??
                                 songData['coverImageUrl'] as String? ??
                                 songData['cover_image_url'] as String?;
              
              final normalizedCoverUrl = UrlNormalizer.normalizeImageUrl(rawCoverUrl);
              
              song = Song(
                id: tempSong.id,
                artistId: tempSong.artistId,
                albumId: tempSong.albumId,
                title: tempSong.title,
                duration: tempSong.duration,
                fileUrl: tempSong.fileUrl,
                coverArtUrl: normalizedCoverUrl,
                lyrics: tempSong.lyrics,
                genreId: tempSong.genreId,
                trackNumber: tempSong.trackNumber,
                status: tempSong.status,
                isExplicit: tempSong.isExplicit,
                releaseDate: tempSong.releaseDate,
                totalStreams: tempSong.totalStreams,
                totalLikes: tempSong.totalLikes,
                totalShares: tempSong.totalShares,
                createdAt: tempSong.createdAt,
                updatedAt: tempSong.updatedAt,
                artist: tempSong.artist,
              );
            }
            
            featuredSongs.add(
              FeaturedSong(
                song: song,
                featuredReason: 'Destacada por el administrador',
                rank: i + 1,
              ),
            );
          } catch (e) {
            // Error silencioso al parsear canción individual
          }
        }

        return featuredSongs;
      } else {
        return [];
      }
    } on DioException {
      return [];
    } catch (e) {
      return [];
    }
  }


  /// Obtener canciones populares
  /// Si el endpoint falla, retorna lista vacía silenciosamente (no afecta la UI)
  Future<List<Song>> getPopularSongs({int limit = 10}) async {
    try {
      final response = await _dio.get(
        '/public/songs/top',
        queryParameters: {'limit': limit},
      );

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> data = response.data is List ? response.data : (response.data['songs'] ?? []);
        final validData = data.where((item) => item != null && item is Map<String, dynamic>).toList();
        
        if (validData.isEmpty) {
          return [];
        }
        
        return validData.map((json) {
          try {
            return Song.fromJson(json as Map<String, dynamic>);
          } catch (e) {
            // Error silencioso al parsear canción individual
            return null;
          }
        }).where((item) => item != null).cast<Song>().toList();
      } else {
        // Error silencioso - el endpoint puede no estar disponible (500, etc.)
        return [];
      }
    } on DioException {
      // Error silencioso - no loguear para evitar spam en consola
      // El endpoint puede no estar disponible o tener problemas en el backend
      return [];
    } catch (_) {
      // Error silencioso
      return [];
    }
  }

  /// Obtener artistas más escuchados
  Future<List<Artist>> getTopArtists({int limit = 8}) async {
    try {
      final response = await _dio.get(
        '/public/artists/top',
        queryParameters: {'limit': limit},
      );

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> data = response.data is List ? response.data : (response.data['artists'] ?? []);
        final validData = data.where((item) => item != null && item is Map<String, dynamic>).toList();
        
        if (validData.isEmpty) {
          return [];
        }
        
        return validData.map((json) {
          try {
            return Artist.fromJson(json as Map<String, dynamic>);
          } catch (e) {
            return null;
          }
        }).where((item) => item != null).cast<Artist>().toList();
      } else {
        return [];
      }
    } on DioException {
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Obtener playlists destacadas
  Future<List<FeaturedPlaylist>> getFeaturedPlaylists({int limit = 6}) async {
    try {
      final url = '/public/featured/playlists';
      AppLogger.debug('[HomeService] Obteniendo playlists destacadas desde: ${ApiConfig.baseUrl}$url');
      final response = await _dio.get(
        url,
        queryParameters: {'limit': limit},
      );

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> data = response.data is List ? response.data : [];
        final validData = data.where((item) => item != null && item is Map<String, dynamic>).toList();
        
        if (validData.isEmpty) {
          return [];
        }
        
        final playlists = <FeaturedPlaylist>[];
        for (var i = 0; i < validData.length; i++) {
          try {
            final item = validData[i] as Map<String, dynamic>;
            
            // Normalizar coverArtUrl antes de parsear (convertir localhost a 10.0.2.2)
            final coverArtUrl = item['coverArtUrl'] ?? item['cover_art_url'];
            if (coverArtUrl != null && coverArtUrl is String && coverArtUrl.isNotEmpty) {
              final normalizedCoverUrl = UrlNormalizer.normalizeImageUrl(coverArtUrl);
              if (normalizedCoverUrl != null && normalizedCoverUrl.isNotEmpty) {
                item['coverArtUrl'] = normalizedCoverUrl;
                item['cover_art_url'] = normalizedCoverUrl;
              }
            }
            
            // Transformar el user de camelCase a snake_case si existe
            if (item.containsKey('user') && item['user'] != null) {
              final userData = item['user'] as Map<String, dynamic>;
              
              // Obtener valores con fallback para ambos formatos (camelCase y snake_case)
              String? getStringValue(String camelKey, String snakeKey) {
                final camelValue = userData[camelKey];
                final snakeValue = userData[snakeKey];
                if (camelValue != null) return camelValue.toString();
                if (snakeValue != null) return snakeValue.toString();
                return null;
              }
              
              dynamic getValue(String camelKey, String snakeKey, {dynamic defaultValue}) {
                return userData[camelKey] ?? userData[snakeKey] ?? defaultValue;
              }
              
              final transformedUser = <String, dynamic>{
                'id': getValue('id', 'id', defaultValue: '') as String,
                'email': getValue('email', 'email', defaultValue: '') as String,
                'username': getValue('username', 'username', defaultValue: '') as String,
                'first_name': getStringValue('firstName', 'first_name') ?? '',
                'last_name': getStringValue('lastName', 'last_name') ?? '',
                'avatar_url': getValue('avatarUrl', 'avatar_url'),
                'role': getValue('role', 'role', defaultValue: 'user'),
                'subscription_status': getValue('subscriptionStatus', 'subscription_status', defaultValue: 'inactive'),
                'is_verified': getValue('isVerified', 'is_verified', defaultValue: false),
                'is_active': getValue('isActive', 'is_active', defaultValue: true),
                'last_login_at': getValue('lastLoginAt', 'last_login_at'),
                'created_at': getValue('createdAt', 'created_at'),
                'updated_at': getValue('updatedAt', 'updated_at'),
              };
              
              // Solo incluir campos que no sean null (excepto los que ya tienen defaultValue)
              transformedUser.removeWhere((key, value) => value == null && !['avatar_url', 'last_login_at', 'created_at', 'updated_at'].contains(key));
              
              item['user'] = transformedUser;
            }
            
            final playlist = Playlist.fromJson(item);
            final featuredPlaylist = FeaturedPlaylist(
              playlist: playlist,
              featuredReason: 'Destacada',
              rank: i + 1,
            );
            playlists.add(featuredPlaylist);
          } catch (e) {
            // Error silencioso al parsear playlist individual
          }
        }
        
        return playlists;
      } else {
        return [];
      }
    } on DioException {
      return [];
    } catch (e) {
      return [];
    }
  }


}
