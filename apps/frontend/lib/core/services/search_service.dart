import 'package:dio/dio.dart';
import 'http_client_service.dart';
import '../utils/error_handler.dart';
import '../models/artist_model.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart';
import '../utils/data_normalizer.dart';

class SearchService {
  static final SearchService _instance = SearchService._internal();
  factory SearchService() => _instance;
  SearchService._internal();

  final HttpClientService _httpClient = HttpClientService();

  /// Inicializar el servicio
  Future<void> initialize() async {
    if (!_httpClient.isInitialized) {
      await _httpClient.initialize();
    }
  }

  /// Realiza una búsqueda global de artistas, canciones y playlists
  Future<SearchResults> search(String query, {int limit = 10}) async {
    try {
      // Asegurar que el servicio esté inicializado
      await initialize();

      if (query.trim().isEmpty) {
        return SearchResults.empty();
      }

      final response = await _httpClient.dio.get(
        '/search',
        queryParameters: {
          'q': query.trim(),
          'limit': limit,
        },
      );

      if (response.statusCode != 200 || response.data == null) {
        throw Exception('Error en la respuesta del servidor: ${response.statusCode}');
      }

      final data = response.data as Map<String, dynamic>;

      // Normalizar y parsear resultados
      final artistsData = (data['artists'] as List<dynamic>?)
              ?.map((item) => DataNormalizer.normalizeArtist(item as Map<String, dynamic>))
              .toList() ??
          [];
      final songsData = (data['songs'] as List<dynamic>?)
              ?.map((item) => DataNormalizer.normalizeSong(item as Map<String, dynamic>))
              .toList() ??
          [];
      final playlistsData = (data['playlists'] as List<dynamic>?)
              ?.map((item) => DataNormalizer.normalizePlaylist(item as Map<String, dynamic>))
              .toList() ??
          [];

      return SearchResults(
        artists: artistsData.map((json) => Artist.fromJson(json)).toList(),
        songs: songsData.map((json) => Song.fromJson(json)).toList(),
        playlists: playlistsData.map((json) => Playlist.fromJson(json)).toList(),
        totals: SearchTotals(
          artists: (data['totals']?['artists'] as num?)?.toInt() ?? 0,
          songs: (data['totals']?['songs'] as num?)?.toInt() ?? 0,
          playlists: (data['totals']?['playlists'] as num?)?.toInt() ?? 0,
        ),
      );
    } on DioException catch (e) {
      ErrorHandler.handleDioError(e, context: 'SearchService.search');
      throw Exception('Error de conexión: ${e.message}');
    } catch (e) {
      ErrorHandler.handleGenericError(e, context: 'SearchService.search');
      rethrow;
    }
  }
}

class SearchResults {
  final List<Artist> artists;
  final List<Song> songs;
  final List<Playlist> playlists;
  final SearchTotals totals;

  SearchResults({
    required this.artists,
    required this.songs,
    required this.playlists,
    required this.totals,
  });

  factory SearchResults.empty() {
    return SearchResults(
      artists: [],
      songs: [],
      playlists: [],
      totals: SearchTotals(artists: 0, songs: 0, playlists: 0),
    );
  }

  bool get isEmpty => artists.isEmpty && songs.isEmpty && playlists.isEmpty;
}

class SearchTotals {
  final int artists;
  final int songs;
  final int playlists;

  SearchTotals({
    required this.artists,
    required this.songs,
    required this.playlists,
  });
}

