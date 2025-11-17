'use client';

import { useEffect, useRef, useState } from 'react';
import { useSession, signOut } from 'next-auth/react';
import { usePathname } from 'next/navigation';
import Link from 'next/link';
import {
  HomeIcon,
  UsersIcon,
  MusicalNoteIcon,
  ChartBarIcon,
  CreditCardIcon,
  CogIcon,
  Bars3Icon,
  XMarkIcon,
  ArrowRightOnRectangleIcon,
  ChevronDownIcon,
  StarIcon,
  ListBulletIcon,
} from '@heroicons/react/24/outline';

interface DashboardLayoutProps {
  children: React.ReactNode;
}

const navigation = [
  { name: 'Dashboard', href: '/dashboard', icon: HomeIcon },
  { name: 'Administrar usuarios', href: '/dashboard/users', icon: UsersIcon },
  { name: 'Administrar artistas', href: '/dashboard/artists', icon: MusicalNoteIcon },
  { name: 'Gestionar canciones', href: '/dashboard/songs', icon: MusicalNoteIcon },
  { name: 'Administrar Playlists', href: '/dashboard/playlists', icon: ListBulletIcon },
  { name: 'Contenido destacado', href: '/dashboard/featured', icon: StarIcon },
  { name: 'Analytics', href: '/dashboard/analytics', icon: ChartBarIcon },
  { name: 'Pagos', href: '/dashboard/payments', icon: CreditCardIcon },
  { name: 'Configuración', href: '/dashboard/settings', icon: CogIcon },
];

export default function DashboardLayout({ children }: DashboardLayoutProps) {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const [highContrast, setHighContrast] = useState<boolean>(false);
  const menuRef = useRef<HTMLDivElement | null>(null);
  const { data: session } = useSession();
  const pathname = usePathname();

  const handleSignOut = () => {
    signOut({ callbackUrl: '/login', redirect: true });
    if (typeof window !== 'undefined') {
      localStorage.removeItem('access_token');
    }
  };

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

  // Inicializar/guardar modo alto contraste
  useEffect(() => {
    if (typeof window === 'undefined') return;
    const saved = localStorage.getItem('admin_high_contrast');
    if (saved) {
      const val = saved === '1';
      setHighContrast(val);
      document.documentElement.classList.toggle('high-contrast', val);
    }
  }, []);

  useEffect(() => {
    if (typeof window === 'undefined') return;
    localStorage.setItem('admin_high_contrast', highContrast ? '1' : '0');
    document.documentElement.classList.toggle('high-contrast', highContrast);
  }, [highContrast]);

  return (
    <div className="min-h-screen antialiased bg-gradient-to-b from-gray-50 to-gray-100">
      {/* Mobile sidebar */}
      <div className={`fixed inset-0 z-50 lg:hidden ${sidebarOpen ? 'block' : 'hidden'}`}>
        <div className="fixed inset-0 bg-warm-600 bg-opacity-75" onClick={() => setSidebarOpen(false)} />
        <div className="fixed inset-y-0 left-0 flex w-64 flex-col bg-white shadow-xl hc-shadow">
          <div className="flex h-16 items-center justify-between px-4">
            <div className="flex items-center">
              <div className="h-8 w-8 bg-vintage-600 rounded-lg flex items-center justify-center">
                <MusicalNoteIcon className="h-5 w-5 text-white" />
              </div>
              <span className="ml-2 text-lg font-vintage font-bold text-warm-900">
                Vintage Music
              </span>
            </div>
            <button
              type="button"
              className="text-warm-400 hover:text-warm-600"
              onClick={() => setSidebarOpen(false)}
            >
              <XMarkIcon className="h-6 w-6" />
            </button>
          </div>
          <nav className="flex-1 px-4 py-4 space-y-1">
            {navigation.map((item) => {
              const isActive = pathname === item.href;
              return (
                <Link
                  key={item.name}
                  href={item.href}
                  className={`sidebar-link ${
                    isActive ? 'sidebar-link-active' : 'sidebar-link-inactive'
                  }`}
                  onClick={() => setSidebarOpen(false)}
                >
                  <item.icon className="mr-3 h-5 w-5" />
                  {item.name}
                </Link>
              );
            })}
          </nav>
        </div>
      </div>

      {/* Desktop sidebar */}
      <div className="hidden lg:fixed lg:inset-y-0 lg:flex lg:w-64 lg:flex-col">
        <div className="flex flex-col flex-grow bg-white/95 backdrop-blur border-r border-gray-200 shadow-sm hc-shadow">
          <div className="flex h-16 items-center px-4">
            <div className="h-8 w-8 bg-vintage-600 rounded-lg flex items-center justify-center">
              <MusicalNoteIcon className="h-5 w-5 text-white" />
            </div>
            <span className="ml-2 text-lg font-vintage font-bold text-warm-900">
              Vintage Music
            </span>
          </div>
          <nav className="flex-1 px-4 py-4 space-y-1">
            {navigation.map((item) => {
              const isActive = pathname === item.href;
              return (
                <Link
                  key={item.name}
                  href={item.href}
                  className={`sidebar-link ${
                    isActive ? 'sidebar-link-active' : 'sidebar-link-inactive'
                  }`}
                >
                  <item.icon className="mr-3 h-5 w-5" />
                  {item.name}
                </Link>
              );
            })}
          </nav>
        </div>
      </div>

      {/* Main content */}
      <div className="lg:pl-64">
        {/* Top bar */}
        <div className="sticky top-0 z-40 flex h-16 shrink-0 items-center gap-x-4 border-b border-gray-200 bg-white/95 backdrop-blur px-4 shadow-md hc-shadow sm:gap-x-6 sm:px-6 lg:px-8">
          <button
            type="button"
            className="-m-2.5 p-2.5 text-warm-700 lg:hidden"
            onClick={() => setSidebarOpen(true)}
          >
            <Bars3Icon className="h-6 w-6" />
          </button>

          <div className="flex flex-1 gap-x-4 self-stretch lg:gap-x-6">
            <div className="flex flex-1" />
            <div className="flex items-center gap-x-4 lg:gap-x-6">
              {/* Toggle Alto Contraste */}
              <button
                onClick={() => setHighContrast((v) => !v)}
                className={`hidden sm:inline-flex items-center rounded-lg border px-3 py-1.5 text-sm transition ${
                  highContrast
                    ? 'bg-vintage-600 text-white border-vintage-600'
                    : 'bg-white text-warm-700 border-gray-300 hover:border-vintage-500'
                }`}
                title="Alternar alto contraste"
              >
                {highContrast ? 'Contraste: Alto' : 'Contraste: Normal'}
              </button>
              <div className="relative" ref={menuRef}>
                <button
                  onClick={() => setMenuOpen((prev) => !prev)}
                  className="flex items-center space-x-2 rounded-full bg-white border border-gray-200 px-3 py-1.5 shadow-sm hover:border-vintage-500 transition-colors"
                >
                  <div className="h-8 w-8 bg-vintage-100 rounded-full flex items-center justify-center">
                    <span className="text-sm font-semibold text-vintage-700">
                      {session?.user?.name?.charAt(0) ?? 'A'}
                    </span>
                  </div>
                  <div className="hidden lg:block text-left">
                    <p className="text-xs font-medium text-warm-900 leading-tight">
                      {session?.user?.name ?? 'Administrador'}
                    </p>
                    <p className="text-[11px] text-warm-500 leading-tight">
                      {session?.user?.email ?? ''}
                    </p>
                  </div>
                  <ChevronDownIcon className="h-4 w-4 text-warm-400" />
                </button>
                {menuOpen && (
                  <div className="absolute right-0 mt-2 w-48 rounded-lg border border-warm-200 bg-white shadow-lg py-1 z-50">
                    <div className="px-4 py-2 border-b border-warm-100">
                      <p className="text-xs font-semibold text-warm-900">
                        {session?.user?.name ?? 'Administrador'}
                      </p>
                      <p className="text-[11px] text-warm-500 truncate">
                        {session?.user?.email ?? ''}
                      </p>
                    </div>
                    <button
                      onClick={handleSignOut}
                      className="w-full px-4 py-2 text-sm text-left text-warm-600 hover:bg-vintage-50 flex items-center gap-2"
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

        {/* Page content */}
        <main className="py-6">
          <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
            {children}
          </div>
        </main>
      </div>

      {/* Estilos globales para alto contraste */}
      <style jsx global>{`
        .high-contrast .hc-shadow {
          box-shadow: 0 12px 28px rgba(16, 24, 40, 0.28) !important;
        }
        .high-contrast .hc-card {
          box-shadow: 0 14px 32px rgba(16, 24, 40, 0.28) !important;
        }
        .high-contrast .hc-ring {
          box-shadow: inset 0 0 0 2px rgba(16, 24, 40, 0.35) !important;
        }
      `}</style>
    </div>
  );
}









