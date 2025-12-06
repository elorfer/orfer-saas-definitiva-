import 'package:flutter/foundation.dart';
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
  @JsonKey(name: 'is_verified')
  final bool? isVerified;
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
    this.isVerified,
    this.totalStreams = 0,
    this.totalFollowers = 0,
    this.monthlyListeners = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory Artist.fromJson(Map<String, dynamic> json) => _$ArtistFromJson(json);
  Map<String, dynamic> toJson() => _$ArtistToJson(this);

  String get displayName => stageName ?? 'Artista Desconocido';
  bool get isVerifiedValue {
    final result = isVerified ?? verificationStatus;
    // Debug: Verificar valores de verificación
    if (kDebugMode && (stageName?.contains('ORFER') ?? false)) {
      debugPrint('🔍 [Artist] ${stageName}: isVerified=$isVerified, verificationStatus=$verificationStatus, isVerifiedValue=$result');
    }
    return result;
  }

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
