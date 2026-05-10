'use client';

import { useMemo, useState } from 'react';
import { useSession } from 'next-auth/react';
import { useRouter } from 'next/navigation';
import toast from 'react-hot-toast';
import { apiClient } from '@/lib/api';
import {
  ArrowPathIcon,
  MagnifyingGlassIcon,
  StarIcon,
  ClockIcon,
  UserGroupIcon,
  ChartBarIcon,
  XMarkIcon,
  ExclamationTriangleIcon,
  BanknotesIcon,
  UserPlusIcon,
} from '@heroicons/react/24/outline';
import { formatDistanceToNow } from 'date-fns';
import { es } from 'date-fns/locale';

import {
  usePremiumUsers,
  usePremiumUsersExpiringSoon,
  usePremiumStats,
  useManualRevenueStats,
  useMonthlyRevenueStats,
} from '@/hooks/usePremium';
import {
  useMarkAsPremium,
  useRemovePremium,
  usePremiumUsersCount,
  useUsers,
} from '@/hooks/useUsers';
import { PremiumPlans } from '@/components/PremiumPlans';
import RechargeParticles from '@/components/dashboard/RechargeParticles';
import type { UserModel } from '@/types/user';

const PAGE_SIZE = 10;

export default function PremiumPage() {
  const { data: session, status } = useSession();
  const router = useRouter();
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [activeTab, setActiveTab] = useState<'all' | 'expiring'>('all');

  // Estado para renovación
  const [showPremiumModal, setShowPremiumModal] = useState(false);
  const [selectedUserForPremium, setSelectedUserForPremium] = useState<UserModel | null>(null);

  const { data: stats, isLoading: statsLoading, refetch: refetchStats } = usePremiumStats(status === 'authenticated');
  const { data: revenueData, isLoading: revenueLoading, refetch: refetchRevenue } = useManualRevenueStats(status === 'authenticated');
  const { data: monthlyRevenue, refetch: refetchMonthly } = useMonthlyRevenueStats(status === 'authenticated');
  const { data: premiumData, isLoading: premiumLoading, isFetching: premiumFetching, refetch: refetchPremium } = usePremiumUsers({
    page,
    limit: PAGE_SIZE,
    enabled: status === 'authenticated' && activeTab === 'all'
  });
  const { data: expiringData, isLoading: expiringLoading, refetch: refetchExpiring } = usePremiumUsersExpiringSoon(
    30,
    status === 'authenticated' && activeTab === 'expiring'
  );

  // Estado para buscador de candidatos
  const [showAddModal, setShowAddModal] = useState(false);
  const [candidateSearch, setCandidateSearch] = useState('');
  const { data: searchResults, isFetching: isSearchingCandidates } = useUsers({
    page: 1,
    limit: 5,
    search: candidateSearch, // El hook useUsers ya maneja el filtro por búsqueda
    enabled: showAddModal && candidateSearch.length > 1
  });


  const { mutateAsync: markAsPremium } = useMarkAsPremium();
  const { mutateAsync: removePremium } = useRemovePremium();
  const [updatingId, setUpdatingId] = useState<string | null>(null);

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

  if (status === 'unauthenticated' || !session) {
    router.push('/login');
    return null;
  }

  const handleOpenRenewModal = (user: UserModel) => {
    setSelectedUserForPremium(user);
    setShowPremiumModal(true);
  };

  const handleDownloadReport = async () => {
    try {
      const response = await apiClient.downloadRevenueReport();
      // Crear Blob y descargar
      const blob = new Blob([response.data], { type: 'text/csv' });
      const url = window.URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.setAttribute('download', `ingresos_manuales_${new Date().toISOString().split('T')[0]}.csv`);
      document.body.appendChild(link);
      link.click();
      link.remove();
      toast.success('Reporte descargado correctamente');
    } catch (error) {
      console.error(error);
      toast.error('Error al descargar el reporte');
    }
  };

  const handleRemovePremium = async (user: UserModel) => {
    if (user.subscriptionStatus !== 'active') {
      window.alert('El usuario no tiene premium activo.');
      return;
    }

    const confirmed = window.confirm(`¿Seguro que deseas remover el premium de ${user.email}?`);
    if (!confirmed) return;

    try {
      setUpdatingId(user.id);
      await removePremium(user.id);
      refetchPremium();
      refetchExpiring();
      refetchStats();
    } finally {
      setUpdatingId(null);
    }
  };

  const users = activeTab === 'all' ? (premiumData?.users ?? []) : (expiringData?.users ?? []);
  const total = activeTab === 'all' ? (premiumData?.total ?? 0) : (expiringData?.total ?? 0);

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

  const formatExpirationDate = (date: string | null) => {
    if (!date) return 'Sin fecha';
    const expDate = new Date(date);
    const now = new Date();
    const daysLeft = Math.ceil((expDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));

    if (daysLeft < 0) return 'Expirado';
    if (daysLeft === 0) return 'Expira hoy';
    if (daysLeft <= 7) return `Expira en ${daysLeft} día${daysLeft > 1 ? 's' : ''}`;

    return formatDistanceToNow(expDate, { addSuffix: true, locale: es });
  };

  const getExpirationColor = (date: string | null) => {
    if (!date) return 'text-gray-500';
    const expDate = new Date(date);
    const now = new Date();
    const daysLeft = Math.ceil((expDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));

    if (daysLeft < 0) return 'text-red-600';
    if (daysLeft <= 7) return 'text-orange-600';
    if (daysLeft <= 30) return 'text-yellow-600';
    return 'text-green-600';
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900 flex items-center gap-2">
            <StarIcon className="h-8 w-8 text-yellow-500" />
            Gestión Premium
          </h1>
          <p className="mt-1 text-sm text-gray-500">
            Administra usuarios premium, suscripciones y estadísticas
          </p>
        </div>
        <button
          onClick={() => {
            refetchPremium();
            refetchExpiring();
            refetchStats();
            refetchRevenue();
            refetchMonthly();
          }}
          className="flex items-center gap-2 rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-600 transition hover:border-brown-600 hover:text-brown-700"
        >
          <ArrowPathIcon className={`h-4 w-4 ${premiumFetching ? 'animate-spin' : ''}`} />
          Actualizar
        </button>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <div className="bg-white border border-gray-200 rounded-xl shadow-sm p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-500">Total Premium</p>
              <p className="mt-2 text-3xl font-bold text-gray-900">
                {statsLoading ? '...' : stats?.total ?? 0}
              </p>
            </div>
            <div className="h-12 w-12 rounded-full bg-yellow-100 flex items-center justify-center">
              <StarIcon className="h-6 w-6 text-yellow-600" />
            </div>
          </div>
        </div>

        <div className="bg-white border border-gray-200 rounded-xl shadow-sm p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-500">Próximos a expirar</p>
              <p className="mt-2 text-3xl font-bold text-orange-600">
                {statsLoading ? '...' : stats?.expiringSoon ?? 0}
              </p>
              <p className="mt-1 text-xs text-gray-500">En los próximos 30 días</p>
            </div>
            <div className="h-12 w-12 rounded-full bg-orange-100 flex items-center justify-center">
              <ClockIcon className="h-6 w-6 text-orange-600" />
            </div>
          </div>
        </div>

        <div className="bg-white border border-gray-200 rounded-xl shadow-sm p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-500">Agregados recientemente</p>
              <p className="mt-2 text-3xl font-bold text-green-600">
                {statsLoading ? '...' : stats?.recentlyAdded ?? 0}
              </p>
              <p className="mt-1 text-xs text-gray-500">Últimos 30 días</p>
            </div>
            <div className="h-12 w-12 rounded-full bg-green-100 flex items-center justify-center">
              <UserGroupIcon className="h-6 w-6 text-green-600" />
            </div>
          </div>
        </div>

        <div className="bg-white border border-gray-200 rounded-xl shadow-sm p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-500">Tasa de conversión</p>
              <p className="mt-2 text-3xl font-bold text-blue-600">
                {statsLoading ? '...' : stats?.total ? `${((stats.total / (stats.total + 100)) * 100).toFixed(1)}%` : '0%'}
              </p>
              <p className="mt-1 text-xs text-gray-500">Estimado</p>
            </div>
            <div className="h-12 w-12 rounded-full bg-blue-100 flex items-center justify-center">
              <ChartBarIcon className="h-6 w-6 text-blue-600" />
            </div>
          </div>
        </div>

        <div className="bg-white border border-gray-200 rounded-xl shadow-sm p-6 relative overflow-hidden">
          <RechargeParticles />
          <div className="flex items-center justify-between relative z-10">
            <div>
              <p className="text-sm font-medium text-gray-500">Ingresos Manuales</p>
              <p className="mt-2 text-3xl font-bold text-emerald-600">
                {revenueLoading ? '...' : new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(revenueData?.totalManualRevenue || 0)}
              </p>
              <p className="mt-1 text-xs text-gray-500">Acumulado Total</p>
            </div>
            <div className="h-12 w-12 rounded-full bg-emerald-100 flex items-center justify-center">
              <BanknotesIcon className="h-6 w-6 text-emerald-600" />
            </div>
          </div>
        </div>
      </div>

      {/* Tabla de reporte mensual */}
      <div className="bg-white border border-gray-200 rounded-xl shadow-sm p-6 mt-6 mb-8">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-lg font-semibold text-gray-800">Historial de Ingresos Mensuales</h3>
          <button
            onClick={handleDownloadReport}
            className="flex items-center gap-2 rounded-lg bg-emerald-600 px-4 py-2 text-sm font-medium text-white hover:bg-emerald-700 transition"
          >
            <BanknotesIcon className="h-4 w-4" />
            Descargar CSV
          </button>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-sm text-left">
            <thead className="bg-gray-50 text-gray-500 font-medium">
              <tr>
                <th className="px-4 py-3 rounded-l-lg">Mes</th>
                <th className="px-4 py-3">Transacciones</th>
                <th className="px-4 py-3 text-right rounded-r-lg">Total Recaudado</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {monthlyRevenue?.map((item) => (
                <tr key={item.month} className="hover:bg-gray-50 transition">
                  <td className="px-4 py-3 font-medium text-gray-800">{item.month}</td>
                  <td className="px-4 py-3 text-gray-600">{item.count}</td>
                  <td className="px-4 py-3 text-right font-semibold text-emerald-600">
                    {new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(item.total)}
                  </td>
                </tr>
              ))}
              {!monthlyRevenue?.length && (
                <tr><td colSpan={3} className="px-4 py-6 text-center text-gray-500">No hay registros aún</td></tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Tabs */}
      <div className="bg-white border border-gray-200 rounded-xl shadow-sm">
        <div className="border-b border-gray-200 flex flex-col sm:flex-row sm:items-center sm:justify-between pr-4 gap-4 sm:gap-0">
          <nav className="flex -mb-px" aria-label="Tabs">
            <button
              onClick={() => {
                setActiveTab('all');
                setPage(1);
              }}
              className={`${activeTab === 'all'
                ? 'border-brown-600 text-brown-600'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                } whitespace-nowrap py-4 px-6 border-b-2 font-medium text-sm transition`}
            >
              Todos los Premium ({premiumData?.total ?? 0})
            </button>
            <button
              onClick={() => {
                setActiveTab('expiring');
                setPage(1);
              }}
              className={`${activeTab === 'expiring'
                ? 'border-orange-600 text-orange-600'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                } whitespace-nowrap py-4 px-6 border-b-2 font-medium text-sm transition flex items-center gap-2`}
            >
              <ExclamationTriangleIcon className="h-4 w-4" />
              Próximos a expirar ({expiringData?.total ?? 0})
            </button>
          </nav>

          <button
            onClick={() => {
              setCandidateSearch('');
              setShowAddModal(true);
            }}
            className="flex items-center gap-2 rounded-lg bg-brown-600 px-4 py-2 text-sm font-medium text-white hover:bg-brown-700 transition shadow-sm mb-2 sm:mb-0 ml-4 sm:ml-0"
          >
            <UserPlusIcon className="h-4 w-4" />
            Agregar Premium
          </button>
        </div>

        {/* Search and Filters */}
        <div className="p-6 border-b border-gray-200">
          <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
            <div className="relative w-full sm:w-72">
              <input
                type="text"
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                placeholder="Buscar por nombre, correo o usuario..."
                className="w-full rounded-full border border-gray-200 bg-gray-50 px-4 py-2 pl-10 text-sm text-gray-800 focus:border-brown-700 focus:outline-none focus:ring-2 focus:ring-brown-100"
              />
              <MagnifyingGlassIcon className="h-5 w-5 text-gray-400 absolute left-3 top-1/2 -translate-y-1/2" />
            </div>
            <p className="text-sm text-gray-500">
              {filteredUsers.length.toLocaleString('es-ES')} de {total.toLocaleString('es-ES')} usuarios
            </p>
          </div>
        </div>

        {/* Users Table */}
        <div className="overflow-hidden">
          <table className="min-w-full divide-y divide-gray-200 bg-white">
            <thead className="bg-gray-50">
              <tr>
                <th className="py-3 px-6 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">
                  Usuario
                </th>
                <th className="py-3 px-6 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">
                  Estado Premium
                </th>
                <th className="py-3 px-6 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">
                  Origen de Suscripción
                </th>
                <th className="py-3 px-6 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">
                  Expiración y Días Restantes
                </th>
                <th className="py-3 px-6 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">
                  Último acceso
                </th>
                <th className="py-3 px-6 text-right text-xs font-semibold uppercase tracking-wider text-gray-500">
                  Acciones
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {(activeTab === 'all' ? premiumLoading : expiringLoading) ? (
                <tr>
                  <td colSpan={5} className="py-12 text-center text-sm text-gray-500">
                    Cargando usuarios premium...
                  </td>
                </tr>
              ) : filteredUsers.length === 0 ? (
                <tr>
                  <td colSpan={5} className="py-12 text-center text-sm text-gray-500">
                    {activeTab === 'expiring'
                      ? 'No hay usuarios próximos a expirar.'
                      : 'No se encontraron usuarios premium.'}
                  </td>
                </tr>
              ) : (
                filteredUsers.map((user: UserModel) => {
                  const expirationDate = user.subscriptionExpiresAt
                    ? new Date(user.subscriptionExpiresAt).toISOString()
                    : null;

                  return (
                    <tr key={user.id} className="hover:bg-gray-50 transition">
                      <td className="py-4 px-6">
                        <div className="flex items-center gap-3">
                          <div className="h-10 w-10 rounded-full bg-gradient-to-br from-yellow-400 to-yellow-600 text-white flex items-center justify-center text-sm font-semibold">
                            {user.firstName?.charAt(0)?.toUpperCase() || user.email.charAt(0).toUpperCase()}
                          </div>
                          <div>
                            <p className="text-sm font-medium text-gray-900">
                              {`${user.firstName} ${user.lastName}`.trim() || user.username}
                            </p>
                            <p className="text-xs text-gray-500">{user.email}</p>
                            <p className="text-xs text-gray-400">@{user.username}</p>
                          </div>
                        </div>
                      </td>
                      <td className="py-4 px-6">
                        <span className="inline-flex items-center rounded-full px-3 py-1 text-xs font-semibold bg-yellow-100 text-yellow-800">
                          <StarIcon className="h-3 w-3 mr-1" />
                          Premium Activo
                        </span>
                      </td>
                      <td className="py-4 px-6">
                        {user.subscriptionSource === 'revenuecat' ? (
                          <span className="inline-flex items-center rounded-full px-3 py-1 text-xs font-semibold bg-blue-100 text-blue-800">
                            🛒 RevenueCat
                          </span>
                        ) : (
                          <span className="inline-flex items-center rounded-full px-3 py-1 text-xs font-semibold bg-purple-100 text-purple-800">
                            👤 Manual
                          </span>
                        )}
                      </td>
                      <td className="py-4 px-6">
                        <div className="flex flex-col">
                          <span className={`text-sm font-medium ${getExpirationColor(expirationDate)}`}>
                            {formatExpirationDate(expirationDate)}
                          </span>
                          {expirationDate && (
                            <span className="text-xs text-gray-500">
                              {new Date(expirationDate).toLocaleDateString('es-ES', {
                                year: 'numeric',
                                month: 'short',
                                day: 'numeric',
                              })}
                            </span>
                          )}
                        </div>
                      </td>
                      <td className="py-4 px-6 text-sm text-gray-500">
                        {user.lastLoginAt
                          ? formatDistanceToNow(new Date(user.lastLoginAt), { addSuffix: true, locale: es })
                          : 'Nunca'}
                      </td>
                      <td className="py-4 px-6 text-right">
                        <div className="flex items-center justify-end gap-2">
                          <button
                            onClick={() => handleOpenRenewModal(user)}
                            className="inline-flex items-center rounded-lg border border-green-200 bg-green-50 px-3 py-1.5 text-xs font-semibold text-green-700 transition hover:border-green-300 hover:bg-green-100 disabled:opacity-50 disabled:cursor-not-allowed disabled:bg-gray-100 disabled:text-gray-400 disabled:border-gray-200"
                            disabled={user.subscriptionSource === 'revenuecat'}
                            title={
                              user.subscriptionSource === 'revenuecat'
                                ? 'Gestionado automáticamente por RevenueCat'
                                : 'Extender suscripción'
                            }
                          >
                            <ClockIcon className="h-3 w-3 mr-1" />
                            Renovar
                          </button>

                          <button
                            onClick={() => handleRemovePremium(user)}
                            className="inline-flex items-center rounded-lg border border-red-200 bg-red-50 px-3 py-1.5 text-xs font-semibold text-red-700 transition hover:border-red-300 hover:bg-red-100 disabled:cursor-not-allowed disabled:opacity-40"
                            disabled={updatingId === user.id || user.subscriptionSource === 'revenuecat'}
                            title={
                              user.subscriptionSource === 'revenuecat'
                                ? 'No se puede quitar: Suscripción de RevenueCat (Google Play/App Store)'
                                : 'Remover premium'
                            }
                          >
                            {updatingId === user.id ? (
                              <ArrowPathIcon className="h-4 w-4 animate-spin" />
                            ) : (
                              'Quitar'
                            )}
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
        {activeTab === 'all' && totalPages > 1 && (
          <div className="px-6 py-4 flex flex-col items-center justify-between gap-4 sm:flex-row border-t border-gray-200">
            <p className="text-sm text-gray-500">
              Página {page} de {totalPages}
            </p>
            <div className="flex items-center gap-2">
              <button
                onClick={handlePrev}
                disabled={page === 1}
                className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-500 transition hover:border-brown-600 hover:text-brown-700 disabled:cursor-not-allowed disabled:opacity-50"
              >
                Anterior
              </button>
              <button
                onClick={handleNext}
                disabled={page === totalPages}
                className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-500 transition hover:border-brown-600 hover:text-brown-700 disabled:cursor-not-allowed disabled:opacity-50"
              >
                Siguiente
              </button>
            </div>
          </div>
        )}
      </div>



      {/* MODAL DE RENOVACIÓN DE PLANES */}
      {showPremiumModal && selectedUserForPremium && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/30 backdrop-blur-sm px-4">
          <div className="w-full max-w-md rounded-2xl bg-white shadow-xl">
            <div className="flex items-center justify-between border-b border-gray-200 px-6 py-4">
              <div>
                <h2 className="text-lg font-semibold text-gray-900">Renovar Suscripción</h2>
                <p className="text-sm text-gray-500">
                  Extender plan para <b>{selectedUserForPremium.firstName || selectedUserForPremium.username}</b>
                </p>
              </div>
              <button
                onClick={() => setShowPremiumModal(false)}
                className="rounded-full p-1 text-gray-400 transition hover:bg-gray-100 hover:text-gray-600"
              >
                <XMarkIcon className="h-5 w-5" />
              </button>
            </div>

            <div className="px-6 py-6">
              <PremiumPlans
                userId={selectedUserForPremium.id}
                onSuccess={() => {
                  setShowPremiumModal(false);
                  refetchPremium();
                  refetchExpiring();
                  refetchStats();
                }}
              />
              <p className="text-xs text-gray-400 mt-4 text-center">
                Al seleccionar un plan, la nueva fecha de expiración se calculará a partir de hoy (reinicia la vigencia).
              </p>
            </div>
          </div>
        </div>
      )}

      {/* Modal para Buscar y Agregar Premium */}
      {showAddModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/30 backdrop-blur-sm px-4">
          <div className="w-full max-w-lg rounded-2xl bg-white shadow-xl">
            <div className="flex items-center justify-between border-b border-gray-200 px-6 py-4">
              <h2 className="text-lg font-semibold text-gray-900">Otorgar Premium Manual</h2>
              <button onClick={() => setShowAddModal(false)} className="rounded-full p-1 text-gray-400 hover:bg-gray-100">
                <XMarkIcon className="h-5 w-5" />
              </button>
            </div>

            <div className="p-6">
              <div className="relative mb-4">
                <input
                  type="text"
                  value={candidateSearch}
                  onChange={(e) => setCandidateSearch(e.target.value)}
                  placeholder="Buscar usuario por email o nombre..."
                  className="w-full rounded-lg border border-gray-300 px-4 py-2 pl-10 focus:border-brown-500 focus:ring-brown-500"
                  autoFocus
                />
                <MagnifyingGlassIcon className="h-5 w-5 text-gray-400 absolute left-3 top-2.5" />
              </div>

              <div className="max-h-60 overflow-y-auto space-y-2">
                {isSearchingCandidates && <p className="text-sm text-gray-500 text-center py-2">Buscando...</p>}

                {!isSearchingCandidates && candidateSearch.length > 1 && searchResults?.users.length === 0 && (
                  <p className="text-sm text-gray-500 text-center py-2">No se encontraron usuarios.</p>
                )}

                {searchResults?.users.map(user => (
                  <div key={user.id} className="flex items-center justify-between p-3 rounded-lg border border-gray-100 hover:bg-gray-50 transition">
                    <div className="flex flex-col">
                      <span className="font-medium text-gray-900">{user.email}</span>
                      <span className="text-xs text-gray-500">{user.firstName} {user.lastName}</span>
                      {user.subscriptionStatus === 'active' && <span className="text-xs text-yellow-600 font-semibold">Ya es Premium</span>}
                    </div>
                    <button
                      onClick={() => {
                        if (user.subscriptionStatus === 'active') {
                          toast.error('Este usuario ya es Premium');
                          return;
                        }
                        setSelectedUserForPremium(user);
                        setShowAddModal(false);
                        setShowPremiumModal(true);
                      }}
                      disabled={user.subscriptionStatus === 'active'}
                      className="text-sm bg-brown-600 text-white px-3 py-1.5 rounded-md hover:bg-brown-700 disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      Seleccionar
                    </button>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
