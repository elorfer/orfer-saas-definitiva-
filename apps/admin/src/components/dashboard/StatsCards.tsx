'use client';

import { useQuery } from 'react-query';
import { apiClient } from '@/lib/api';
import {
  UsersIcon,
  MusicalNoteIcon,
  ChartBarIcon,
  CurrencyDollarIcon,
} from '@heroicons/react/24/outline';

interface StatCardProps {
  title: string;
  value: string | number;
  icon: React.ComponentType<any>;
  change?: string;
  changeType?: 'increase' | 'decrease';
  loading?: boolean;
}

function StatCard({ title, value, icon: Icon, change, changeType, loading }: StatCardProps) {
  return (
    <div className="card">
      <div className="flex items-center">
        <div className="flex-shrink-0">
          <div className="h-8 w-8 bg-vintage-100 rounded-lg flex items-center justify-center">
            <Icon className="h-5 w-5 text-vintage-600" />
          </div>
        </div>
        <div className="ml-4 flex-1">
          <p className="text-sm font-medium text-warm-600">{title}</p>
          {loading ? (
            <div className="mt-1 h-6 bg-warm-200 rounded animate-pulse" />
          ) : (
            <p className="mt-1 text-2xl font-semibold text-warm-900">{value}</p>
          )}
          {change && (
            <p className={`mt-1 text-sm ${changeType === 'increase' ? 'text-green-600' : 'text-red-600'}`}>
              {change}
            </p>
          )}
        </div>
      </div>
    </div>
  );
}

export default function StatsCards() {
  const { data: globalStats, isLoading } = useQuery(
    'globalStats',
    () => apiClient.getGlobalStats(),
    {
      refetchInterval: 30000, // Refetch every 30 seconds
    }
  );

  const stats = [
    {
      title: 'Total Usuarios',
      value: globalStats?.data?.totalUsers || 0,
      icon: UsersIcon,
      change: '+12%',
      changeType: 'increase' as const,
    },
    {
      title: 'Total Artistas',
      value: globalStats?.data?.totalArtists || 0,
      icon: MusicalNoteIcon,
      change: '+8%',
      changeType: 'increase' as const,
    },
    {
      title: 'Total Canciones',
      value: globalStats?.data?.totalSongs || 0,
      icon: ChartBarIcon,
      change: '+15%',
      changeType: 'increase' as const,
    },
    {
      title: 'Reproducciones',
      value: globalStats?.data?.totalStreams?.toLocaleString() || 0,
      icon: CurrencyDollarIcon,
      change: '+23%',
      changeType: 'increase' as const,
    },
  ];

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
      {stats.map((stat, index) => (
        <StatCard
          key={index}
          title={stat.title}
          value={stat.value}
          icon={stat.icon}
          change={stat.change}
          changeType={stat.changeType}
          loading={isLoading}
        />
      ))}
    </div>
  );
}









