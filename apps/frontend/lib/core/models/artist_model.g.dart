// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'artist_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Artist _$ArtistFromJson(Map<String, dynamic> json) => Artist(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      stageName: json['stage_name'] as String?,
      profilePhotoUrl: json['profile_photo_url'] as String?,
      coverPhotoUrl: json['cover_photo_url'] as String?,
      bio: json['bio'] as String?,
      websiteUrl: json['website_url'] as String?,
      socialLinks: json['social_links'] as Map<String, dynamic>?,
      verificationStatus: json['verification_status'] as bool? ?? false,
      totalStreams: (json['total_streams'] as num?)?.toInt() ?? 0,
      totalFollowers: (json['total_followers'] as num?)?.toInt() ?? 0,
      monthlyListeners: (json['monthly_listeners'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$ArtistToJson(Artist instance) {
  final val = <String, dynamic>{
    'id': instance.id,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('user_id', instance.userId);
  writeNotNull('stage_name', instance.stageName);
  writeNotNull('profile_photo_url', instance.profilePhotoUrl);
  writeNotNull('cover_photo_url', instance.coverPhotoUrl);
  writeNotNull('bio', instance.bio);
  writeNotNull('website_url', instance.websiteUrl);
  writeNotNull('social_links', instance.socialLinks);
  val['verification_status'] = instance.verificationStatus;
  val['total_streams'] = instance.totalStreams;
  val['total_followers'] = instance.totalFollowers;
  val['monthly_listeners'] = instance.monthlyListeners;
  writeNotNull('created_at', instance.createdAt?.toIso8601String());
  writeNotNull('updated_at', instance.updatedAt?.toIso8601String());
  return val;
}

FeaturedArtist _$FeaturedArtistFromJson(Map<String, dynamic> json) =>
    FeaturedArtist(
      artist: Artist.fromJson(json['artist'] as Map<String, dynamic>),
      featuredReason: json['featured_reason'] as String?,
      rank: (json['rank'] as num).toInt(),
      imageUrl: json['image_url'] as String?,
    );

Map<String, dynamic> _$FeaturedArtistToJson(FeaturedArtist instance) {
  final val = <String, dynamic>{
    'artist': instance.artist.toJson(),
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('featured_reason', instance.featuredReason);
  val['rank'] = instance.rank;
  writeNotNull('image_url', instance.imageUrl);
  return val;
}
