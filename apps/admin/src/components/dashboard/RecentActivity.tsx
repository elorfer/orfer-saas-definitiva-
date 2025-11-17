'use client';

import { useQuery } from 'react-query';
import { apiClient } from '@/lib/api';
import { ClockIcon, UserIcon, MusicalNoteIcon } from '@heroicons/react/24/outline';
import { formatDistanceToNow } from 'date-fns';
import { es } from 'date-fns/locale';

export default function RecentActivity() {
  const { data: recentUsers, isLoading: usersLoading } = useQuery(
    'recentUsers',
    () => apiClient.getUsers(1, 5),
    {
      refetchInterval: 30000,
    }
  );

  const { data: recentArtists, isLoading: artistsLoading } = useQuery(
    'recentArtists',
    () => apiClient.getArtists(1, 5),
    {
      refetchInterval: 30000,
    }
  );

  const isLoading = usersLoading || artistsLoading;

  if (isLoading) {
    return (
      <div className="card">
        <h3 className="text-lg font-medium text-warm-900 mb-4">Actividad Reciente</h3>
        <div className="space-y-4">
          {[...Array(3)].map((_, i) => (
            <div key={i} className="flex items-center space-x-3">
              <div className="h-8 w-8 bg-warm-200 rounded-full animate-pulse" />
              <div className="flex-1">
                <div className="h-4 bg-warm-200 rounded animate-pulse mb-1" />
                <div className="h-3 bg-warm-200 rounded animate-pulse w-1/2" />
              </div>
            </div>
          ))}
        </div>
      </div>
    );
  }

  const activities = [
    ...(recentUsers?.data?.users?.map((user: any) => ({
      id: user.id,
      type: 'user',
      title: 'Nuevo usuario registrado',
      description: `${user.firstName} ${user.lastName} (${user.email})`,
      timestamp: user.createdAt,
      icon: UserIcon,
    })) || []),
    ...(recentArtists?.data?.artists?.map((artist: any) => ({
      id: artist.id,
      type: 'artist',
      title: 'Nuevo artista verificado',
      description: `${artist.stageName}`,
      timestamp: artist.createdAt,
      icon: MusicalNoteIcon,
    })) || []),
  ]
    .sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime())
    .slice(0, 10);

  return (
    <div className="card">
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-lg font-medium text-warm-900">Actividad Reciente</h3>
        <ClockIcon className="h-5 w-5 text-vintage-600" />
      </div>
      
      <div className="space-y-4">
        {activities.map((activity) => (
          <div key={`${activity.type}-${activity.id}`} className="flex items-start space-x-3">
            <div className="flex-shrink-0">
              <div className="h-8 w-8 bg-vintage-100 rounded-full flex items-center justify-center">
                <activity.icon className="h-4 w-4 text-vintage-600" />
              </div>
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium text-warm-900">{activity.title}</p>
              <p className="text-sm text-warm-500">{activity.description}</p>
              <p className="text-xs text-warm-400 mt-1">
                {formatDistanceToNow(new Date(activity.timestamp), {
                  addSuffix: true,
                  locale: es,
                })}
              </p>
            </div>
          </div>
        ))}
      </div>
      
      {activities.length === 0 && (
        <div className="text-center py-6">
          <ClockIcon className="mx-auto h-12 w-12 text-warm-300" />
          <h3 className="mt-2 text-sm font-medium text-warm-900">No hay actividad reciente</h3>
          <p className="mt-1 text-sm text-warm-500">
            La actividad reciente aparecerá aquí.
          </p>
        </div>
      )}
    </div>
  );
}









