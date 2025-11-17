import 'package:json_annotation/json_annotation.dart';

part 'artist_model.g.dart';

@JsonSerializable(
  fieldRename: FieldRename.snake,
  explicitToJson: true,
  includeIfNull: false,
)
class Artist {
  final String id;
  final String? userId;
  final String? stageName;
  final String? profilePhotoUrl;
  final String? coverPhotoUrl;
  final String? bio;
  final String? websiteUrl;
  final Map<String, dynamic>? socialLinks;
  final bool verificationStatus;
  final int totalStreams;
  final int totalFollowers;
  final int monthlyListeners;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Artist({
    required this.id,
    this.userId,
    this.stageName,
    this.profilePhotoUrl,
    this.coverPhotoUrl,
    this.bio,
    this.websiteUrl,
    this.socialLinks,
    this.verificationStatus = false,
    this.totalStreams = 0,
    this.totalFollowers = 0,
    this.monthlyListeners = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory Artist.fromJson(Map<String, dynamic> json) => _$ArtistFromJson(json);
  Map<String, dynamic> toJson() => _$ArtistToJson(this);

  String get displayName => stageName ?? 'Artista Desconocido';
  bool get isVerified => verificationStatus;

  String? getSocialLink(String platform) => socialLinks?[platform];
}

@JsonSerializable(
  fieldRename: FieldRename.snake,
  explicitToJson: true,
  includeIfNull: false,
)
class FeaturedArtist {
  final Artist artist;
  final String? featuredReason;
  final int rank;
  final String? imageUrl;

  const FeaturedArtist({
    required this.artist,
    this.featuredReason,
    required this.rank,
    this.imageUrl,
  });

  factory FeaturedArtist.fromJson(Map<String, dynamic> json) => _$FeaturedArtistFromJson(json);
  Map<String, dynamic> toJson() => _$FeaturedArtistToJson(this);
}
