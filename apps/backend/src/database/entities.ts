import { Album } from '../common/entities/album.entity';
import { Artist } from '../common/entities/artist.entity';
import { ArtistFollower } from '../common/entities/artist-follower.entity';
import { Genre } from '../common/entities/genre.entity';
import { Payment } from '../common/entities/payment.entity';
import { PlayHistory } from '../common/entities/play-history.entity';
import { Playlist } from '../common/entities/playlist.entity';
import { PlaylistFollower } from '../common/entities/playlist-follower.entity';
import { PlaylistSong } from '../common/entities/playlist-song.entity';
import { Song } from '../common/entities/song.entity';
import { SongLike } from '../common/entities/song-like.entity';
import { SongUpload } from '../common/entities/song-upload.entity';
import { StreamingStats } from '../common/entities/streaming-stats.entity';
import { User } from '../common/entities/user.entity';

export const entities = [
  Album,
  Artist,
  ArtistFollower,
  Genre,
  Payment,
  PlayHistory,
  Playlist,
  PlaylistFollower,
  PlaylistSong,
  Song,
  SongLike,
  SongUpload,
  StreamingStats,
  User,
];
