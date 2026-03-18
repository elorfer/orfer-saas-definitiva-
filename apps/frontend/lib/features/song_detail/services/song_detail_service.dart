import 'package:dio/dio.dart';
import '../../../core/models/song_model.dart';
import '../../../core/services/http_client_service.dart';
import '../../../core/utils/retry_handler.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/utils/data_normalizer.dart';
import '../../../core/utils/response_parser.dart';
import '../../../core/utils/url_normalizer.dart';

/// Servicio para obtener información de canciones y canciones por artista
class SongDetailService {
  static final SongDetailService _instance = SongDetailService._internal();
  factory SongDetailService() => _instance;
  SongDetailService._internal();

  final HttpClientService _httpClient = HttpClientService();

  /// Obtener instancia de Dio del HttpClientService
  Dio get _dio => _httpClient.dio;

  /// Inicializar el servicio
  Future<void> initialize() async {
    if (!_httpClient.isInitialized) {
      await _httpClient.initialize();
    }
  }

  /// Obtener canciones por artista
  Future<List<Song>> getSongsByArtist(String artistId, {int limit = 50}) async {
    try {
      final response = await RetryHandler.retryDataLoad(
        shouldRetry: RetryHandler.isDioErrorRetryable,
        operation: () => _dio.get(
          '/public/songs',
          queryParameters: {
            'artistId': artistId,
            'limit': limit,
            'all': 'true', // Incluir todas las canciones publicadas
          },
        ),
      );

      if (ResponseParser.isSuccess(response)) {
        final data = ResponseParser.extractList(response, listKey: 'songs');
        final validData = ResponseParser.validateList(data);
        
        if (validData.isEmpty) {
          return [];
        }
        
        final normalizedList = validData
            .map((json) => DataNormalizer.normalizeSong(Map<String, dynamic>.from(json as Map)))
            .toList();

        for (final n in normalizedList) {
          final rawCoverUrl = n['cover_art_url'] as String?;
          final normalizedCoverUrl = UrlNormalizer.normalizeImageUrl(rawCoverUrl);
          if (normalizedCoverUrl != null) {
            n['cover_art_url'] = normalizedCoverUrl;
          }
        }

        try {
          return await Song.parseList(normalizedList);
        } catch (_) {
          final parsed = <Song>[];
          for (final n in normalizedList) {
            try {
              parsed.add(Song.fromJson(n));
            } catch (_) {}
          }
          return parsed;
        }
      } else {
        return [];
      }
    } on DioException catch (e) {
      ErrorHandler.handleDioError(e, context: 'SongDetailService.getSongsByArtist');
      return [];
    } catch (e) {
      ErrorHandler.handleGenericError(e, context: 'SongDetailService.getSongsByArtist');
      return [];
    }
  }

  /// Obtener una canción por ID
  Future<Song?> getSongById(String songId) async {
    try {
      final response = await RetryHandler.retryDataLoad(
        shouldRetry: RetryHandler.isDioErrorRetryable,
        operation: () => _dio.get('/public/songs/$songId'),
      );

      if (ResponseParser.isSuccess(response)) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final normalized = DataNormalizer.normalizeSong(data);
          
          // Normalizar URL de portada
          final rawCoverUrl = normalized['cover_art_url'] as String?;
          final normalizedCoverUrl = UrlNormalizer.normalizeImageUrl(rawCoverUrl);
          if (normalizedCoverUrl != null) {
            normalized['cover_art_url'] = normalizedCoverUrl;
            normalized['coverArtUrl'] = normalizedCoverUrl;
          }
          
          // Normalizar URL del archivo de audio
          final rawFileUrl = normalized['file_url'] as String?;
          if (rawFileUrl != null && rawFileUrl.isNotEmpty) {
            final normalizedFileUrl = UrlNormalizer.normalizeUrl(rawFileUrl);
            normalized['file_url'] = normalizedFileUrl;
            normalized['fileUrl'] = normalizedFileUrl;
          }
          
          // 🆕 Normalizar URL del avatar del artista si existe
          if (normalized['artist'] is Map<String, dynamic>) {
            final artistData = normalized['artist'] as Map<String, dynamic>;
            final rawArtistAvatarUrl = artistData['profile_photo_url'] as String?;
            
            // 🆕 OPTIMIZACIÓN: No cargar artista completo aquí (se hace de forma asíncrona en la UI)
            // Esto permite que la pantalla se muestre inmediatamente mientras se carga el avatar en segundo plano
            if (rawArtistAvatarUrl != null && rawArtistAvatarUrl.isNotEmpty) {
              final normalizedArtistAvatarUrl = UrlNormalizer.normalizeImageUrl(rawArtistAvatarUrl);
              if (normalizedArtistAvatarUrl != null) {
                artistData['profile_photo_url'] = normalizedArtistAvatarUrl;
                normalized['artist'] = artistData;
              }
            }
          }
          
          return await Song.parse(normalized);
        }
      }
      return null;
    } on DioException catch (e) {
      ErrorHandler.handleDioError(e, context: 'SongDetailService.getSongById');
      return null;
    } catch (e) {
      ErrorHandler.handleGenericError(e, context: 'SongDetailService.getSongById');
      return null;
    }
  }
}

