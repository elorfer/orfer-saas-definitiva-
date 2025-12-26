import axios from 'axios';

const normalizeApiBaseUrl = (url?: string) => {
  const fallback = 'http://localhost:3001';
  const rawUrl = (url && url.trim().length > 0 ? url : fallback).trim();
  const trimmed = rawUrl.replace(/\/+$/, '');

  if (/\/api\/v\d+$/i.test(trimmed)) {
    return trimmed;
  }

  if (/\/api$/i.test(trimmed)) {
    return `${trimmed}/v1`;
  }

  return `${trimmed}/api/v1`;
};

const API_BASE_URL = normalizeApiBaseUrl(process.env.NEXT_PUBLIC_API_URL);

// Función para obtener la URL base de la API (sin /api/v1)
export const getApiUrl = () => {
  const url = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001';
  return url.replace(/\/api\/v\d+$/i, '').replace(/\/api$/i, '');
};

export const api = axios.create({
  baseURL: API_BASE_URL,
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor para agregar el token de autenticación PRIMERO
api.interceptors.request.use(
  (config) => {
    if (typeof window !== 'undefined') {
      const token = localStorage.getItem('access_token');
      if (token) {
        config.headers.Authorization = `Bearer ${token}`;
      }
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Interceptor para eliminar Content-Type cuando se envía FormData (DESPUÉS de agregar el token)
api.interceptors.request.use((config) => {
  if (config.data instanceof FormData) {
    // Eliminar Content-Type para que el navegador establezca el boundary correcto
    // Asegurar que Authorization se mantenga
    delete config.headers['Content-Type'];
    // Asegurar que el header Authorization esté presente
    if (typeof window !== 'undefined') {
      const token = localStorage.getItem('access_token');
      if (token && !config.headers.Authorization) {
        config.headers.Authorization = `Bearer ${token}`;
      }
    }
  }
  return config;
});

// Response interceptor para manejar errores
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      // Token expirado o inválido; limpiar el token local y dejar que la vista maneje el error
      if (typeof window !== 'undefined') {
        localStorage.removeItem('access_token');
      }
    }
    return Promise.reject(error);
  }
);

// Funciones de utilidad para la API
export const apiClient = {
  // Auth
  login: (email: string, password: string) =>
    api.post('/auth/login', { email, password }),
  
  logout: () => api.post('/auth/logout'),
  
  getProfile: () => api.get('/auth/profile'),

  // Users
  getUsers: (page = 1, limit = 10) =>
    api.get(`/users?page=${page}&limit=${limit}`),
  
  getUser: (id: string) => api.get(`/users/${id}`),
  
  createUser: (data: any) => api.post('/auth/register', data),
  
  updateUser: (id: string, data: any) => api.patch(`/users/${id}`, data),
  
  deleteUser: (id: string) => api.delete(`/users/${id}`),
  
  activateUser: (id: string) => api.post(`/users/${id}/activate`),
  
  deactivateUser: (id: string) => api.post(`/users/${id}/deactivate`),
  
  verifyUser: (id: string) => api.post(`/users/${id}/verify`),

  // Premium users
  markAsPremium: (id: string, expiresAt?: string) => 
    api.post(`/users/${id}/premium`, expiresAt ? { expiresAt } : {}),
  
  removePremium: (id: string) => api.post(`/users/${id}/remove-premium`),
  
  getPremiumUsersCount: () => api.get('/users/premium/count'),
  
  getPremiumUsers: (page = 1, limit = 10) =>
    api.get(`/users/premium/list?page=${page}&limit=${limit}`),
  
  getPremiumUsersExpiringSoon: (days = 30) =>
    api.get(`/users/premium/expiring-soon?days=${days}`),
  
  getPremiumStats: () => api.get('/users/premium/stats'),

  // Artists
  getArtists: (page = 1, limit = 100) =>
    api.get(`/artists?page=${page}&limit=${limit}`),
  
  getArtist: (id: string) => api.get(`/artists/${id}`),

  // Verificar/desverificar artista
  verifyArtist: (id: string) => api.patch(`/artists/${id}/verify`),
  
  unverifyArtist: (id: string) => api.patch(`/artists/${id}/unverify`),

  // Crear artista (multipart/form-data)
  createArtist: (data: {
    name: string;
    nationalityCode?: string;
    biography?: string;
    featured?: boolean;
    userId?: string;
    phone?: string;
    genres?: string[];
    profileFile?: File | null;
    coverFile?: File | null;
  }) => {
    const form = new FormData();
    form.append('name', data.name);
    if (data.nationalityCode) form.append('nationalityCode', data.nationalityCode);
    if (data.biography) form.append('biography', data.biography);
    if (typeof data.featured === 'boolean') form.append('featured', String(data.featured));
    if (data.userId) form.append('userId', data.userId);
    if (data.phone) form.append('phone', data.phone);
    if (data.genres && data.genres.length > 0) {
      // Enviar cada género como un campo separado (el backend los recibirá como array)
      data.genres.forEach((genre) => {
        form.append('genres[]', genre);
      });
    }
    if (data.profileFile) form.append('profile', data.profileFile);
    if (data.coverFile) form.append('cover', data.coverFile);
    return api.post('/artists', form);
  },

  // Actualizar artista (multipart/form-data)
  updateArtist: (id: string, data: {
    name?: string;
    nationalityCode?: string;
    biography?: string;
    featured?: boolean;
    genres?: string[];
    profileFile?: File | null;
    coverFile?: File | null;
  }) => {
    const form = new FormData();
    if (data.name) form.append('name', data.name);
    if (data.nationalityCode) form.append('nationalityCode', data.nationalityCode);
    if (data.biography !== undefined) form.append('biography', data.biography);
    if (typeof data.featured === 'boolean') form.append('featured', String(data.featured));
    if (data.genres !== undefined) {
      if (data.genres.length > 0) {
        // Enviar cada género como un campo separado
        data.genres.forEach((genre) => {
          form.append('genres[]', genre);
        });
      } else {
        // Si es array vacío, enviar un campo vacío para limpiar géneros
        form.append('genres[]', '');
      }
    }
    if (data.profileFile) form.append('profile', data.profileFile);
    if (data.coverFile) form.append('cover', data.coverFile);
    return api.put(`/artists/${id}`, form);
  },

  // Toggle destacado
  toggleArtistFeatured: (id: string, featured: boolean) =>
    api.put(`/artists/${id}/feature`, { featured }),
  
  deleteArtist: (id: string) => api.delete(`/artists/${id}`),
  
  getArtistStats: (id: string) => api.get(`/artists/${id}/stats`),

  // Songs
  getSongs: (page = 1, limit = 10, all = true) =>
    api.get(`/songs?page=${page}&limit=${limit}&all=${all}`),
  
  getSong: (id: string) => api.get(`/songs/${id}`),
  
  getSongsByGenre: (genreId: string, page = 1, limit = 50) =>
    api.get(`/songs/genre/${genreId}?page=${page}&limit=${limit}`),
  
  getTopSongsByPlays: (limit = 10) => api.get(`/songs/top?limit=${limit}`),
  
  uploadSong: (
    audioFile: File, 
    coverFile: File | undefined, 
    songData: {
      title: string;
      artistId: string;
      albumId?: string;
      genreId?: string;
      genres?: string[]; // Array de géneros musicales
      status?: string;
      duration?: number;
    },
    onUploadProgress?: (progressEvent: { loaded: number; total: number }) => void
  ) => {
    const formData = new FormData();
    formData.append('audio', audioFile);
    if (coverFile) {
      formData.append('cover', coverFile);
    }
    formData.append('title', songData.title);
    formData.append('artistId', songData.artistId);
    if (songData.genres && songData.genres.length > 0) {
      // Enviar cada género como un campo separado (el backend los recibirá como array)
      songData.genres.forEach((genre) => {
        formData.append('genres[]', genre);
      });
    }
    if (songData.albumId) {
      formData.append('albumId', songData.albumId);
    }
    if (songData.genreId) {
      formData.append('genreId', songData.genreId);
    }
    if (songData.status) {
      formData.append('status', songData.status);
    }
    if (songData.duration !== undefined) {
      formData.append('duration', songData.duration.toString());
    }
    return api.post('/songs/upload', formData, {
      onUploadProgress: (progressEvent) => {
        if (progressEvent.total && onUploadProgress) {
          onUploadProgress({
            loaded: progressEvent.loaded,
            total: progressEvent.total,
          });
        }
      },
    });
  },
  
  createSong: (data: any) => api.post('/songs', data),
  
  updateSong: (id: string, data: any) => api.patch(`/songs/${id}`, data),
  
  deleteSong: (id: string) => api.delete(`/songs/${id}`),
  
  // Genres
  getGenres: (page = 1, limit = 50, all = false) =>
    api.get(`/genres?page=${page}&limit=${limit}&all=${all ? 'true' : 'false'}`),
  
  getGenre: (id: string) => api.get(`/genres/${id}`),
  
  searchGenres: (query: string, limit = 20) =>
    api.get(`/genres/search?q=${encodeURIComponent(query)}&limit=${limit}`),
  
  createGenre: (data: {
    name: string;
    description?: string;
    colorHex?: string;
    imageUrl?: string;
  }) => api.post('/genres', data),
  
  updateGenre: (id: string, data: {
    name?: string;
    description?: string;
    colorHex?: string;
    imageUrl?: string;
  }) => api.patch(`/genres/${id}`, data),
  
  uploadGenreImage: (id: string, imageFile: File) => {
    const formData = new FormData();
    formData.append('image', imageFile);
    return api.post(`/genres/${id}/image`, formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    });
  },
  
  deleteGenre: (id: string) => api.delete(`/genres/${id}`),
  
  // Playlists
  getPlaylists: (page = 1, limit = 10) =>
    api.get(`/playlists?page=${page}&limit=${limit}`),
  
  getPlaylist: (id: string) => api.get(`/playlists/${id}`),
  
  getFeaturedPlaylists: (limit = 10) => api.get(`/playlists/featured?limit=${limit}`),
  
  createPlaylist: (data: any) => api.post('/playlists', data),
  
  updatePlaylist: (id: string, data: any) => api.put(`/playlists/${id}`, data),
  
  deletePlaylist: (id: string) => api.delete(`/playlists/${id}`),
  
  toggleFeaturedPlaylist: (id: string) => api.patch(`/playlists/${id}/feature`),
  
  uploadPlaylistCover: (id: string, coverFile: File) => {
    const formData = new FormData();
    formData.append('cover', coverFile);
    return api.post(`/playlists/${id}/cover`, formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    });
  },
  
  addSongToPlaylist: (playlistId: string, songId: string) =>
    api.post(`/playlists/${playlistId}/songs/${songId}`),
  
  removeSongFromPlaylist: (playlistId: string, songId: string) =>
    api.delete(`/playlists/${playlistId}/songs/${songId}`),

  // Analytics
  getGlobalStats: () => api.get('/analytics/global'),
  
  getTopArtists: (limit = 10) => api.get(`/analytics/top-artists?limit=${limit}`),
  
  getTopSongs: (limit = 10) => api.get(`/analytics/top-songs?limit=${limit}`),

  // Analytics - Datos históricos
  getDailyStreams: (days = 7) => api.get(`/analytics/daily-streams?days=${days}`),
  
  getDailyActiveUsers: (days = 7) => api.get(`/analytics/daily-active-users?days=${days}`),
  
  getGenreDistribution: (limit = 5) => api.get(`/analytics/genre-distribution?limit=${limit}`),
  
  getPeakHours: () => api.get('/analytics/peak-hours'),

  // Payments
  getPayments: (page = 1, limit = 10) =>
    api.get(`/payments?page=${page}&limit=${limit}`),
  
  getPayment: (id: string) => api.get(`/payments/${id}`),
  
  refundPayment: (id: string) => api.post(`/payments/${id}/refund`),

  // Featured Content
  getFeaturedSongs: (limit = 10) => api.get(`/featured/songs?limit=${limit}`),
  featureSong: (id: string) => api.post(`/featured/songs/${id}/feature`),
  unfeatureSong: (id: string) => api.delete(`/featured/songs/${id}/feature`),

  getFeaturedArtists: (limit = 10) => api.get(`/featured/artists?limit=${limit}`),
  // Eliminado: featureArtist / unfeatureArtist. La gestión se hace solo desde /artists vía toggleArtistFeatured

  // App messages (home banner)
  getHomeMessage: () => api.get('/app-messages/home'),
  publishHomeMessage: (data: { message: string; isActive?: boolean }) =>
    api.post('/app-messages/home', data),
  updateHomeMessageStatus: (id: string, isActive: boolean) =>
    api.patch(`/app-messages/${id}/status`, { isActive }),
  disableHomeMessages: () => api.post('/app-messages/home/disable'),

  // Ads
  getAds: (page = 1, limit = 10, status?: string) => {
    const params = new URLSearchParams({ page: page.toString(), limit: limit.toString() });
    if (status) params.append('status', status);
    return api.get(`/ads?${params.toString()}`);
  },
  
  getAd: (id: string) => api.get(`/ads/${id}`),
  
  createAd: (data: any) => api.post('/ads', data),
  
  updateAd: (id: string, data: any) => api.patch(`/ads/${id}`, data),
  
  deleteAd: (id: string) => api.delete(`/ads/${id}`),
  
  activateAd: (id: string) => api.post(`/ads/${id}/activate`),
  
  pauseAd: (id: string) => api.post(`/ads/${id}/pause`),
  
  uploadAdAudio: (id: string, file: File) => {
    const formData = new FormData();
    formData.append('file', file);
    // No establecer Content-Type explícitamente - el interceptor lo maneja automáticamente
    return api.post(`/ads/${id}/upload-audio`, formData);
  },
  
  uploadAdCover: (id: string, file: File) => {
    const formData = new FormData();
    formData.append('file', file);
    // No establecer Content-Type explícitamente - el interceptor lo maneja automáticamente
    return api.post(`/ads/${id}/upload-cover`, formData);
  },
  
  getAdStats: (id: string) => api.get(`/ads/${id}/stats`),

  // Settings (Configuraciones)
  getSettings: () => api.get('/settings'),
  
  getAdFrequency: () => api.get('/settings/ad-frequency'),
  
  updateAdFrequency: (value: number) => api.put('/settings/ad-frequency', { value }),
  
  getSetting: (key: string) => api.get(`/settings/${key}`),
  
  updateSetting: (key: string, value: number, description?: string) => 
    api.put(`/settings/${key}`, { value, description }),
};

export default api;
