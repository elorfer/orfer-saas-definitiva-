'use client';

import { useQuery } from 'react-query';
import { apiClient } from '@/lib/api';
import { ChartBarIcon } from '@heroicons/react/24/outline';

export default function TopSongs() {
  const { data: topSongs, isLoading } = useQuery(
    'topSongs',
    () => apiClient.getTopSongs(5),
    {
      refetchInterval: 60000, // Refetch every minute
    }
  );

  if (isLoading) {
    return (
      <div className="card">
        <h3 className="text-lg font-medium text-warm-900 mb-4">Canciones Más Populares</h3>
        <div className="space-y-3">
          {[...Array(5)].map((_, i) => (
            <div key={i} className="flex items-center space-x-3">
              <div className="h-10 w-10 bg-warm-200 rounded-full animate-pulse" />
              <div className="flex-1">
                <div className="h-4 bg-warm-200 rounded animate-pulse mb-1" />
                <div className="h-3 bg-warm-200 rounded animate-pulse w-2/3" />
              </div>
            </div>
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="card">
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-lg font-medium text-warm-900">Canciones Más Populares</h3>
        <ChartBarIcon className="h-5 w-5 text-vintage-600" />
      </div>
      
      <div className="space-y-3">
        {topSongs?.data?.map((song: any, index: number) => (
          <div key={song.id} className="flex items-center space-x-3">
            <div className="flex-shrink-0">
              <div className="h-10 w-10 bg-vintage-100 rounded-full flex items-center justify-center">
                <span className="text-sm font-medium text-vintage-700">
                  {index + 1}
                </span>
              </div>
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium text-warm-900 truncate">
                {song.title}
              </p>
              <p className="text-sm text-warm-500">
                {song.artist?.stageName}
              </p>
            </div>
            <div className="flex-shrink-0">
              <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-vintage-100 text-vintage-800">
                {song.totalStreams?.toLocaleString()} streams
              </span>
            </div>
          </div>
        ))}
      </div>
      
      {topSongs?.data?.length === 0 && (
        <div className="text-center py-6">
          <ChartBarIcon className="mx-auto h-12 w-12 text-warm-300" />
          <h3 className="mt-2 text-sm font-medium text-warm-900">No hay canciones</h3>
          <p className="mt-1 text-sm text-warm-500">
            Las canciones aparecerán aquí cuando los artistas las suban.
          </p>
        </div>
      )}
    </div>
  );
}









