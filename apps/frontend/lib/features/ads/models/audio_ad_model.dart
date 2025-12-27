/// Modelo de datos para anuncios de audio
/// Traducción directa del DTO del Backend
class AudioAd {
  final String id;
  final String title;
  final String? description;
  final String audioUrl;
  final String? coverImageUrl;
  final String advertiserName;
  final String? clickThroughUrl;
  final Duration duration; // Usar Duration en Flutter
  final bool isSkippable;
  final int skipAfterSeconds;

  final int totalPlays;
  final int totalClicks;

  AudioAd({
    required this.id,
    required this.title,
    this.description,
    required this.audioUrl,
    this.coverImageUrl,
    required this.advertiserName,
    this.clickThroughUrl,
    required this.duration,
    this.isSkippable = true,
    this.skipAfterSeconds = 5,
    this.totalPlays = 0,
    this.totalClicks = 0,
  });

  factory AudioAd.fromJson(Map<String, dynamic> json) {
    // ✅ NORMALIZACIÓN: Manejar tanto camelCase como snake_case
    final audioUrl = json['audioUrl'] as String? ?? json['audio_url'] as String?;
    final coverImageUrl = json['coverImageUrl'] as String? ?? json['cover_image_url'] as String?;
    final advertiserName = json['advertiserName'] as String? ?? json['advertiser_name'] as String?;
    final clickThroughUrl = json['clickThroughUrl'] as String? ?? json['click_through_url'] as String?;
    final durationSeconds = json['durationSeconds'] as int? ?? json['duration_seconds'] as int?;
    final isSkippable = json['isSkippable'] as bool? ?? json['is_skippable'] as bool?;
    final skipAfterSeconds = json['skipAfterSeconds'] as int? ?? json['skip_after_seconds'] as int?;
    
    // Validar que audioUrl esté presente (requerido)
    if (audioUrl == null || audioUrl.isEmpty) {
      throw Exception('AudioAd.fromJson: audioUrl es requerido pero está vacío o nulo');
    }
    
    // Validar que advertiserName esté presente (requerido)
    if (advertiserName == null || advertiserName.isEmpty) {
      throw Exception('AudioAd.fromJson: advertiserName es requerido pero está vacío o nulo');
    }
    
    return AudioAd(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      audioUrl: audioUrl,
      coverImageUrl: coverImageUrl,
      advertiserName: advertiserName,
      clickThroughUrl: clickThroughUrl,
      // CRÍTICO: Mapeo de duración desde segundos a Duration
      duration: Duration(seconds: durationSeconds ?? 0),
      isSkippable: isSkippable ?? true,
      skipAfterSeconds: skipAfterSeconds ?? 5,
      totalPlays: json['totalPlays'] as int? ?? json['total_plays'] as int? ?? 0,
      totalClicks: json['totalClicks'] as int? ?? json['total_clicks'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'audioUrl': audioUrl,
      'coverImageUrl': coverImageUrl,
      'advertiserName': advertiserName,
      'clickThroughUrl': clickThroughUrl,
      'durationSeconds': duration.inSeconds,
      'isSkippable': isSkippable,
      'skipAfterSeconds': skipAfterSeconds,
    };
  }

  @override
  String toString() {
    return 'AudioAd(id: $id, title: $title, advertiser: $advertiserName, duration: ${duration.inSeconds}s)';
  }
}





