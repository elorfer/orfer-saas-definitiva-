'use client';

import { useEffect, useRef, useState } from 'react';
import { signOut, useSession } from 'next-auth/react';
import { usePathname, useRouter } from 'next/navigation';
import {
  MusicalNoteIcon,
  UserGroupIcon,
  BellIcon,
  Cog6ToothIcon,
  MagnifyingGlassIcon,
  ChevronDownIcon,
  ArrowRightOnRectangleIcon,
  UsersIcon,
  HomeIcon,
  ShieldCheckIcon,
  ListBulletIcon,
  StarIcon,
  TagIcon,
} from '@heroicons/react/24/outline';

interface DashboardLayoutProps {
  children: React.ReactNode;
}

export default function DashboardLayout({ children }: DashboardLayoutProps) {
  const { data: session, status } = useSession();
  const router = useRouter();
  const pathname = usePathname();
  const [menuOpen, setMenuOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement | null>(null);

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
    { name: 'Géneros musicales', href: '/dashboard/genres', icon: TagIcon },
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
                key={item.href}
                onClick={() => {
                  if (!isActive) {
                    router.push(item.href);
                  }
                }}
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
                <h1 className="text-2xl font-bold text-gray-900">Panel de Administración</h1>
              </div>
              <div className="flex items-center gap-2">
                <div className="relative w-full sm:w-72">
                  <input
                    type="text"
                    placeholder="Buscar..."
                    className="pl-10 pr-4 py-2 w-full rounded-full bg-gray-50 border border-gray-200 focus:outline-none focus:border-purple-500 focus:ring-2 focus:ring-purple-100 text-sm transition"
                  />
                  <MagnifyingGlassIcon className="h-4 w-4 text-gray-400 absolute left-3 top-1/2 -translate-y-1/2" />
                </div>
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
        </header>

        <main className="flex-1">
          {children}
        </main>
      </div>
    </div>
  );
}














