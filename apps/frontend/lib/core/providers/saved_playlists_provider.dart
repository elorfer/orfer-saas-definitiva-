import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playlist_model.dart';
import '../utils/logger.dart';

/// Estado del provider de playlists guardadas
class SavedPlaylistsState {
  final List<Playlist> playlists;
  final Set<String> savedIds;
  final bool isLoading;

  const SavedPlaylistsState({
    this.playlists = const [],
    this.savedIds = const {},
    this.isLoading = true,
  });

  SavedPlaylistsState copyWith({
    List<Playlist>? playlists,
    Set<String>? savedIds,
    bool? isLoading,
  }) {
    return SavedPlaylistsState(
      playlists: playlists ?? this.playlists,
      savedIds: savedIds ?? this.savedIds,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Provider para gestionar playlists guardadas localmente (Likes)
class SavedPlaylistsNotifier extends Notifier<SavedPlaylistsState> {
  static const String _boxName = 'saved_playlists_v1';
  Box<String>? _box;
  bool _isInitialized = false;

  @override
  SavedPlaylistsState build() {
    _init();
    return const SavedPlaylistsState();
  }

  Future<void> _init() async {
    if (_isInitialized) return;

    try {
      _box = await Hive.openBox<String>(_boxName);
      _loadFromBox();
      _isInitialized = true;
    } catch (e) {
      AppLogger.error('[SavedPlaylists] Error initializing Hive box: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  void _loadFromBox() {
    if (_box == null) return;

    try {
      final playlists = <Playlist>[];
      final savedIds = <String>{};

      for (var i = 0; i < _box!.length; i++) {
        final jsonStr = _box!.getAt(i);
        if (jsonStr != null) {
          try {
            final Map<String, dynamic> json = jsonDecode(jsonStr);
            final playlist = Playlist.fromJson(json);
            playlists.add(playlist);
            savedIds.add(playlist.id);
          } catch (e) {
            AppLogger.error('[SavedPlaylists] Error parsing playlist at index $i: $e');
          }
        }
      }

      // Ordenar por nombre o fecha si es necesario (aquí por orden de inserción reverso para mostrar las últimas primero)
      // Opcional: playlists.sort((a, b) => ...);
      
      state = state.copyWith(
        playlists: playlists.reversed.toList(), // Mostrar las más recientes primero
        savedIds: savedIds,
        isLoading: false,
      );
      
      AppLogger.info('[SavedPlaylists] Loaded ${playlists.length} playlists');
    } catch (e) {
      AppLogger.error('[SavedPlaylists] Error loading from box: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  /// Toggle like/save status of a playlist
  Future<void> toggleSave(Playlist playlist) async {
    if (_box == null) await _init();

    final isSaved = state.savedIds.contains(playlist.id);
    final currentPlaylists = List<Playlist>.from(state.playlists);
    final currentIds = Set<String>.from(state.savedIds);

    try {
      if (isSaved) {
        // Remover
        currentPlaylists.removeWhere((p) => p.id == playlist.id);
        currentIds.remove(playlist.id);
        
        // Encontrar la clave en Hive para borrar (esto es O(N) desafortunadamente con Hive boxes indexados por int)
        // Para optimizar, podríamos usar un MapBox, pero por ahora iteramos o guardamos key mapping.
        // Dado que Hive guarda keys, podemos buscar la key asociada a este valor.
        // Una estrategia mejor es usar el ID de la playlist como Key en Hive.
        
        // Re-implementando con ID como Key para O(1) delete
        await _box!.delete(playlist.id);
        
      } else {
        // Guardar
        // Insertar al inicio para UX "agregado recientemente"
        currentPlaylists.insert(0, playlist);
        currentIds.add(playlist.id);
        
        await _box!.put(playlist.id, jsonEncode(playlist.toJson()));
      }

      state = state.copyWith(
        playlists: currentPlaylists,
        savedIds: currentIds,
      );
      
      AppLogger.info('[SavedPlaylists] ${isSaved ? 'Removed' : 'Saved'} playlist: ${playlist.name}');

    } catch (e) {
      AppLogger.error('[SavedPlaylists] Error toggling save: $e');
    }
  }

  bool isSaved(String id) => state.savedIds.contains(id);
}

/// Provider global
final savedPlaylistsProvider = NotifierProvider<SavedPlaylistsNotifier, SavedPlaylistsState>(() {
  return SavedPlaylistsNotifier();
});
