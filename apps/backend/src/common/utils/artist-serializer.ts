/**
 * Utilidad para serializar artistas con compatibilidad camelCase y snake_case
 * Evita duplicación de código en múltiples controladores
 */
export class ArtistSerializer {
  /**
   * Serializa un artista a formato lite (versión pública simplificada)
   */
  static serializeLite(artist: any) {
    const profilePhotoUrl = artist.profilePhotoUrl ?? artist.user?.avatarUrl ?? null;
    const coverPhotoUrl = artist.coverPhotoUrl ?? null;
    const name = artist.name ?? artist.stageName;
    
    return {
      id: artist.id,
      name,
      stageName: artist.stageName ?? name,
      // Ambas variantes para máxima compatibilidad (camelCase y snake_case)
      profilePhotoUrl,
      profile_photo_url: profilePhotoUrl,
      coverPhotoUrl,
      cover_photo_url: coverPhotoUrl,
      nationalityCode: artist.nationalityCode ?? null,
      nationality_code: artist.nationalityCode ?? null,
      featured: !!artist.isFeatured || !!artist.featured,
      is_featured: !!artist.isFeatured || !!artist.featured,
      totalStreams: artist.totalStreams ?? 0,
      total_streams: artist.totalStreams ?? 0,
      totalFollowers: artist.totalFollowers ?? 0,
      total_followers: artist.totalFollowers ?? 0,
      monthlyListeners: artist.monthlyListeners ?? 0,
      monthly_listeners: artist.monthlyListeners ?? 0,
    };
  }

  /**
   * Serializa un artista completo (con biografía y detalles adicionales)
   */
  static serializeFull(artist: any) {
    const biography = artist.biography ?? artist.bio ?? null;
    const profilePhotoUrl = artist.profilePhotoUrl ?? null;
    const coverPhotoUrl = artist.coverPhotoUrl ?? null;
    const nationalityCode = artist.nationalityCode ?? null;
    
    return {
      id: artist.id,
      name: artist.name ?? artist.stageName,
      stageName: artist.stageName,
      // Ambas variantes para máxima compatibilidad (camelCase y snake_case)
      biography,
      bio: biography,
      profilePhotoUrl,
      profile_photo_url: profilePhotoUrl,
      coverPhotoUrl,
      cover_photo_url: coverPhotoUrl,
      nationalityCode,
      nationality_code: nationalityCode,
      verificationStatus: artist.verificationStatus ?? false,
      totalStreams: artist.totalStreams ?? 0,
      totalFollowers: artist.totalFollowers ?? 0,
      monthlyListeners: artist.monthlyListeners ?? 0,
    };
  }
}