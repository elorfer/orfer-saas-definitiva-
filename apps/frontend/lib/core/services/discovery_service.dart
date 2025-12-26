import 'package:dio/dio.dart';
import '../models/song_model.dart';
import 'http_client_service.dart';
import '../utils/logger.dart';

/// 🔮 Discovery Service - SIMPLIFICADO
/// 
/// Motor de recomendación basado en géneros.
/// Simple, rápido y confiable.
class DiscoveryService {
  static final DiscoveryService _instance = DiscoveryService._internal();
  factory DiscoveryService() => _instance;
  DiscoveryService._internal();

  final HttpClientService _httpClient = HttpClientService();

  /// 🎯 Obtener siguiente canción para autoplay
  /// 
  /// [genreId]: ID del género de la canción actual
  /// [genres]: Lista de nombres de géneros
  /// [currentSongId]: ID de la canción actual (para excluir)
  /// [excludeIds]: IDs adicionales a excluir
  /// [count]: Número de canciones a obtener
  Future<NextUpResult> getNextUp({
    String? genreId,
    List<String> genres = const [],
    required String currentSongId,
    List<String> excludeIds = const [],
    int count = 5,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'currentSongId': currentSongId,
        'count': count.toString(),
        if (genreId != null) 'genreId': genreId,
        if (genres.isNotEmpty) 'genres': genres.join(','),
        if (excludeIds.isNotEmpty) 'excludeIds': excludeIds.join(','),
      };

      final response = await _httpClient.dio.get(
        '/discovery/next-up',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final songs = await Song.parseList(data['songs'] as List? ?? []);
        final metadata = NextUpMetadata.fromJson(data['metadata'] ?? {});
        return NextUpResult(songs: songs, metadata: metadata);
      } else {
        AppLogger.warning('[DiscoveryService] Error ${response.statusCode}: ${response.data}');
        return NextUpResult.empty();
      }
    } on DioException catch (e) {
      AppLogger.error('[DiscoveryService] getNextUp error: ${e.message}');
      return NextUpResult.empty();
    } catch (e) {
      AppLogger.error('[DiscoveryService] getNextUp error: $e');
      return NextUpResult.empty();
    }
  }
}

/// 🎵 Resultado de next-up
class NextUpResult {
  final List<Song> songs;
  final NextUpMetadata metadata;

  NextUpResult({
    required this.songs,
    required this.metadata,
  });

  factory NextUpResult.fromJson(Map<String, dynamic> json) {
    return NextUpResult(
      songs: (json['songs'] as List? ?? [])
          .map((s) => Song.fromJson(s))
          .toList(),
      metadata: NextUpMetadata.fromJson(json['metadata'] ?? {}),
    );
  }

  factory NextUpResult.empty() {
    return NextUpResult(
      songs: [],
      metadata: NextUpMetadata.empty(),
    );
  }

  bool get isEmpty => songs.isEmpty;
  bool get isNotEmpty => songs.isNotEmpty;
}

class NextUpMetadata {
  final String? genreId;
  final List<String> genres;
  final int count;
  final int processingTimeMs;

  NextUpMetadata({
    this.genreId,
    required this.genres,
    required this.count,
    required this.processingTimeMs,
  });

  factory NextUpMetadata.fromJson(Map<String, dynamic> json) {
    return NextUpMetadata(
      genreId: json['genreId'],
      genres: List<String>.from(json['genres'] ?? []),
      count: json['count'] ?? 0,
      processingTimeMs: json['processingTimeMs'] ?? 0,
    );
  }

  factory NextUpMetadata.empty() => NextUpMetadata(
        genres: [],
        count: 0,
        processingTimeMs: 0,
      );
}
