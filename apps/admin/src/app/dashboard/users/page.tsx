'use client';

import { useMemo, useState } from 'react';
import { usePathname, useRouter } from 'next/navigation';
import {
  ArrowPathIcon,
  MagnifyingGlassIcon,
  UsersIcon,
  HomeIcon,
  MusicalNoteIcon,
  ShieldCheckIcon,
  UserPlusIcon,
  XMarkIcon,
  TrashIcon,
  ListBulletIcon,
  StarIcon,
} from '@heroicons/react/24/outline';

import { useCreateUser, useDeactivateUser, useActivateUser, useUsers } from '@/hooks/useUsers';
import type { UserModel } from '@/types/user';

const PAGE_SIZE = 10;
const DEFAULT_CREATE_FORM = {
  email: '',
  username: '',
  password: '',
  firstName: '',
  lastName: '',
  role: 'user' as 'admin' | 'artist' | 'user',
  stageName: '',
};

const roleLabels: Record<string, { label: string; badge: string; text: string }> = {
  admin: { label: 'Administrador', badge: 'bg-purple-100 text-purple-700', text: 'Administrador' },
  artist: { label: 'Artista', badge: 'bg-blue-100 text-blue-700', text: 'Artista' },
  user: { label: 'Usuario', badge: 'bg-gray-100 text-gray-700', text: 'Usuario' },
};

export default function UsersPage() {
  const router = useRouter();
  const pathname = usePathname();
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');

  const { data, isLoading, isFetching, refetch } = useUsers({ page, limit: PAGE_SIZE, enabled: true });
  const users = data?.users ?? [];

  const { mutateAsync: createUser, isLoading: isCreating } = useCreateUser();
  const { mutateAsync: deactivateUser } = useDeactivateUser();
  const { mutateAsync: activateUser } = useActivateUser();
  const [updatingId, setUpdatingId] = useState<string | null>(null);
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [createForm, setCreateForm] = useState(DEFAULT_CREATE_FORM);

  const navItems = [
    { name: 'Dashboard', href: '/dashboard', icon: HomeIcon },
    { name: 'Administrar usuarios', href: '/dashboard/users', icon: UsersIcon },
    { name: 'Gestionar canciones', href: '/dashboard/songs', icon: MusicalNoteIcon },
    { name: 'Artistas', href: '/dashboard/artists', icon: UsersIcon },
    { name: 'Administrar Playlists', href: '/dashboard/playlists', icon: ListBulletIcon },
    { name: 'Contenido destacado', href: '/dashboard/featured', icon: StarIcon },
    { name: 'Aprobar contenido', href: '/dashboard/approvals', icon: ShieldCheckIcon },
  ];

  const openCreateModal = () => {
    setCreateForm(DEFAULT_CREATE_FORM);
    setShowCreateModal(true);
  };

  const handleCreateUser = async (event: React.FormEvent) => {
    event.preventDefault();

    try {
      await createUser({
        ...createForm,
        stageName: createForm.role === 'artist' ? createForm.stageName : undefined,
      });
      setShowCreateModal(false);
      setCreateForm(DEFAULT_CREATE_FORM);
    } catch {
      // handled by hook
    }
  };

  const handleDeactivateUser = async (user: UserModel) => {
    if (!user.isActive) {
      window.alert('El usuario ya está desactivado.');
      return;
    }

    const confirmed = window.confirm(`¿Seguro que deseas desactivar a ${user.email}?`);
    if (!confirmed) return;

    try {
      setUpdatingId(user.id);
      await deactivateUser(user.id);
    } finally {
      setUpdatingId(null);
    }
  };

  const handleActivateUser = async (user: UserModel) => {
    if (user.isActive) {
      window.alert('El usuario ya está activo.');
      return;
    }

    try {
      setUpdatingId(user.id);
      await activateUser(user.id);
    } finally {
      setUpdatingId(null);
    }
  };

  const filteredUsers = useMemo(() => {
    if (!search.trim()) return users;
    const query = search.toLowerCase();

    return users.filter((user) => {
      const fullName = `${user.firstName} ${user.lastName}`.toLowerCase();
      return (
        user.email.toLowerCase().includes(query) ||
        user.username.toLowerCase().includes(query) ||
        fullName.includes(query)
      );
    });
  }, [users, search]);

  const total = data?.total ?? 0;
  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));

  const handleNext = () => {
    if (page < totalPages) {
      setPage((prev) => prev + 1);
    }
  };

  const handlePrev = () => {
    if (page > 1) {
      setPage((prev) => prev - 1);
    }
  };

  return (
    <>
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
            <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
              <div>
                <h1 className="text-2xl font-bold text-gray-900">Administrar usuarios</h1>
                <p className="mt-1 text-sm text-gray-500">
                  Consulta, filtra y gestiona los usuarios registrados.
                </p>
              </div>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => refetch()}
                  className="flex items-center gap-2 rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-600 transition hover:border-purple-400 hover:text-purple-600"
                >
                  <ArrowPathIcon className={`h-4 w-4 ${isFetching ? 'animate-spin' : ''}`} />
                  Actualizar
                </button>
                <button
                  onClick={openCreateModal}
                  className="flex items-center gap-2 rounded-lg bg-purple-600 px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-purple-700"
                >
                  <UserPlusIcon className="h-4 w-4" />
                  Nuevo usuario
                </button>
              </div>
            </div>
          </div>
        </header>

        <main className="flex-1 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6 space-y-6">
          <div className="bg-white border border-gray-200 rounded-2xl shadow-sm p-6">
            <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
              <div className="relative w-full sm:w-72">
                <input
                  type="text"
                  value={search}
                  onChange={(event) => setSearch(event.target.value)}
                  placeholder="Buscar por nombre, correo o usuario..."
                  className="w-full rounded-full border border-gray-200 bg-gray-50 px-4 py-2 pl-10 text-sm text-gray-800 focus:border-purple-500 focus:outline-none focus:ring-2 focus:ring-purple-100"
                />
                <MagnifyingGlassIcon className="h-5 w-5 text-gray-400 absolute left-3 top-1/2 -translate-y-1/2" />
              </div>
              <p className="text-sm text-gray-500">{total.toLocaleString('es-ES')} usuarios en total</p>
            </div>

            <div className="mt-6 overflow-hidden rounded-xl border border-gray-200">
              <table className="min-w-full divide-y divide-gray-200 bg-white">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="py-3 px-4 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">
                      Usuario
                    </th>
                    <th className="py-3 px-4 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">
                      Rol
                    </th>
                    <th className="py-3 px-4 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">
                      Estado
                    </th>
                    <th className="py-3 px-4 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">
                      Suscripción
                    </th>
                    <th className="py-3 px-4 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">
                      Último acceso
                    </th>
                    <th className="py-3 px-4 text-right text-xs font-semibold uppercase tracking-wider text-gray-500">
                      Acciones
                    </th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100">
                  {isLoading ? (
                    <tr>
                      <td colSpan={6} className="py-12 text-center text-sm text-gray-500">
                        Cargando usuarios...
                      </td>
                    </tr>
                  ) : filteredUsers.length === 0 ? (
                    <tr>
                      <td colSpan={6} className="py-12 text-center text-sm text-gray-500">
                        No se encontraron usuarios.
                      </td>
                    </tr>
                  ) : (
                    filteredUsers.map((user: UserModel) => {
                      const roleInfo = roleLabels[user.role] ?? roleLabels.user;

                      return (
                        <tr key={user.id} className="hover:bg-gray-50 transition">
                          <td className="py-4 px-4">
                            <div className="flex items-center gap-3">
                              <div className="h-10 w-10 rounded-full bg-gradient-to-br from-purple-500 to-purple-600 text-white flex items-center justify-center text-sm font-semibold">
                                {user.firstName?.charAt(0)?.toUpperCase() || user.email.charAt(0).toUpperCase()}
                              </div>
                              <div>
                                <p className="text-sm font-medium text-gray-900">
                                  {`${user.firstName} ${user.lastName}`.trim() || user.username}
                                </p>
                                <p className="text-xs text-gray-500">{user.email}</p>
                              </div>
                            </div>
                          </td>
                          <td className="py-4 px-4">
                            <span
                              className={`inline-flex items-center rounded-full px-3 py-1 text-xs font-semibold ${roleInfo.badge}`}
                            >
                              {roleInfo.text}
                            </span>
                          </td>
                          <td className="py-4 px-4">
                            <span
                              className={`inline-flex items-center rounded-full px-3 py-1 text-xs font-semibold ${
                                user.isActive ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-600'
                              }`}
                            >
                              {user.isActive ? 'Activo' : 'Inactivo'}
                            </span>
                          </td>
                          <td className="py-4 px-4 text-sm text-gray-600">
                            {user.subscriptionStatus === 'active' ? (
                              <span className="text-green-600 font-medium">Activa</span>
                            ) : (
                              <span className="text-gray-500">{user.subscriptionStatus ?? 'Sin suscripción'}</span>
                            )}
                          </td>
                          <td className="py-4 px-4 text-sm text-gray-500">
                            {user.lastLoginAt ? new Date(user.lastLoginAt).toLocaleString('es-ES') : 'Nunca'}
                          </td>
                          <td className="py-4 px-4 text-right">
                            {user.isActive ? (
                              <button
                                onClick={() => handleDeactivateUser(user)}
                                className="inline-flex items-center rounded-lg border border-gray-200 bg-white px-3 py-1.5 text-xs font-semibold text-gray-500 transition hover:border-yellow-300 hover:text-yellow-600 disabled:cursor-not-allowed disabled:opacity-60"
                                disabled={updatingId === user.id}
                              >
                                <ShieldCheckIcon className={`h-4 w-4 ${updatingId === user.id ? 'animate-spin' : ''}`} />
                                <span className="ml-1">Desactivar</span>
                              </button>
                            ) : (
                              <button
                                onClick={() => handleActivateUser(user)}
                                className="inline-flex items-center rounded-lg border border-gray-200 bg-white px-3 py-1.5 text-xs font-semibold text-gray-500 transition hover:border-green-300 hover:text-green-600 disabled:cursor-not-allowed disabled:opacity-60"
                                disabled={updatingId === user.id}
                              >
                                <ShieldCheckIcon className={`h-4 w-4 ${updatingId === user.id ? 'animate-spin' : ''}`} />
                                <span className="ml-1">Activar</span>
                              </button>
                            )}
                          </td>
                        </tr>
                      );
                    })
                  )}
                </tbody>
              </table>
            </div>

            <div className="mt-6 flex flex-col items-center justify-between gap-4 sm:flex-row">
              <p className="text-sm text-gray-500">
                Página {page} de {totalPages}
              </p>
              <div className="flex items-center gap-2">
                <button
                  onClick={handlePrev}
                  disabled={page === 1}
                  className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-500 transition hover:border-purple-400 hover:text-purple-600 disabled:cursor-not-allowed disabled:opacity-50"
                >
                  Anterior
                </button>
                <button
                  onClick={handleNext}
                  disabled={page === totalPages}
                  className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-500 transition hover:border-purple-400 hover:text-purple-600 disabled:cursor-not-allowed disabled:opacity-50"
                >
                  Siguiente
                </button>
              </div>
            </div>
          </div>
        </main>
      </div>
    </div>
    {showCreateModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/30 backdrop-blur-sm px-4">
          <div className="w-full max-w-lg rounded-2xl bg-white shadow-xl">
            <div className="flex items-center justify-between border-b border-gray-200 px-6 py-4">
              <div>
                <h2 className="text-lg font-semibold text-gray-900">Crear nuevo usuario</h2>
                <p className="text-sm text-gray-500">Registra un nuevo usuario y define su rol dentro del sistema.</p>
              </div>
              <button
                onClick={() => setShowCreateModal(false)}
                className="rounded-full p-1 text-gray-400 transition hover:bg-gray-100 hover:text-gray-600"
                aria-label="Cerrar"
              >
                <XMarkIcon className="h-5 w-5" />
              </button>
            </div>

            <form onSubmit={handleCreateUser} className="px-6 py-6 space-y-4">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-semibold uppercase tracking-wide text-gray-500 mb-1">
                    Nombre
                  </label>
                  <input
                    type="text"
                    value={createForm.firstName}
                    onChange={(event) =>
                      setCreateForm((prev) => ({ ...prev, firstName: event.target.value }))
                    }
                    required
                    className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm focus:border-purple-500 focus:outline-none focus:ring-2 focus:ring-purple-100"
                    placeholder="Juan"
                  />
                </div>
                <div>
                  <label className="block text-xs font-semibold uppercase tracking-wide text-gray-500 mb-1">
                    Apellido
                  </label>
                  <input
                    type="text"
                    value={createForm.lastName}
                    onChange={(event) =>
                      setCreateForm((prev) => ({ ...prev, lastName: event.target.value }))
                    }
                    required
                    className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm focus:border-purple-500 focus:outline-none focus:ring-2 focus:ring-purple-100"
                    placeholder="Pérez"
                  />
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-semibold uppercase tracking-wide text-gray-500 mb-1">
                    Correo electrónico
                  </label>
                  <input
                    type="email"
                    value={createForm.email}
                    onChange={(event) =>
                      setCreateForm((prev) => ({ ...prev, email: event.target.value }))
                    }
                    required
                    className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm focus:border-purple-500 focus:outline-none focus:ring-2 focus:ring-purple-100"
                    placeholder="usuario@vintagemusic.com"
                  />
                </div>
                <div>
                  <label className="block text-xs font-semibold uppercase tracking-wide text-gray-500 mb-1">
                    Usuario
                  </label>
                  <input
                    type="text"
                    value={createForm.username}
                    onChange={(event) =>
                      setCreateForm((prev) => ({ ...prev, username: event.target.value }))
                    }
                    required
                    className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm focus:border-purple-500 focus:outline-none focus:ring-2 focus:ring-purple-100"
                    placeholder="usuario123"
                  />
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-semibold uppercase tracking-wide text-gray-500 mb-1">
                    Contraseña
                  </label>
                  <input
                    type="password"
                    value={createForm.password}
                    onChange={(event) =>
                      setCreateForm((prev) => ({ ...prev, password: event.target.value }))
                    }
                    required
                    className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm focus:border-purple-500 focus:outline-none focus:ring-2 focus:ring-purple-100"
                    placeholder="••••••••"
                  />
                </div>
                <div>
                  <label className="block text-xs font-semibold uppercase tracking-wide text-gray-500 mb-1">
                    Rol
                  </label>
                  <select
                    value={createForm.role}
                    onChange={(event) =>
                      setCreateForm((prev) => ({ ...prev, role: event.target.value as 'admin' | 'artist' | 'user' }))
                    }
                    className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm focus:border-purple-500 focus:outline-none focus:ring-2 focus:ring-purple-100"
                  >
                    <option value="admin">Administrador</option>
                    <option value="artist">Artista</option>
                    <option value="user">Usuario</option>
                  </select>
                </div>
              </div>

              {createForm.role === 'artist' && (
                <div>
                  <label className="block text-xs font-semibold uppercase tracking-wide text-gray-500 mb-1">
                    Nombre artístico
                  </label>
                  <input
                    type="text"
                    value={createForm.stageName}
                    onChange={(event) =>
                      setCreateForm((prev) => ({ ...prev, stageName: event.target.value }))
                    }
                    className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm focus:border-purple-500 focus:outline-none focus:ring-2 focus:ring-purple-100"
                    placeholder="Ej. The Vintage"
                  />
                </div>
              )}

              <div className="flex items-center justify-end gap-3 pt-2">
                <button
                  type="button"
                  onClick={() => setShowCreateModal(false)}
                  className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-600 transition hover:border-gray-300 hover:text-gray-700"
                  disabled={isCreating}
                >
                  Cancelar
                </button>
                <button
                  type="submit"
                  disabled={isCreating}
                  className="inline-flex items-center rounded-lg bg-purple-600 px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-purple-700 disabled:cursor-not-allowed disabled:bg-purple-400"
                >
                  {isCreating ? 'Creando...' : 'Crear usuario'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </>
  );
}

