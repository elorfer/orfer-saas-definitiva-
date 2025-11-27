import 'package:flutter_test/flutter_test.dart';
import 'package:vintage_music_app/core/models/playback_context.dart';

void main() {
  group('PlaybackContext', () {
    group('Validaciones', () {
      test('debe rechazar IDs vacíos', () {
        expect(
          () => PlaybackContext.playlist(
            playlistId: '',
            name: 'Test',
            songIds: ['song1'],
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('debe rechazar nombres vacíos', () {
        expect(
          () => PlaybackContext.playlist(
            playlistId: 'playlist1',
            name: '',
            songIds: ['song1'],
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('debe rechazar listas de canciones vacías para playlists', () {
        expect(
          () => PlaybackContext.playlist(
            playlistId: 'playlist1',
            name: 'Test',
            songIds: [],
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('debe rechazar índices fuera de rango', () {
        expect(
          () => PlaybackContext.playlist(
            playlistId: 'playlist1',
            name: 'Test',
            songIds: ['song1', 'song2'],
            startIndex: 5,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('Funcionalidad de shuffle', () {
      test('debe generar índices aleatorios diferentes', () {
        var context = PlaybackContext.playlist(
          playlistId: 'test',
          name: 'Test',
          songIds: ['song1', 'song2', 'song3', 'song4', 'song5'],
          shuffle: true,
        );

        final indices = <int>{};
        
        // Simular navegación a través de múltiples canciones
        for (int i = 0; i < 15; i++) {
          final nextIndex = context.getNextIndex();
          if (nextIndex != null) {
            indices.add(nextIndex);
            // Mover al siguiente índice para continuar la secuencia
            context = context.moveToIndex(nextIndex);
          }
        }

        // Con 5 canciones y shuffle, debe generar al menos 3 índices diferentes
        expect(indices.length, greaterThan(2));
      });

      test('no debe repetir el índice actual inmediatamente', () {
        final context = PlaybackContext.playlist(
          playlistId: 'test',
          name: 'Test',
          songIds: ['song1', 'song2', 'song3'],
          startIndex: 1,
          shuffle: true,
        );

        final nextIndex = context.getNextIndex();
        expect(nextIndex, isNot(equals(1)));
      });
    });

    group('Navegación secuencial', () {
      test('debe avanzar correctamente en orden', () {
        final context = PlaybackContext.playlist(
          playlistId: 'test',
          name: 'Test',
          songIds: ['song1', 'song2', 'song3'],
          startIndex: 0,
        );

        expect(context.getNextIndex(), equals(1));
      });

      test('debe retroceder correctamente en orden', () {
        final context = PlaybackContext.playlist(
          playlistId: 'test',
          name: 'Test',
          songIds: ['song1', 'song2', 'song3'],
          startIndex: 2,
        );

        expect(context.getPreviousIndex(), equals(1));
      });

      test('debe manejar el final de la lista sin repeat', () {
        final context = PlaybackContext.playlist(
          playlistId: 'test',
          name: 'Test',
          songIds: ['song1', 'song2'],
          startIndex: 1,
          repeat: false,
        );

        expect(context.getNextIndex(), isNull);
      });

      test('debe repetir desde el inicio con repeat activado', () {
        final context = PlaybackContext.playlist(
          playlistId: 'test',
          name: 'Test',
          songIds: ['song1', 'song2'],
          startIndex: 1,
          repeat: true,
        );

        expect(context.getNextIndex(), equals(0));
      });
    });

    group('Propiedades computadas', () {
      test('currentSongId debe devolver la canción correcta', () {
        final context = PlaybackContext.playlist(
          playlistId: 'test',
          name: 'Test',
          songIds: ['song1', 'song2', 'song3'],
          startIndex: 1,
        );

        expect(context.currentSongId, equals('song2'));
      });

      test('isValid debe validar contextos correctamente', () {
        final validContext = PlaybackContext.playlist(
          playlistId: 'test',
          name: 'Test',
          songIds: ['song1', 'song2'],
        );

        expect(validContext.isValid, isTrue);
      });

      test('progressInfo debe mostrar información correcta', () {
        final context = PlaybackContext.playlist(
          playlistId: 'test',
          name: 'Test',
          songIds: ['song1', 'song2', 'song3'],
          startIndex: 1,
        );

        expect(context.progressInfo, equals('2 de 3'));
      });
    });

    group('Serialización', () {
      test('debe serializar y deserializar correctamente', () {
        final original = PlaybackContext.playlist(
          playlistId: 'test',
          name: 'Test Playlist',
          description: 'Una playlist de prueba',
          songIds: ['song1', 'song2', 'song3'],
          startIndex: 1,
          shuffle: true,
          repeat: true,
        );

        final json = original.toJson();
        final restored = PlaybackContext.fromJson(json);

        expect(restored.type, equals(original.type));
        expect(restored.id, equals(original.id));
        expect(restored.name, equals(original.name));
        expect(restored.description, equals(original.description));
        expect(restored.songIds, equals(original.songIds));
        expect(restored.currentIndex, equals(original.currentIndex));
        expect(restored.shuffle, equals(original.shuffle));
        expect(restored.repeat, equals(original.repeat));
      });
    });

    group('Contextos específicos', () {
      test('featuredSongs debe permitir lista vacía', () {
        expect(
          () => PlaybackContext.featuredSongs(currentSongId: 'song1'),
          returnsNormally,
        );
      });

      test('featuredSongs no debe soportar shuffle', () {
        final context = PlaybackContext.featuredSongs(currentSongId: 'song1');
        expect(context.type.supportsShuffleMode, isFalse);
      });

      test('album debe desactivar shuffle por defecto', () {
        final context = PlaybackContext.album(
          albumId: 'album1',
          albumName: 'Test Album',
          songIds: ['song1', 'song2'],
        );
        expect(context.shuffle, isFalse);
      });
    });

    group('Historial de shuffle', () {
      test('moveToIndex debe actualizar el historial', () {
        final context = PlaybackContext.playlist(
          playlistId: 'test',
          name: 'Test',
          songIds: ['song1', 'song2', 'song3'],
          shuffle: true,
        );

        final newContext = context.moveToIndex(2);
        expect(newContext.currentIndex, equals(2));
      });

      test('resetShuffleHistory debe funcionar correctamente', () {
        final context = PlaybackContext.playlist(
          playlistId: 'test',
          name: 'Test',
          songIds: ['song1', 'song2', 'song3'],
          shuffle: true,
        );

        // Mover a diferentes índices para crear historial
        final contextWithHistory = context.moveToIndex(1).moveToIndex(2);
        
        // Resetear historial
        final resetContext = contextWithHistory.resetShuffleHistory();
        
        // Verificar que el contexto sigue siendo válido
        expect(resetContext.isValid, isTrue);
        expect(resetContext.shuffle, isTrue);
      });
    });
  });
}
