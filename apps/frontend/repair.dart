import 'dart:io';

void main() {
  final dir = Directory('lib');
  int count = 0;
  for (var entity in dir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      try {
        var content = entity.readAsStringSync();
        var original = content;
        
        // Repair common utf-8 encoding botches saved as literals
        content = content.replaceAll('Ã¡', 'á');
        content = content.replaceAll('Ã©', 'é');
        content = content.replaceAll('Ã³', 'ó');
        content = content.replaceAll('Ãº', 'ú');
        content = content.replaceAll('Ã±', 'ñ');
        content = content.replaceAll('Â¿', '¿');
        content = content.replaceAll('Â¡', '¡');
        
        // Special case for í which comes as Ã followed by a specific byte
        content = content.replaceAll('Ã­', 'í'); 
        content = content.replaceAll('Ã\xAD', 'í'); 

        content = content.replaceAll('RegÃ­strate', 'Regístrate'); // Specific catch just in case

        if (content != original) {
          entity.writeAsStringSync(content);
          count++;
          print('Repaired ${entity.path}');
        }
      } catch (e) {
        // Skip files that might not be utf-8 readable
      }
    }
  }
  print('Fixed $count files.');
}
