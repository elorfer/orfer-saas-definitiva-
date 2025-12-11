class Genre {
  final String id;
  final String name;
  final String? description;
  final String? colorHex;
  final String? imageUrl;
  final int? songCount;
  final int? albumCount;

  const Genre({
    required this.id,
    required this.name,
    this.description,
    this.colorHex,
    this.imageUrl,
    this.songCount,
    this.albumCount,
  });

  factory Genre.fromJson(Map<String, dynamic> json) {
    return Genre(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      colorHex: json['color_hex'] as String? ?? json['colorHex'] as String?,
      imageUrl: json['image_url'] as String? ?? json['imageUrl'] as String?,
      songCount: (json['song_count'] as num?)?.toInt() ?? (json['songCount'] as num?)?.toInt(),
      albumCount: (json['album_count'] as num?)?.toInt() ?? (json['albumCount'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (description != null) 'description': description,
      if (colorHex != null) 'color_hex': colorHex,
      if (imageUrl != null) 'image_url': imageUrl,
      if (songCount != null) 'song_count': songCount,
      if (albumCount != null) 'album_count': albumCount,
    };
  }
}

