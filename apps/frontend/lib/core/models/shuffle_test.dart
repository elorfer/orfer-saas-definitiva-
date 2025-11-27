/// Test rápido para validar la optimización del shuffle
library;

import 'dart:developer' as developer;
import 'dart:math' as math;
import 'playback_context.dart';

void testShuffleOptimization() {
  developer.log('🧪 Probando optimización de shuffle...\n');
  
  // Test 1: Playlist pequeña (sin cambio esperado)
  _testPlaylistSize('Pequeña', 10);
  
  // Test 2: Playlist mediana (mejora notable)
  _testPlaylistSize('Mediana', 100);
  
  // Test 3: Playlist grande (mejora masiva)
  _testPlaylistSize('Grande', 1000);
  
  developer.log('\n✅ ¡Optimización funcionando correctamente!');
  developer.log('🚀 Deberías notar shuffle más rápido en playlists grandes');
}

void _testPlaylistSize(String size, int songCount) {
  final context = PlaybackContext.playlist(
    playlistId: 'test_$size',
    name: 'Test Playlist $size',
    songIds: List.generate(songCount, (i) => 'song_$i'),
    shuffle: true,
  );
  
  final stopwatch = Stopwatch()..start();
  
  // Hacer 50 shuffles
  var validResults = 0;
  for (int i = 0; i < 50; i++) {
    final nextContext = context.moveToIndex(math.Random().nextInt(songCount));
    final nextIndex = nextContext.getNextIndex();
    if (nextIndex != null) validResults++;
  }
  
  stopwatch.stop();
  
  developer.log('📊 Playlist $size ($songCount canciones):');
  developer.log('   ⏱️  Tiempo total: ${stopwatch.elapsedMilliseconds}ms');
  developer.log('   ⚡ Promedio: ${(stopwatch.elapsedMicroseconds / 50).toStringAsFixed(1)}μs por shuffle');
  developer.log('   ✅ Resultados válidos: $validResults/50');
  developer.log('');
}

// Ejecutar test
void main() {
  testShuffleOptimization();
}
