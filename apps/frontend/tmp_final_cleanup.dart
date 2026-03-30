
import 'dart:io';

void main() {
  final file = File('c:/appdefinitiva/apps/frontend/lib/core/navigation/app_router.dart');
  String content = file.readAsStringSync();
  
  // Limpiar cualquier argumento posicional huérfano dentro de MaterialPage
  // Estos son los que están causando el error de "Too many positional arguments"
  
  final List<String> patternsToRemove = [
    r'SpotifyPageTransitions\.\w+,',
    r'const Duration\(milliseconds: \d+\),',
    r'Duration\.zero,',
  ];
  
  for (var pattern in patternsToRemove) {
    // Solo removemos si la línea parece estar dándonos problemas dentro de un MaterialPage
    // Usamos regex con multilínea para ser precisos
    final regex = RegExp('^\\s+$pattern\\s*\$', multiLine: true);
    content = content.replaceAll(regex, '');
  }
  
  // Limpiar posibles líneas en blanco consecutivas resultantes
  content = content.replaceAll(RegExp(r'\n\s*\n\s*\n'), '\n\n');
  
  file.writeAsStringSync(content);
  print('Successfully cleaned up all orphan arguments in app_router.dart');
}
