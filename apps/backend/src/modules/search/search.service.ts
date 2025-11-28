import { Injectable } from '@nestjs/common';
import { SongsService } from '../songs/songs.service';
import { ArtistsService } from '../artists/artists.service';
import { PlaylistsService } from '../playlists/playlists.service';
import { SongMapper } from '../songs/mappers/song.mapper';
import { ArtistSerializer } from '../../common/utils/artist-serializer';

@Injectable()
export class SearchService {
  constructor(
    private readonly songsService: SongsService,
    private readonly artistsService: ArtistsService,
    private readonly playlistsService: PlaylistsService,
  ) {}

  async searchAll(query: string, limit: number = 10) {
    // Búsqueda paralela para mejor rendimiento
    const [songsResult, artistsResult, playlistsResult] = await Promise.all([
      this.songsService.searchSongs(query, 1, limit),
      this.artistsService.searchArtists(query, 1, limit),
      this.playlistsService.searchPlaylists(query, 1, limit),
    ]);

    // Transformar a DTOs
    const songs = songsResult.songs.map(song => SongMapper.toDto(song));
    const artists = artistsResult.artists.map(artist => ArtistSerializer.serializeLite(artist));
    const playlists = playlistsResult.playlists;

    return {
      artists,
      songs,
      playlists,
      totals: {
        artists: artistsResult.total,
        songs: songsResult.total,
        playlists: playlistsResult.total,
      },
    };
  }
}

