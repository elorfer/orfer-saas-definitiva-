// ignore_for_file: unused_local_variable, dangling_library_doc_comments, unintended_html_in_doc_comment

/*
 Utility helpers to normalize genre names coming from backend or UI.

 Usage:
 final normalized = normalizeGenres(input);
 // normalized -> List<String> of trimmed, lowercased, unique genre names
*/

List<String> normalizeGenres(dynamic input) {
  if (input == null) return <String>[];

  // Accept either a single comma-separated String or a List
  Iterable<String> raw;
  if (input is String) {
    // split by comma to accept both "pop,salsa" and single names
    raw = input.split(',');
  } else if (input is Iterable) {
    raw = input.map((e) => e?.toString() ?? '');
  } else {
    raw = [input.toString()];
  }

  final seen = <String>{};
  final result = <String>[];

  for (final r in raw) {
    final trimmed = r.trim();
    if (trimmed.isEmpty) continue;
    final lower = trimmed.toLowerCase();
    if (seen.add(lower)) result.add(lower);
  }

  return result;
}

String normalizeGenreName(String input) => input.trim().toLowerCase();

bool isValidUuid(String? id) {
  if (id == null) return false;
  final uuidReg = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
  return uuidReg.hasMatch(id);
}
