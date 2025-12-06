import 'package:dio/dio.dart';
import '../config/app_config.dart';
import 'http_client_service.dart';
import '../utils/logger.dart';
import '../../features/artists/models/artist.dart';

/// Servicio API para manejar el seguimiento de artistas
class FollowArtistsApi {
  final HttpClientService _httpClient = HttpClientService();
  final String baseUrl = AppConfig.baseUrl;

  Dio get _dio => _httpClient.dio;

  Uri _buildUri(String path, [Map<String, dynamic>? queryParams]) {
    final uri = Uri.parse(baseUrl);
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.port,
      path: '${uri.path.replaceAll(RegExp(r'\/$'), '')}/public/artists$path',
      queryParameters: queryParams?.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  /// Seguir un artista
  Future<Map<String, dynamic>> followArtist(String artistId) async {
    try {
      final uri = _buildUri('/$artistId/follow');
      final response = await _dio.post(uri.toString());
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('Error ${response.statusCode}: ${response.data}');
      }
    } catch (e) {
      AppLogger.error('[FollowArtistsApi] Error siguiendo artista $artistId', e);
      rethrow;
    }
  }

  /// Dejar de seguir un artista
  Future<Map<String, dynamic>> unfollowArtist(String artistId) async {
    try {
      final uri = _buildUri('/$artistId/follow');
      final response = await _dio.delete(uri.toString());
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('Error ${response.statusCode}: ${response.data}');
      }
    } catch (e) {
      AppLogger.error('[FollowArtistsApi] Error dejando de seguir artista $artistId', e);
      rethrow;
    }
  }

  /// Verificar si un usuario sigue a un artista
  Future<bool> isFollowing(String artistId, {String? userId}) async {
    try {
      final queryParams = userId != null ? {'userId': userId} : null;
      final uri = _buildUri('/$artistId/is-followed', queryParams);
      final response = await _dio.get(uri.toString());
      
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return data['isFollowing'] as bool? ?? false;
      } else {
        throw Exception('Error ${response.statusCode}: ${response.data}');
      }
    } catch (e) {
      AppLogger.error('[FollowArtistsApi] Error verificando seguimiento', e);
      return false;
    }
  }

  /// Obtener lista de artistas seguidos por el usuario autenticado
  Future<List<ArtistLite>> getMyFollowedArtists() async {
    try {
      final uri = _buildUri('/followed/mine');
      final response = await _dio.get(uri.toString());
      
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final List artistsData = data['artists'] as List? ?? [];
        return artistsData
            .map((json) => ArtistLite.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Error ${response.statusCode}: ${response.data}');
      }
    } catch (e) {
      AppLogger.error('[FollowArtistsApi] Error obteniendo artistas seguidos', e);
      rethrow;
    }
  }

  /// Obtener lista de artistas seguidos por un usuario específico
  Future<List<ArtistLite>> getFollowedArtistsByUser(String userId) async {
    try {
      final uri = Uri.parse(baseUrl);
      final fullUri = Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.port,
        path: '${uri.path.replaceAll(RegExp(r'\/$'), '')}/users/$userId/followed-artists',
      );
      final response = await _dio.get(fullUri.toString());
      
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final List artistsData = data['artists'] as List? ?? [];
        return artistsData
            .map((json) => ArtistLite.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Error ${response.statusCode}: ${response.data}');
      }
    } catch (e) {
      AppLogger.error('[FollowArtistsApi] Error obteniendo artistas seguidos de usuario $userId', e);
      rethrow;
    }
  }
}





