'use client';

import { useEffect, useRef, useState } from 'react';
import { signOut, useSession } from 'next-auth/react';
import { usePathname, useRouter } from 'next/navigation';
import {
  MusicalNoteIcon,
  UserGroupIcon,
  PlayIcon,
  BellIcon,
  Cog6ToothIcon,
  MagnifyingGlassIcon,
  ArrowTrendingUpIcon,
  ChevronDownIcon,
  ArrowRightOnRectangleIcon,
  UsersIcon,
  HomeIcon,
  ShieldCheckIcon,
  ListBulletIcon,
  StarIcon,
} from '@heroicons/react/24/outline';
import { formatDistanceToNow } from 'date-fns';
import { es } from 'date-fns/locale';

import { useUsers } from '@/hooks/useUsers';
import type { UserModel } from '@/types/user';

export default function DashboardPage() {
  const { data: session, status } = useSession();
  const router = useRouter();
  const pathname = usePathname();
  const [menuOpen, setMenuOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement | null>(null);
  const {
    data: usersData,
    isLoading: usersLoading,
  } = useUsers({ page: 1, limit: 8, enabled: status === 'authenticated' });

  useEffect(() => {
    if (status === 'loading') return;
    if (status === 'unauthenticated' || !session) {
      router.push('/login');
    }
  }, [session, status, router]);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(event.target as Node)) {
        setMenuOpen(false);
      }
    };

    if (menuOpen) {
      document.addEventListener('mousedown', handleClickOutside);
    }

    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, [menuOpen]);

  const handleSignOut = () => {
    signOut({ callbackUrl: '/login', redirect: true });
    if (typeof window !== 'undefined') {
      localStorage.removeItem('access_token');
    }
  };

  const navItems = [
    { name: 'Dashboard', href: '/dashboard', icon: HomeIcon },
    { name: 'Administrar usuarios', href: '/dashboard/users', icon: UsersIcon },
    { name: 'Gestionar canciones', href: '/dashboard/songs', icon: MusicalNoteIcon },
    { name: 'Artistas', href: '/dashboard/artists', icon: UsersIcon },
    { name: 'Administrar Playlists', href: '/dashboard/playlists', icon: ListBulletIcon },
    { name: 'Contenido destacado', href: '/dashboard/featured', icon: StarIcon },
    { name: 'Aprobar contenido', href: '/dashboard/approvals', icon: ShieldCheckIcon },
  ];

  if (status === 'loading') {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-2 border-purple-600 border-t-transparent mx-auto"></div>
          <p className="mt-4 text-gray-600">Cargando...</p>
        </div>
      </div>
    );
  }

  if (!session) {
    return null;
  }

  const usersList = usersData?.users ?? [];
  const totalUsers = usersData?.total ?? 0;
  const activeUsersCount = usersList.filter((user) => user.isActive).length;
  const verifiedUsersCount = usersList.filter((user) => user.isVerified).length;
  const verifiedPercentage = totalUsers > 0 ? Math.min(100, Math.round((verifiedUsersCount / totalUsers) * 100)) : 0;
  const recentUsers: UserModel[] = usersList.slice(0, 5);
  const lastUserCreatedAt = usersList.length > 0 ? usersList[0].createdAt : null;

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
  const summaryRows = [
    {
      item: 'Usuarios',
      total: usersLoading ? '...' : totalUsers.toLocaleString('es-ES'),
      status: usersLoading ? 'Analizando' : `${activeUsersCount} activos`,
      completionLabel: usersLoading ? '...' : `${verifiedUsersCount} verificados`,
      progressValue: usersLoading ? 0 : verifiedPercentage,
      badgeClasses: 'bg-blue-100 text-blue-800',
    },
    {
      item: 'Artistas',
      total: '0',
      status: 'Pendiente',
      completionLabel: 'Próximamente',
      progressValue: 0,
      badgeClasses: 'bg-gray-100 text-gray-700',
    },
    {
      item: 'Canciones',
      total: '0',
      status: 'Pendiente',
      completionLabel: 'Próximamente',
      progressValue: 0,
      badgeClasses: 'bg-gray-100 text-gray-700',
    },
    {
      item: 'Reproducciones',
      total: '0',
      status: 'Pendiente',
      completionLabel: 'Próximamente',
      progressValue: 0,
      badgeClasses: 'bg-gray-100 text-gray-700',
    },
  ];

  return (
    <div className="min-h-screen bg-gray-100 flex">
      <aside className="hidden md:flex w-20 xl:w-64 flex-col bg-white border-r border-gray-200 py-6">
        <div className="flex flex-col items-center xl:items-start px-4 mb-8">
          <div className="h-10 w-10 rounded-xl bg-gradient-to-r from-purple-500 to-purple-600 flex items-center justify-center text-white font-bold">
            VM
          </div>
          <span className="mt-3 text-sm font-semibold text-gray-900 hidden xl:block">
            Vintage Admin
          </span>
        </div>

        <nav className="flex-1 flex flex-col space-y-1 px-2">
          {navItems.map((item) => {
            const isActive = pathname === item.href;
            return (
              <button
                key={item.name}
                onClick={() => router.push(item.href)}
                className={`flex items-center w-full gap-3 rounded-xl px-3 py-2 text-sm font-medium transition ${
                  isActive
                    ? 'bg-purple-100 text-purple-700'
                    : 'text-gray-600 hover:bg-gray-100 hover:text-gray-900'
                }`}
              >
                <item.icon className="h-5 w-5" />
                <span className="hidden xl:inline">{item.name}</span>
              </button>
            );
          })}
        </nav>
      </aside>

      <div className="flex-1 flex flex-col">
      <header className="bg-white border-b border-gray-200 shadow-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
            <div>
              <h1 className="text-2xl font-bold text-gray-900">Dashboard</h1>
              <nav className="mt-1 flex items-center space-x-2 text-sm text-gray-500">
                <span>Alternative</span>
                <span>/</span>
                <span>Dashboards</span>
                <span>/</span>
                <span className="text-gray-900 font-medium">Alternative</span>
              </nav>
            </div>
            <div className="flex flex-col sm:flex-row sm:items-center gap-3">
              <div className="relative w-full sm:w-72">
                <input
                  type="text"
                  placeholder="Buscar..."
                  className="pl-10 pr-4 py-2 w-full rounded-full bg-gray-50 border border-gray-200 focus:outline-none focus:border-purple-500 focus:ring-2 focus:ring-purple-100 text-sm transition"
                />
                <MagnifyingGlassIcon className="h-4 w-4 text-gray-400 absolute left-3 top-1/2 -translate-y-1/2" />
              </div>
              <div className="flex items-center gap-2">
                <button className="relative p-2 text-gray-500 hover:text-gray-700 hover:bg-gray-100 rounded-md transition">
                  <BellIcon className="h-5 w-5" />
                  <span className="absolute top-1 right-1 w-2 h-2 bg-red-500 rounded-full"></span>
                </button>
                <button className="p-2 text-gray-500 hover:text-gray-700 hover:bg-gray-100 rounded-md transition">
                  <Cog6ToothIcon className="h-5 w-5" />
                </button>
                <div className="relative" ref={menuRef}>
                  <button
                    onClick={() => setMenuOpen((prev) => !prev)}
                    className="flex items-center space-x-2 rounded-full bg-white border border-gray-200 px-3 py-1.5 shadow-sm hover:border-purple-500 transition"
                  >
                    <div className="h-8 w-8 bg-purple-100 rounded-full flex items-center justify-center">
                      <span className="text-sm font-semibold text-purple-700">
                        {session?.user?.name?.charAt(0)?.toUpperCase() ??
                          session?.user?.email?.charAt(0)?.toUpperCase() ??
                          'A'}
                      </span>
                    </div>
                    <div className="hidden sm:block text-left">
                      <p className="text-xs font-medium text-gray-900 leading-tight">
                        {session?.user?.name ?? 'Administrador'}
                      </p>
                      <p className="text-[11px] text-gray-500 leading-tight">
                        {session?.user?.email ?? ''}
                      </p>
                    </div>
                    <ChevronDownIcon className="h-4 w-4 text-gray-400" />
                  </button>
                  {menuOpen && (
                    <div className="absolute right-0 mt-2 w-48 rounded-lg border border-gray-200 bg-white shadow-lg py-1 z-50">
                      <div className="px-4 py-2 border-b border-gray-100">
                        <p className="text-xs font-semibold text-gray-900">
                          {session?.user?.name ?? 'Administrador'}
                        </p>
                        <p className="text-[11px] text-gray-500 truncate">
                          {session?.user?.email ?? ''}
                        </p>
                      </div>
                      <button
                        onClick={handleSignOut}
                        className="w-full px-4 py-2 text-sm text-left text-gray-600 hover:bg-purple-50 flex items-center gap-2"
                      >
                        <ArrowRightOnRectangleIcon className="h-4 w-4" />
                        Cerrar sesión
                      </button>
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>
      </header>

      <main className="flex-1 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-6 py-6">
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
              <div className="p-3 bg-purple-100 rounded-lg">
                <UserGroupIcon className="h-6 w-6 text-purple-600" />
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
                <p className="text-2xl font-bold text-gray-900 mb-2">0</p>
                <div className="flex items-center">
                  <ArrowTrendingUpIcon className="h-3 w-3 text-green-500 mr-1" />
                  <span className="text-xs font-medium text-green-600">+8%</span>
                  <span className="text-xs text-gray-500 ml-2">vs mes anterior</span>
                </div>
              </div>
              <div className="p-3 bg-blue-100 rounded-lg">
                <MusicalNoteIcon className="h-6 w-6 text-blue-600" />
              </div>
            </div>
            <div className="mt-4 pt-4 border-t border-gray-200">
              <div className="flex items-center justify-between">
                <span className="text-xs text-gray-500">Progreso</span>
                <span className="text-xs font-medium text-gray-700">0%</span>
              </div>
              <div className="mt-2 bg-gray-200 rounded-full h-1.5">
                <div className="bg-blue-600 rounded-full h-1.5" style={{ width: '0%' }}></div>
              </div>
            </div>
          </div>

          {/* Canciones */}
          <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-5 hover:shadow-md transition-shadow">
            <div className="flex items-center justify-between">
              <div className="flex-1">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-1">Canciones</p>
                <p className="text-2xl font-bold text-gray-900 mb-2">0</p>
                <div className="flex items-center">
                  <ArrowTrendingUpIcon className="h-3 w-3 text-green-500 mr-1" />
                  <span className="text-xs font-medium text-green-600">+23%</span>
                  <span className="text-xs text-gray-500 ml-2">vs mes anterior</span>
                </div>
              </div>
              <div className="p-3 bg-green-100 rounded-lg">
                <MusicalNoteIcon className="h-6 w-6 text-green-600" />
              </div>
            </div>
            <div className="mt-4 pt-4 border-t border-gray-200">
              <div className="flex items-center justify-between">
                <span className="text-xs text-gray-500">Progreso</span>
                <span className="text-xs font-medium text-gray-700">0%</span>
              </div>
              <div className="mt-2 bg-gray-200 rounded-full h-1.5">
                <div className="bg-green-600 rounded-full h-1.5" style={{ width: '0%' }}></div>
              </div>
            </div>
          </div>

          {/* Reproducciones */}
          <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-5 hover:shadow-md transition-shadow">
            <div className="flex items-center justify-between">
              <div className="flex-1">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-1">Reproducciones</p>
                <p className="text-2xl font-bold text-gray-900 mb-2">0</p>
                <div className="flex items-center">
                  <ArrowTrendingUpIcon className="h-3 w-3 text-green-500 mr-1" />
                  <span className="text-xs font-medium text-green-600">+15%</span>
                  <span className="text-xs text-gray-500 ml-2">vs mes anterior</span>
                </div>
              </div>
              <div className="p-3 bg-orange-100 rounded-lg">
                <PlayIcon className="h-6 w-6 text-orange-600" />
              </div>
            </div>
            <div className="mt-4 pt-4 border-t border-gray-200">
              <div className="flex items-center justify-between">
                <span className="text-xs text-gray-500">Progreso</span>
                <span className="text-xs font-medium text-gray-700">0%</span>
              </div>
              <div className="mt-2 bg-gray-200 rounded-full h-1.5">
                <div className="bg-orange-600 rounded-full h-1.5" style={{ width: '0%' }}></div>
              </div>
            </div>
          </div>
        </div>

        {/* Charts Section */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 mb-6">
          {/* Chart 1 */}
          <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-5">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-sm font-semibold text-gray-900">Reproducciones Totales</h3>
              <PlayIcon className="h-4 w-4 text-gray-400" />
            </div>
            <div className="h-48 bg-gray-50 rounded-md border border-gray-200 flex items-center justify-center">
              <p className="text-xs text-gray-400">Gráfico (próximamente)</p>
            </div>
          </div>

          {/* Chart 2 */}
          <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-5">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-sm font-semibold text-gray-900">Usuarios Activos</h3>
              <UserGroupIcon className="h-4 w-4 text-gray-400" />
            </div>
            <div className="h-48 bg-gray-50 rounded-md border border-gray-200 flex items-center justify-center">
              <p className="text-xs text-gray-400">Gráfico (próximamente)</p>
            </div>
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
                    <div className="w-8 h-8 bg-purple-100 rounded-md flex items-center justify-center flex-shrink-0 text-purple-600 font-semibold text-xs">
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
              {[
                { id: 1, title: 'Summer Nights', artist: 'John Doe', plays: '1.2M' },
                { id: 2, title: 'City Lights', artist: 'Maria Garcia', plays: '890K' },
                { id: 3, title: 'Ocean Dreams', artist: 'The Rockers', plays: '756K' },
              ].map((song, index) => (
                <div key={song.id} className="flex items-center space-x-3 p-3 bg-gray-50 rounded-md hover:bg-gray-100 transition-colors">
                  <div className="w-6 h-6 bg-gradient-to-br from-purple-500 to-purple-700 rounded-md flex items-center justify-center text-white font-bold text-xs flex-shrink-0">
                    {index + 1}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium text-gray-900 truncate">{song.title}</p>
                    <p className="text-xs text-gray-500 truncate">{song.artist}</p>
                  </div>
                  <p className="text-sm font-semibold text-gray-700 whitespace-nowrap">{song.plays}</p>
                </div>
              ))}
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
                            className="bg-purple-600 rounded-full h-1.5"
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
      </main>
      </div>
    </div>
  );
}
