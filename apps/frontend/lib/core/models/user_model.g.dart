// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
      id: json['id'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: $enumDecode(_$UserRoleEnumMap, json['role']),
      subscriptionStatus:
          $enumDecode(_$SubscriptionStatusEnumMap, json['subscription_status']),
      isVerified: json['is_verified'] as bool?,
      isActive: json['is_active'] as bool?,
      lastLoginAt: json['last_login_at'] == null
          ? null
          : DateTime.parse(json['last_login_at'] as String),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      artist: json['artist'] == null
          ? null
          : Artist.fromJson(json['artist'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$UserToJson(User instance) {
  final val = <String, dynamic>{
    'id': instance.id,
    'email': instance.email,
    'username': instance.username,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('first_name', instance.firstName);
  writeNotNull('last_name', instance.lastName);
  writeNotNull('avatar_url', instance.avatarUrl);
  val['role'] = _$UserRoleEnumMap[instance.role]!;
  val['subscription_status'] =
      _$SubscriptionStatusEnumMap[instance.subscriptionStatus]!;
  writeNotNull('is_verified', instance.isVerified);
  writeNotNull('is_active', instance.isActive);
  writeNotNull('last_login_at', instance.lastLoginAt?.toIso8601String());
  writeNotNull('created_at', instance.createdAt?.toIso8601String());
  writeNotNull('updated_at', instance.updatedAt?.toIso8601String());
  writeNotNull('artist', instance.artist?.toJson());
  return val;
}

const _$UserRoleEnumMap = {
  UserRole.user: 'user',
  UserRole.artist: 'artist',
  UserRole.admin: 'admin',
};

const _$SubscriptionStatusEnumMap = {
  SubscriptionStatus.free: 'FREE',
  SubscriptionStatus.premium: 'PREMIUM',
  SubscriptionStatus.vip: 'VIP',
  SubscriptionStatus.inactive: 'inactive',
};

Artist _$ArtistFromJson(Map<String, dynamic> json) => Artist(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      stageName: json['stage_name'] as String,
      bio: json['bio'] as String?,
      profileImageUrl: json['profile_image_url'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      genres: (json['genres'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      followersCount: (json['followers_count'] as num?)?.toInt() ?? 0,
      playsCount: (json['plays_count'] as num?)?.toInt() ?? 0,
      isVerified: json['is_verified'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$ArtistToJson(Artist instance) {
  final val = <String, dynamic>{
    'id': instance.id,
    'user_id': instance.userId,
    'stage_name': instance.stageName,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('bio', instance.bio);
  writeNotNull('profile_image_url', instance.profileImageUrl);
  writeNotNull('cover_image_url', instance.coverImageUrl);
  val['genres'] = instance.genres;
  val['followers_count'] = instance.followersCount;
  val['plays_count'] = instance.playsCount;
  val['is_verified'] = instance.isVerified;
  val['created_at'] = instance.createdAt.toIso8601String();
  val['updated_at'] = instance.updatedAt.toIso8601String();
  return val;
}
