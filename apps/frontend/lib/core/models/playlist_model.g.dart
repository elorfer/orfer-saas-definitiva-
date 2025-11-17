// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playlist_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PlaylistSong _$PlaylistSongFromJson(Map<String, dynamic> json) => PlaylistSong(
      id: json['id'] as String,
      playlistId: json['playlistId'] as String,
      songId: json['songId'] as String,
      position: (json['position'] as num).toInt(),
      addedAt: json['addedAt'] == null
          ? null
          : DateTime.parse(json['addedAt'] as String),
      song: json['song'] == null
          ? null
          : Song.fromJson(json['song'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PlaylistSongToJson(PlaylistSong instance) {
  final val = <String, dynamic>{
    'id': instance.id,
    'playlistId': instance.playlistId,
    'songId': instance.songId,
    'position': instance.position,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('addedAt', instance.addedAt?.toIso8601String());
  writeNotNull('song', instance.song?.toJson());
  return val;
}

Playlist _$PlaylistFromJson(Map<String, dynamic> json) => Playlist(
      id: json['id'] as String,
      userId: json['userId'] as String?,
      name: json['name'] as String?,
      description: json['description'] as String?,
      coverArtUrl: json['coverArtUrl'] as String?,
      type: $enumDecodeNullable(_$PlaylistTypeEnumMap, json['type']),
      visibility:
          $enumDecodeNullable(_$PlaylistVisibilityEnumMap, json['visibility']),
      isPublic: json['isPublic'] as bool?,
      isFeatured: json['isFeatured'] as bool?,
      totalTracks: (json['totalTracks'] as num?)?.toInt(),
      totalFollowers: (json['totalFollowers'] as num?)?.toInt(),
      totalDuration: _safeIntFromJson(json['totalDuration']),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      user: json['user'] == null
          ? null
          : User.fromJson(json['user'] as Map<String, dynamic>),
      playlistSongs: (json['playlistSongs'] as List<dynamic>?)
          ?.map((e) => PlaylistSong.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$PlaylistToJson(Playlist instance) {
  final val = <String, dynamic>{
    'id': instance.id,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('userId', instance.userId);
  writeNotNull('name', instance.name);
  writeNotNull('description', instance.description);
  writeNotNull('coverArtUrl', instance.coverArtUrl);
  writeNotNull('type', _$PlaylistTypeEnumMap[instance.type]);
  writeNotNull('visibility', _$PlaylistVisibilityEnumMap[instance.visibility]);
  writeNotNull('isPublic', instance.isPublic);
  writeNotNull('isFeatured', instance.isFeatured);
  writeNotNull('totalTracks', instance.totalTracks);
  writeNotNull('totalFollowers', instance.totalFollowers);
  writeNotNull('totalDuration', instance.totalDuration);
  writeNotNull('createdAt', instance.createdAt?.toIso8601String());
  writeNotNull('updatedAt', instance.updatedAt?.toIso8601String());
  writeNotNull('user', instance.user?.toJson());
  writeNotNull(
      'playlistSongs', instance.playlistSongs?.map((e) => e.toJson()).toList());
  return val;
}

const _$PlaylistTypeEnumMap = {
  PlaylistType.user: 'user',
  PlaylistType.featured: 'featured',
  PlaylistType.genre: 'genre',
  PlaylistType.mood: 'mood',
};

const _$PlaylistVisibilityEnumMap = {
  PlaylistVisibility.public: 'public',
  PlaylistVisibility.private: 'private',
  PlaylistVisibility.unlisted: 'unlisted',
};

FeaturedPlaylist _$FeaturedPlaylistFromJson(Map<String, dynamic> json) =>
    FeaturedPlaylist(
      playlist: Playlist.fromJson(json['playlist'] as Map<String, dynamic>),
      featuredReason: json['featured_reason'] as String?,
      rank: (json['rank'] as num).toInt(),
    );

Map<String, dynamic> _$FeaturedPlaylistToJson(FeaturedPlaylist instance) {
  final val = <String, dynamic>{
    'playlist': instance.playlist.toJson(),
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('featured_reason', instance.featuredReason);
  val['rank'] = instance.rank;
  return val;
}
