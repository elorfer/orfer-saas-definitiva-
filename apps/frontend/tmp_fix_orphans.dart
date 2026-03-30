
import 'dart:io';

void main() {
  final file = File('c:/appdefinitiva/apps/frontend/lib/core/navigation/app_router.dart');
  String content = file.readAsStringSync();
  
  // Limpiar líneas huérfanas de Duration que quedaron tras el refactor anterior
  // Buscamos patrones como:
  // ),
  //     const Duration(milliseconds: 250),
  // ),
  
  // Expresión regular para encontrar el patrón de cierre con la duración huérfana
  final orphanDurationRegex = RegExp(
    r'\),\s+const Duration\(milliseconds: \d+\),\s+\),',
    multiLine: true,
  );
  
  final cleanedContent = content.replaceAll(orphanDurationRegex, '),\n                  ),');
  
  // Guardar el archivo limpio
  file.writeAsStringSync(cleanedContent);
  print('Successfully cleaned up orphan durations in app_router.dart');
}
