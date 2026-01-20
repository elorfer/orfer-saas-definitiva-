'use client';

import { useEffect, useMemo, useState } from 'react';
import { useSession } from 'next-auth/react';
import { useRouter } from 'next/navigation';
import {
  MusicalNoteIcon,
  UserGroupIcon,
  PlayIcon,
  ArrowTrendingUpIcon,
  ArrowPathIcon,
} from '@heroicons/react/24/outline';
import { formatDistanceToNow } from 'date-fns';
import { es } from 'date-fns/locale';
import { toast } from 'react-hot-toast';
import { apiClient } from '@/lib/api';

import { useUsers } from '@/hooks/useUsers';
import { useArtists } from '@/hooks/useArtists';
import { useSongs } from '@/hooks/useSongs';
import { useGlobalStats } from '@/hooks/useGlobalStats';
import { useTopSongs } from '@/hooks/useTopSongs';
import StreamsChart from '@/components/dashboard/StreamsChart';
import ActiveUsersChart from '@/components/dashboard/ActiveUsersChart';
import GenreDistributionChart from '@/components/dashboard/GenreDistributionChart';
import PeakHoursChart from '@/components/dashboard/PeakHoursChart';
import ActiveUsersRealTime from '@/components/dashboard/ActiveUsersRealTime';
import type { UserModel } from '@/types/user';

// Función auxiliar para formatear números grandes
const formatNumber = (num: number): string => {
  if (num >= 1000000) {
    return `${(num / 1000000).toFixed(1)}M`;
  }
  if (num >= 1000) {
    return `${(num / 1000).toFixed(1)}K`;
  }
  return num.toLocaleString('es-ES');
};

export default function DashboardPage() {
  const { data: session, status } = useSession();
  const router = useRouter();


  // Hooks para obtener datos reales
  const {
    data: usersData,
    isLoading: usersLoading,
    refetch: refetchUsers,
  } = useUsers({ page: 1, limit: 8, enabled: status === 'authenticated' });

  const {
    data: artistsData,
    isLoading: artistsLoading,
    refetch: refetchArtists,
  } = useArtists({ page: 1, limit: 1, enabled: status === 'authenticated' });

  const {
    data: songsData,
    isLoading: songsLoading,
    refetch: refetchSongs,
  } = useSongs({ page: 1, limit: 1, enabled: status === 'authenticated' });

  const {
    data: globalStats,
    isLoading: statsLoading,
    refetch: refetchStats,
  } = useGlobalStats(status === 'authenticated');

  const {
    data: topSongs,
    isLoading: topSongsLoading,
    refetch: refetchTopSongs,
  } = useTopSongs(5, status === 'authenticated');

  useEffect(() => {
    if (status === 'loading') return;
    if (status === 'unauthenticated' || !session) {
      router.push('/login');
    }
  }, [session, status, router]);




  if (status === 'loading') {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-2 border-brown-700 border-t-transparent mx-auto"></div>
          <p className="mt-4 text-gray-600">Cargando...</p>
        </div>
      </div>
    );
  }

  if (!session) {
    return null;
  }

  // Calcular datos reales
  const usersList = usersData?.users ?? [];
  const totalUsers = globalStats?.totalUsers ?? usersData?.total ?? 0;
  const activeUsersCount = globalStats?.activeUsers ?? usersList.filter((user) => user.isActive).length;
  const verifiedUsersCount = globalStats?.verifiedUsers ?? usersList.filter((user) => user.isVerified).length;
  const verifiedPercentage = totalUsers > 0 ? Math.min(100, Math.round((verifiedUsersCount / totalUsers) * 100)) : 0;
  const recentUsers: UserModel[] = usersList.slice(0, 5);
  const lastUserCreatedAt = usersList.length > 0 ? usersList[0].createdAt : null;

  // Datos de estadísticas globales
  const totalArtists = globalStats?.totalArtists ?? artistsData?.total ?? 0;
  const totalSongs = globalStats?.totalSongs ?? songsData?.total ?? 0;
  const totalStreams = globalStats?.totalStreams ?? 0;

  // Usar datos reales del backend
  const featuredArtists = globalStats?.featuredArtists ?? artistsData?.artists?.filter((a: any) => a.featured)?.length ?? 0;
  const featuredArtistsPercentage = totalArtists > 0 ? Math.round((featuredArtists / totalArtists) * 100) : 0;

  // Usar datos reales del backend
  const publishedSongs = globalStats?.publishedSongs ?? songsData?.songs?.filter((s: any) => s.status === 'published')?.length ?? 0;
  const publishedSongsPercentage = totalSongs > 0 ? Math.round((publishedSongs / totalSongs) * 100) : 0;

  const isLoading = usersLoading || artistsLoading || songsLoading || statsLoading;

  const getFullName = (user: UserModel) =>
    [user.firstName, user.lastName].filter(Boolean).join(' ') || user.username || user.email;

  const getInitials = (user: UserModel) => {
    const name = getFullName(user).trim();
    if (!name) {
      return 'U';
    }
    const parts = name.split(' ');
    if (parts.length === 1) {
      return parts[0].charAt(0).toUpperCase();
    }
    return `${parts[0].charAt(0)}${parts[parts.length - 1].charAt(0)}`.toUpperCase();
  };

  const formatRelativeDate = (date?: string | null) => {
    if (!date) {
      return 'Sin registro';
    }
    try {
      return formatDistanceToNow(new Date(date), { addSuffix: true, locale: es });
    } catch {
      return 'Sin registro';
    }
  };

  // Filas de resumen con datos reales
  const summaryRows = useMemo(() => [
    {
      item: 'Usuarios',
      total: isLoading ? '...' : totalUsers.toLocaleString('es-ES'),
      status: isLoading ? 'Analizando' : `${activeUsersCount} activos`,
      completionLabel: isLoading ? '...' : `${verifiedUsersCount} verificados`,
      progressValue: isLoading ? 0 : verifiedPercentage,
      badgeClasses: 'bg-brown-100 text-brown-800',
    },
    {
      item: 'Artistas',
      total: isLoading ? '...' : totalArtists.toLocaleString('es-ES'),
      status: isLoading ? 'Analizando' : `${featuredArtists} destacados`,
      completionLabel: isLoading ? '...' : `${totalArtists} totales`,
      progressValue: isLoading ? 0 : featuredArtistsPercentage,
      badgeClasses: 'bg-blue-100 text-blue-800',
    },
    {
      item: 'Canciones',
      total: isLoading ? '...' : totalSongs.toLocaleString('es-ES'),
      status: isLoading ? 'Analizando' : `${publishedSongs} publicadas`,
      completionLabel: isLoading ? '...' : `${totalSongs} totales`,
      progressValue: isLoading ? 0 : publishedSongsPercentage,
      badgeClasses: 'bg-green-100 text-green-800',
    },
    {
      item: 'Reproducciones',
      total: isLoading ? '...' : formatNumber(totalStreams),
      status: isLoading ? 'Analizando' : 'Total acumulado',
      completionLabel: isLoading ? '...' : formatNumber(totalStreams),
      progressValue: 0,
      badgeClasses: 'bg-orange-100 text-orange-800',
    },
  ], [isLoading, totalUsers, activeUsersCount, verifiedUsersCount, verifiedPercentage, totalArtists, featuredArtists, featuredArtistsPercentage, totalSongs, publishedSongs, publishedSongsPercentage, totalStreams]);

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-6 py-6">
      {/* Header */}
      <div className="mb-4">
        <h1 className="text-2xl font-bold text-gray-900">Dashboard</h1>
        <p className="text-sm text-gray-500 mt-1">Resumen de estadísticas y actividad</p>
      </div>

      {/* Stats Cards - Compact */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        {/* Usuarios Totales */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-5 hover:shadow-md transition-shadow">
          <div className="flex items-center justify-between">
            <div className="flex-1">
              <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-1">Usuarios Totales</p>
              <p className="text-2xl font-bold text-gray-900 mb-2">
                {usersLoading ? '...' : totalUsers.toLocaleString('es-ES')}
              </p>
              <div className="flex items-center space-x-2">
                <ArrowTrendingUpIcon className="h-3 w-3 text-green-500" />
                <span className="text-xs font-medium text-green-600">
                  {usersLoading ? 'Cargando...' : `${verifiedUsersCount} verificados`}
                </span>
                <span className="text-xs text-gray-500">
                  {usersLoading ? '' : `${activeUsersCount} activos`}
                </span>
              </div>
            </div>
            <div className="p-3 bg-brown-100 rounded-lg">
              <UserGroupIcon className="h-6 w-6 text-brown-700" />
            </div>
          </div>
          <div className="mt-4 pt-4 border-t border-gray-200">
            <p className="text-xs text-gray-500">
              {usersLoading
                ? 'Analizando actividad reciente...'
                : totalUsers === 0
                  ? 'Sin registros de usuarios.'
                  : `Último registro ${formatRelativeDate(lastUserCreatedAt)}`}
            </p>
          </div>
        </div>

        {/* Artistas */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-5 hover:shadow-md transition-shadow">
          <div className="flex items-center justify-between">
            <div className="flex-1">
              <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-1">Artistas</p>
              <p className="text-2xl font-bold text-gray-900 mb-2">
                {isLoading ? '...' : totalArtists.toLocaleString('es-ES')}
              </p>
              <div className="flex items-center">
                <ArrowTrendingUpIcon className="h-3 w-3 text-green-500 mr-1" />
                <span className="text-xs font-medium text-green-600">
                  {isLoading ? 'Cargando...' : `${featuredArtists} destacados`}
                </span>
              </div>
            </div>
            <div className="p-3 bg-blue-100 rounded-lg">
              <MusicalNoteIcon className="h-6 w-6 text-blue-600" />
            </div>
          </div>
          <div className="mt-4 pt-4 border-t border-gray-200">
            <div className="flex items-center justify-between">
              <span className="text-xs text-gray-500">Progreso</span>
              <span className="text-xs font-medium text-gray-700">
                {isLoading ? '...' : `${featuredArtistsPercentage}%`}
              </span>
            </div>
            <div className="mt-2 bg-gray-200 rounded-full h-1.5">
              <div
                className="bg-blue-600 rounded-full h-1.5 transition-all duration-300"
                style={{ width: isLoading ? '0%' : `${featuredArtistsPercentage}%` }}
              ></div>
            </div>
          </div>
        </div>

        {/* Canciones */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-5 hover:shadow-md transition-shadow">
          <div className="flex items-center justify-between">
            <div className="flex-1">
              <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-1">Canciones</p>
              <p className="text-2xl font-bold text-gray-900 mb-2">
                {isLoading ? '...' : totalSongs.toLocaleString('es-ES')}
              </p>
              <div className="flex items-center">
                <ArrowTrendingUpIcon className="h-3 w-3 text-green-500 mr-1" />
                <span className="text-xs font-medium text-green-600">
                  {isLoading ? 'Cargando...' : `${publishedSongs} publicadas`}
                </span>
              </div>
            </div>
            <div className="p-3 bg-green-100 rounded-lg">
              <MusicalNoteIcon className="h-6 w-6 text-green-600" />
            </div>
          </div>
          <div className="mt-4 pt-4 border-t border-gray-200">
            <div className="flex items-center justify-between">
              <span className="text-xs text-gray-500">Progreso</span>
              <span className="text-xs font-medium text-gray-700">
                {isLoading ? '...' : `${publishedSongsPercentage}%`}
              </span>
            </div>
            <div className="mt-2 bg-gray-200 rounded-full h-1.5">
              <div
                className="bg-green-600 rounded-full h-1.5 transition-all duration-300"
                style={{ width: isLoading ? '0%' : `${publishedSongsPercentage}%` }}
              ></div>
            </div>
          </div>
        </div>

        {/* Reproducciones */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-5 hover:shadow-md transition-shadow">
          <div className="flex items-center justify-between">
            <div className="flex-1">
              <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-1">Reproducciones</p>
              <p className="text-2xl font-bold text-gray-900 mb-2">
                {isLoading ? '...' : formatNumber(totalStreams)}
              </p>
              <div className="flex items-center">
                <PlayIcon className="h-3 w-3 text-orange-500 mr-1" />
                <span className="text-xs font-medium text-orange-600">
                  {isLoading ? 'Cargando...' : 'Total acumulado'}
                </span>
              </div>
            </div>
            <div className="p-3 bg-orange-100 rounded-lg">
              <PlayIcon className="h-6 w-6 text-orange-600" />
            </div>
          </div>
          <div className="mt-4 pt-4 border-t border-gray-200">
            <p className="text-xs text-gray-500">
              {isLoading
                ? 'Analizando reproducciones...'
                : totalStreams === 0
                  ? 'Sin reproducciones aún.'
                  : `Total de reproducciones en la plataforma`}
            </p>
          </div>
        </div>
      </div>

      {/* Real-time Active Users */}
      <div className="mb-6">
        <ActiveUsersRealTime />
      </div>

      {/* Charts Section - Main */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 mb-6">
        {/* Chart 1 - Reproducciones Totales */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-5 hover:shadow-md transition-shadow">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h3 className="text-sm font-semibold text-gray-900">Reproducciones Totales</h3>
              <p className="text-xs text-gray-500 mt-1">Últimos 7 días</p>
            </div>
            <div className="p-2 bg-brown-100 rounded-lg">
              <PlayIcon className="h-5 w-5 text-brown-700" />
            </div>
          </div>
          <StreamsChart />
        </div>

        {/* Chart 2 - Usuarios Activos */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-5 hover:shadow-md transition-shadow">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h3 className="text-sm font-semibold text-gray-900">Usuarios Activos</h3>
              <p className="text-xs text-gray-500 mt-1">Últimos 7 días</p>
            </div>
            <div className="p-2 bg-blue-100 rounded-lg">
              <UserGroupIcon className="h-5 w-5 text-blue-700" />
            </div>
          </div>
          <ActiveUsersChart />
        </div>
      </div>

      {/* Charts Section - Additional */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 mb-6">
        {/* Chart 3 - Distribución por Géneros */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-5 hover:shadow-md transition-shadow">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h3 className="text-sm font-semibold text-gray-900">Géneros Más Populares</h3>
              <p className="text-xs text-gray-500 mt-1">Por reproducciones</p>
            </div>
            <div className="p-2 bg-green-100 rounded-lg">
              <MusicalNoteIcon className="h-5 w-5 text-green-700" />
            </div>
          </div>
          <GenreDistributionChart />
        </div>

        {/* Chart 4 - Horas Pico */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-5 hover:shadow-md transition-shadow">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h3 className="text-sm font-semibold text-gray-900">Horas Pico de Actividad</h3>
              <p className="text-xs text-gray-500 mt-1">Últimos 30 días</p>
            </div>
            <div className="p-2 bg-orange-100 rounded-lg">
              <PlayIcon className="h-5 w-5 text-orange-700" />
            </div>
          </div>
          <PeakHoursChart />
        </div>
      </div>

      {/* Tables Section */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 mb-6">
        {/* Recent Activities */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-5">
          <h3 className="text-sm font-semibold text-gray-900 mb-4">Actividades Recientes</h3>
          <div className="space-y-3">
            {usersLoading ? (
              Array.from({ length: 3 }).map((_, index) => (
                <div
                  key={index}
                  className="flex items-center space-x-3 p-3 bg-gray-50 rounded-md animate-pulse"
                >
                  <div className="w-8 h-8 bg-gray-200 rounded-md flex-shrink-0" />
                  <div className="flex-1 min-w-0 space-y-2">
                    <div className="h-3 bg-gray-200 rounded w-3/4" />
                    <div className="h-2 bg-gray-200 rounded w-1/2" />
                  </div>
                  <div className="w-16 h-2 bg-gray-200 rounded" />
                </div>
              ))
            ) : recentUsers.length === 0 ? (
              <p className="text-sm text-gray-500">No hay actividad reciente.</p>
            ) : (
              recentUsers.map((user) => (
                <div
                  key={user.id}
                  className="flex items-center space-x-3 p-3 bg-gray-50 rounded-md hover:bg-gray-100 transition-colors"
                >
                  <div className="w-8 h-8 bg-brown-100 rounded-md flex items-center justify-center flex-shrink-0 text-brown-700 font-semibold text-xs">
                    {getInitials(user)}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium text-gray-900 truncate">{getFullName(user)}</p>
                    <p className="text-xs text-gray-500 truncate">{user.email}</p>
                  </div>
                  <p className="text-xs text-gray-500 whitespace-nowrap">
                    {formatRelativeDate(user.createdAt)}
                  </p>
                </div>
              ))
            )}
          </div>
        </div>

        {/* Top Songs */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-5">
          <h3 className="text-sm font-semibold text-gray-900 mb-4">Top Canciones</h3>
          <div className="space-y-3">
            {topSongsLoading ? (
              Array.from({ length: 3 }).map((_, index) => (
                <div
                  key={index}
                  className="flex items-center space-x-3 p-3 bg-gray-50 rounded-md animate-pulse"
                >
                  <div className="w-6 h-6 bg-gray-200 rounded-md flex-shrink-0" />
                  <div className="flex-1 min-w-0 space-y-2">
                    <div className="h-3 bg-gray-200 rounded w-3/4" />
                    <div className="h-2 bg-gray-200 rounded w-1/2" />
                  </div>
                  <div className="w-16 h-2 bg-gray-200 rounded" />
                </div>
              ))
            ) : !topSongs || topSongs.length === 0 ? (
              <p className="text-sm text-gray-500">No hay canciones disponibles.</p>
            ) : (
              topSongs.slice(0, 5).map((song, index) => (
                <div key={song.id} className="flex items-center space-x-3 p-3 bg-gray-50 rounded-md hover:bg-gray-100 transition-colors">
                  <div className="w-6 h-6 bg-gradient-to-br from-brown-700 to-brown-800 rounded-md flex items-center justify-center text-white font-bold text-xs flex-shrink-0">
                    {index + 1}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium text-gray-900 truncate">{song.title}</p>
                    <p className="text-xs text-gray-500 truncate">
                      {song.artist?.stageName ?? 'Artista desconocido'}
                    </p>
                  </div>
                  <p className="text-sm font-semibold text-gray-700 whitespace-nowrap">
                    {formatNumber(song.totalStreams || 0)}
                  </p>
                </div>
              ))
            )}
          </div>
        </div>
      </div>

      {/* Data Table */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-5">
        <h3 className="text-sm font-semibold text-gray-900 mb-4">Resumen de Datos</h3>
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b border-gray-200">
                <th className="text-left py-3 px-4 text-xs font-semibold text-gray-600 uppercase tracking-wider">Item</th>
                <th className="text-left py-3 px-4 text-xs font-semibold text-gray-600 uppercase tracking-wider">Total</th>
                <th className="text-left py-3 px-4 text-xs font-semibold text-gray-600 uppercase tracking-wider">Estado</th>
                <th className="text-left py-3 px-4 text-xs font-semibold text-gray-600 uppercase tracking-wider">Completado</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {summaryRows.map((row, index) => (
                <tr key={index} className="hover:bg-gray-50 transition-colors">
                  <td className="py-3 px-4 text-sm font-medium text-gray-900">{row.item}</td>
                  <td className="py-3 px-4 text-sm text-gray-600">{row.total}</td>
                  <td className="py-3 px-4">
                    <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${row.badgeClasses}`}>
                      {row.status}
                    </span>
                  </td>
                  <td className="py-3 px-4">
                    <div className="flex items-center">
                      <div className="flex-1 bg-gray-200 rounded-full h-1.5 mr-2">
                        <div
                          className="bg-brown-700 rounded-full h-1.5 transition-all duration-300"
                          style={{ width: `${row.progressValue}%` }}
                        ></div>
                      </div>
                      <span className="text-xs font-medium text-gray-600 w-24 text-right">
                        {row.completionLabel}
                      </span>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
