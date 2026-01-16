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
  MegaphoneIcon,
  SparklesIcon,
  Bars3Icon,
  XMarkIcon,
} from '@heroicons/react/24/outline';

interface DashboardLayoutProps {
  children: React.ReactNode;
}

export default function DashboardLayout({ children }: DashboardLayoutProps) {
  const { data: session, status } = useSession();
  const router = useRouter();
  const pathname = usePathname();
  const [menuOpen, setMenuOpen] = useState(false);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false); // Nuevo estado para móvil
  const menuRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    if (status === 'loading') return;
    if (status === 'unauthenticated' || !session) {
      router.push('/login');
    }
  }, [session, status, router]);

  // Cerrar menú móvil al cambiar de ruta
  useEffect(() => {
    setMobileMenuOpen(false);
  }, [pathname]);

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
    { name: 'Usuarios Premium', href: '/dashboard/premium', icon: SparklesIcon },
    { name: 'Gestionar canciones', href: '/dashboard/songs', icon: MusicalNoteIcon },
    { name: 'Artistas', href: '/dashboard/artists', icon: UsersIcon },
    { name: 'Géneros musicales', href: '/dashboard/genres', icon: TagIcon },
    { name: 'Administrar Playlists', href: '/dashboard/playlists', icon: ListBulletIcon },
    { name: 'Contenido destacado', href: '/dashboard/featured', icon: StarIcon },
    { name: 'Mensaje en Home', href: '/dashboard/home-message', icon: MegaphoneIcon },
    { name: 'Anuncios de Audio', href: '/dashboard/ads', icon: MegaphoneIcon },
    { name: 'Aprobar contenido', href: '/dashboard/approvals', icon: ShieldCheckIcon },
    { name: 'Configuración', href: '/dashboard/settings', icon: Cog6ToothIcon },
  ];

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

  return (
    <div className="min-h-screen bg-gray-100 flex">
      {/* Sidebar Desktop (Oculto en móvil) */}
      <aside className="hidden md:flex w-20 xl:w-64 flex-col bg-white border-r border-gray-200 py-6 sticky top-0 h-screen overflow-y-auto">
        <div className="flex flex-col items-center px-4 mb-8">
          <img
            src="/logo-principal.webp"
            alt="Struky Logo"
            className="h-20 w-20 object-contain rounded-2xl"
            onError={(e) => {
              console.error('Error cargando logo-principal.webp');
              e.currentTarget.style.display = 'none';
            }}
          />
          <span className="mt-3 text-sm font-semibold text-gray-900 text-center hidden xl:block">
            STRUKY ADMIN
          </span>
        </div>

        <nav className="flex-1 flex flex-col space-y-1 px-2">
          {navItems.map((item) => {
            const isActive = pathname === item.href;
            return (
              <button
                key={item.href}
                onClick={() => {
                  router.push(item.href);
                }}
                className={`flex items-center w-full gap-3 rounded-xl px-3 py-2 text-sm font-medium transition ${isActive
                  ? 'bg-brown-100 text-brown-700'
                  : 'text-gray-600 hover:bg-gray-100 hover:text-gray-900'
                  }`}
              >
                <item.icon className="h-5 w-5 flex-shrink-0" />
                <span className="hidden xl:inline">{item.name}</span>
              </button>
            );
          })}
        </nav>
      </aside>

      {/* Mobile Drawer (Overlay + Sidebar) */}
      {mobileMenuOpen && (
        <div className="fixed inset-0 z-50 flex md:hidden">
          {/* Overlay oscuro */}
          <div
            className="fixed inset-0 bg-black/50 backdrop-blur-sm transition-opacity"
            onClick={() => setMobileMenuOpen(false)}
          />

          {/* Sidebar Panel */}
          <div className="relative flex-1 flex flex-col max-w-xs w-full bg-white pt-5 pb-4 animate-in slide-in-from-left duration-300 shadow-xl">
            <div className="absolute top-0 right-0 -mr-12 pt-2">
              <button
                type="button"
                className="ml-1 flex items-center justify-center h-10 w-10 rounded-full focus:outline-none focus:ring-2 focus:ring-inset focus:ring-white"
                onClick={() => setMobileMenuOpen(false)}
              >
                <span className="sr-only">Cerrar menú</span>
                <XMarkIcon className="h-6 w-6 text-white" aria-hidden="true" />
              </button>
            </div>

            <div className="flex-shrink-0 flex items-center px-4 mb-6">
              <img
                className="h-10 w-auto"
                src="/logo-principal.webp"
                alt="Struky"
              />
              <span className="ml-3 font-bold text-gray-900 text-lg">Struky Admin</span>
            </div>

            <div className="mt-2 flex-1 h-0 overflow-y-auto">
              <nav className="px-2 space-y-1">
                {navItems.map((item) => {
                  const isActive = pathname === item.href;
                  return (
                    <button
                      key={item.href}
                      onClick={() => {
                        router.push(item.href);
                        setMobileMenuOpen(false);
                      }}
                      className={`group flex items-center px-2 py-2 text-base font-medium rounded-md w-full ${isActive
                        ? 'bg-brown-50 text-brown-700'
                        : 'text-gray-600 hover:bg-gray-50 hover:text-gray-900'
                        }`}
                    >
                      <item.icon
                        className={`mr-4 h-6 w-6 flex-shrink-0 ${isActive ? 'text-brown-700' : 'text-gray-400 group-hover:text-gray-500'
                          }`}
                        aria-hidden="true"
                      />
                      {item.name}
                    </button>
                  )
                })}
              </nav>
            </div>
          </div>
        </div>
      )}

      <div className="flex-1 flex flex-col min-w-0 overflow-hidden">
        <header className="bg-white border-b border-gray-200 shadow-sm">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
            <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">

              {/* Header Title + Hamburger */}
              <div className="flex items-center justify-between md:justify-start gap-4">
                {/* Botón Hamburguesa (Solo Móvil) */}
                <button
                  type="button"
                  className="md:hidden -ml-2 p-2 rounded-md text-gray-400 hover:text-gray-500 hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-brown-500"
                  onClick={() => setMobileMenuOpen(true)}
                >
                  <span className="sr-only">Abrir menú</span>
                  <Bars3Icon className="h-6 w-6" aria-hidden="true" />
                </button>

                <h1 className="text-xl md:text-2xl font-bold text-gray-900 truncate">
                  Struky Panel
                </h1>
              </div>

              <div className="flex items-center gap-2 justify-end">
                <div className="hidden md:block relative w-full sm:w-72">
                  <input
                    type="text"
                    placeholder="Buscar..."
                    className="pl-10 pr-4 py-2 w-full rounded-full bg-gray-50 border border-gray-200 focus:outline-none focus:border-brown-700 focus:ring-2 focus:ring-brown-100 text-sm transition"
                  />
                  <MagnifyingGlassIcon className="h-4 w-4 text-gray-400 absolute left-3 top-1/2 -translate-y-1/2" />
                </div>
                <button className="relative p-2 text-gray-500 hover:text-gray-700 hover:bg-gray-100 rounded-md transition">
                  <BellIcon className="h-5 w-5" />
                  <span className="absolute top-1 right-1 w-2 h-2 bg-red-500 rounded-full"></span>
                </button>
                <div className="relative" ref={menuRef}>
                  <button
                    onClick={() => setMenuOpen((prev) => !prev)}
                    className="flex items-center space-x-2 rounded-full bg-white border border-gray-200 px-3 py-1.5 shadow-sm hover:border-brown-700 transition"
                  >
                    <div className="h-8 w-8 bg-brown-100 rounded-full flex items-center justify-center overflow-hidden">
                      <span className="text-sm font-semibold text-brown-700">
                        {session?.user?.name?.charAt(0)?.toUpperCase() ?? 'A'}
                      </span>
                    </div>
                    <div className="hidden sm:block text-left">
                      <p className="text-xs font-medium text-gray-900 leading-tight">
                        {session?.user?.name ?? 'Admin'}
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
                        className="w-full px-4 py-2 text-sm text-left text-gray-600 hover:bg-brown-50 flex items-center gap-2"
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

        <main className="flex-1 overflow-y-auto">
          {children}
        </main>
      </div>
    </div>
  );
}




















