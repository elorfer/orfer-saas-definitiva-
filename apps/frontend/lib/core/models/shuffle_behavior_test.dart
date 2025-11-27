/// Test específico para verificar el comportamiento del shuffle
library;

import 'dart:developer' as developer;
import 'playback_context.dart';

void testShuffleBehavior() {
  developer.log('🎯 Probando comportamiento del shuffle...\n');
  
  // Test 1: Verificar que no repite canciones inmediatamente
  _testNoImmediateRepeats();
  
  // Test 2: Verificar que eventualmente reproduce todas las canciones
  _testEventuallyPlaysAll();
  
  // Test 3: Verificar comportamiento con repeat
  _testRepeatBehavior();
  
  developer.log('\n✅ ¡Comportamiento del shuffle validado!');
}

void _testNoImmediateRepeats() {
  developer.log('📊 Test 1: Sin repeticiones inmediatas');
  
  final context = PlaybackContext.playlist(
    playlistId: 'test_no_repeat',
    name: 'Test No Repeat',
    songIds: List.generate(10, (i) => 'song_$i'),
    shuffle: true,
  );
  
  var currentContext = context;
  final playedSongs = <int>[];
  
  // Reproducir 5 canciones y verificar que no se repiten
  for (int i = 0; i < 5; i++) {
    final nextIndex = currentContext.getNextIndex();
    if (nextIndex != null) {
      if (playedSongs.contains(nextIndex)) {
        developer.log('   ❌ ERROR: Canción $nextIndex repetida en posición $i');
        return;
      }
      playedSongs.add(nextIndex);
      currentContext = currentContext.moveToIndex(nextIndex);
      developer.log('   🎵 Reproduciendo canción $nextIndex');
    }
  }
  
  developer.log('   ✅ Sin repeticiones inmediatas detectadas');
}

void _testEventuallyPlaysAll() {
  developer.log('\n📊 Test 2: Eventualmente reproduce todas');
  
  final songCount = 8;
  final context = PlaybackContext.playlist(
    playlistId: 'test_all_songs',
    name: 'Test All Songs',
    songIds: List.generate(songCount, (i) => 'song_$i'),
    shuffle: true,
    repeat: true,
  );
  
  var currentContext = context;
  final playedSongs = <int>{};
  var iterations = 0;
  final maxIterations = songCount * 3; // Máximo 3 vueltas completas
  
  // Reproducir hasta que hayamos escuchado todas las canciones
  while (playedSongs.length < songCount && iterations < maxIterations) {
    final nextIndex = currentContext.getNextIndex();
    if (nextIndex != null) {
      playedSongs.add(nextIndex);
      currentContext = currentContext.moveToIndex(nextIndex);
      iterations++;
    } else {
      break;
    }
  }
  
  if (playedSongs.length == songCount) {
    developer.log('   ✅ Todas las canciones fueron reproducidas ($iterations iteraciones)');
  } else {
    developer.log('   ❌ ERROR: Solo ${playedSongs.length}/$songCount canciones reproducidas');
  }
}

void _testRepeatBehavior() {
  developer.log('\n📊 Test 3: Comportamiento con repeat');
  
  final context = PlaybackContext.playlist(
    playlistId: 'test_repeat',
    name: 'Test Repeat',
    songIds: List.generate(5, (i) => 'song_$i'),
    shuffle: true,
    repeat: true,
  );
  
  var currentContext = context;
  var songsPlayed = 0;
  const targetSongs = 12; // Más de una vuelta completa
  
  // Reproducir más canciones de las que hay en la playlist
  for (int i = 0; i < targetSongs; i++) {
    final nextIndex = currentContext.getNextIndex();
    if (nextIndex != null) {
      currentContext = currentContext.moveToIndex(nextIndex);
      songsPlayed++;
    } else {
      developer.log('   ❌ ERROR: Shuffle terminó prematuramente en iteración $i');
      return;
    }
  }
  
  if (songsPlayed == targetSongs) {
    developer.log('   ✅ Repeat funciona correctamente ($songsPlayed canciones reproducidas)');
  } else {
    developer.log('   ❌ ERROR: Solo $songsPlayed/$targetSongs canciones reproducidas con repeat');
  }
}

// Ejecutar test
void main() {
  testShuffleBehavior();
}
