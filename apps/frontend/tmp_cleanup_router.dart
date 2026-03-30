
import 'dart:io';

void main() {
  final file = File('c:/appdefinitiva/apps/frontend/lib/core/navigation/app_router.dart');
  final lines = file.readAsLinesSync();
  final newLines = <String>[];
  
  bool insideMaterialPage = false;
  
  for (var line in lines) {
    String trimmed = line.trim();
    
    // Convert createCustomTransitionPage to MaterialPage
    if (trimmed.contains('createCustomTransitionPage<void>(')) {
      line = line.replaceFirst('createCustomTransitionPage<void>(', 'MaterialPage<void>(');
      insideMaterialPage = true;
    } else if (trimmed.contains('MaterialPage<void>(')) {
      insideMaterialPage = true;
    }
    
    // If we hit the end of the block (the closing );)
    if (insideMaterialPage && trimmed == ');') {
      insideMaterialPage = false;
    }
    
    // If inside MaterialPage, skip invalid parameters
    if (insideMaterialPage) {
      if (trimmed.startsWith('transitionsBuilder:') || 
          trimmed.startsWith('transitionDuration:') || 
          trimmed.startsWith('reverseTransitionDuration:')) {
        continue;
      }
    }
    
    newLines.add(line);
  }
  
  file.writeAsStringSync(newLines.join('\n'));
  print('Successfully cleaned up app_router.dart');
}
