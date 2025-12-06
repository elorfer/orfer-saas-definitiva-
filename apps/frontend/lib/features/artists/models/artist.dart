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
}


