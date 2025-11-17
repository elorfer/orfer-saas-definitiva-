class ArtistLite {
  final String id;
  final String name;
  final String? profilePhotoUrl;
  final String? coverPhotoUrl;
  final String? nationalityCode;
  final bool featured;

  const ArtistLite({
    required this.id,
    required this.name,
    this.profilePhotoUrl,
    this.coverPhotoUrl,
    this.nationalityCode,
    required this.featured,
  });

  factory ArtistLite.fromJson(Map<String, dynamic> json) {
    return ArtistLite(
      id: json['id'] as String,
      name: (json['name'] ?? json['stageName'] ?? '') as String,
      profilePhotoUrl: json['profilePhotoUrl'] as String?,
      coverPhotoUrl: json['coverPhotoUrl'] as String?,
      nationalityCode: json['nationalityCode'] as String?,
      featured: (json['featured'] ?? json['isFeatured'] ?? false) as bool,
    );
  }
}


