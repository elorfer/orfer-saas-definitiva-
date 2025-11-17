import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

enum UserRole {
  @JsonValue('user')
  user,
  @JsonValue('artist')
  artist,
  @JsonValue('admin')
  admin,
}

enum SubscriptionStatus {
  @JsonValue('FREE')
  free,
  @JsonValue('PREMIUM')
  premium,
  @JsonValue('VIP')
  vip,
  @JsonValue('inactive')
  inactive,
}

@JsonSerializable(
  fieldRename: FieldRename.snake,
  explicitToJson: true,
  includeIfNull: false,
)
class User {
  final String id;
  final String email;
  final String username;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;
  final UserRole role;
  final SubscriptionStatus subscriptionStatus;
  final bool? isVerified;
  final bool? isActive;
  final DateTime? lastLoginAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Artist? artist;

  const User({
    required this.id,
    required this.email,
    required this.username,
    this.firstName,
    this.lastName,
    this.avatarUrl,
    required this.role,
    required this.subscriptionStatus,
    this.isVerified,
    this.isActive,
    this.lastLoginAt,
    this.createdAt,
    this.updatedAt,
    this.artist,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);

  User copyWith({
    String? id,
    String? email,
    String? username,
    String? firstName,
    String? lastName,
    String? avatarUrl,
    UserRole? role,
    SubscriptionStatus? subscriptionStatus,
    bool? isVerified,
    bool? isActive,
    DateTime? lastLoginAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    Artist? artist,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      artist: artist ?? this.artist,
    );
  }

  String get fullName => '${firstName ?? ''} ${lastName ?? ''}'.trim().isEmpty ? username : '${firstName ?? ''} ${lastName ?? ''}'.trim();
  String get displayName => username;
  bool get isArtist => role == UserRole.artist;
  bool get isAdmin => role == UserRole.admin;
  bool get isPremium => subscriptionStatus != SubscriptionStatus.free;
  bool get isUserActive => isActive ?? true; // Por defecto activo si no se especifica
  bool get isUserVerified => isVerified ?? false; // Por defecto no verificado si no se especifica
}

@JsonSerializable(
  fieldRename: FieldRename.snake,
  explicitToJson: true,
  includeIfNull: false,
)
class Artist {
  final String id;
  final String userId;
  final String stageName;
  final String? bio;
  final String? profileImageUrl;
  final String? coverImageUrl;
  final List<String> genres;
  final int followersCount;
  final int playsCount;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Artist({
    required this.id,
    required this.userId,
    required this.stageName,
    this.bio,
    this.profileImageUrl,
    this.coverImageUrl,
    this.genres = const [],
    this.followersCount = 0,
    this.playsCount = 0,
    this.isVerified = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Artist.fromJson(Map<String, dynamic> json) => _$ArtistFromJson(json);
  Map<String, dynamic> toJson() => _$ArtistToJson(this);
}
