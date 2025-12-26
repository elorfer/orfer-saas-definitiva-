class ArtistLite {
  final String id;
  final String name;
  final String? profilePhotoUrl;
  final String? coverPhotoUrl;
  final String? nationalityCode;
  final bool featured;
  final int totalFollowers;
  final int totalStreams;
  final int monthlyListeners;

  const ArtistLite({
    required this.id,
    required this.name,
    this.profilePhotoUrl,
    this.coverPhotoUrl,
    this.nationalityCode,
    required this.featured,
    this.totalFollowers = 0,
    this.totalStreams = 0,
    this.monthlyListeners = 0,
  });

  factory ArtistLite.fromJson(Map<String, dynamic> json) {
    return ArtistLite(
      id: json['id'] as String,
      name: (json['name'] ?? json['stageName'] ?? '') as String,
      profilePhotoUrl: json['profilePhotoUrl'] as String?,
      coverPhotoUrl: json['coverPhotoUrl'] as String?,
      nationalityCode: json['nationalityCode'] as String?,
      featured: (json['featured'] ?? json['isFeatured'] ?? false) as bool,
      totalFollowers: (json['totalFollowers'] ?? json['total_followers'] ?? 0) as int,
      totalStreams: (json['totalStreams'] ?? json['total_streams'] ?? 0) as int,
      monthlyListeners: (json['monthlyListeners'] ?? json['monthly_listeners'] ?? 0) as int,
    );
  }

  /// Método copyWith robusto para actualizaciones inmutables
  /// Permite actualizar propiedades individuales sin mutar el objeto original
  ArtistLite copyWith({
    String? id,
    String? name,
    String? profilePhotoUrl,
    String? coverPhotoUrl,
    String? nationalityCode,
    bool? featured,
    int? totalFollowers,
    int? totalStreams,
    int? monthlyListeners,
    // Parámetros especiales para setear null explícitamente
    bool clearProfilePhotoUrl = false,
    bool clearCoverPhotoUrl = false,
    bool clearNationalityCode = false,
  }) {
    return ArtistLite(
      id: id ?? this.id,
      name: name ?? this.name,
      profilePhotoUrl: clearProfilePhotoUrl ? null : (profilePhotoUrl ?? this.profilePhotoUrl),
      coverPhotoUrl: clearCoverPhotoUrl ? null : (coverPhotoUrl ?? this.coverPhotoUrl),
      nationalityCode: clearNationalityCode ? null : (nationalityCode ?? this.nationalityCode),
      featured: featured ?? this.featured,
      totalFollowers: totalFollowers ?? this.totalFollowers,
      totalStreams: totalStreams ?? this.totalStreams,
      monthlyListeners: monthlyListeners ?? this.monthlyListeners,
    );
  }

  /// Serialización a JSON para persistencia en Hive
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'profilePhotoUrl': profilePhotoUrl,
      'coverPhotoUrl': coverPhotoUrl,
      'nationalityCode': nationalityCode,
      'featured': featured,
      'totalFollowers': totalFollowers,
      'totalStreams': totalStreams,
      'monthlyListeners': monthlyListeners,
    };
  }

  /// Nombre para mostrar (preferir name)
  String get displayName => name.isNotEmpty ? name : 'Artista desconocido';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ArtistLite && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ArtistLite(id: $id, name: $name, followers: $totalFollowers)';
}


