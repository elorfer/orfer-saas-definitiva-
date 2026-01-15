'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { toast } from 'react-hot-toast';
import {
  PlusIcon,
  MagnifyingGlassIcon,
  PencilIcon,
  TrashIcon,
  PlayIcon,
  PauseIcon,
  ChartBarIcon,
  Cog6ToothIcon,
  MusicalNoteIcon,
} from '@heroicons/react/24/outline';
import { useAds, useDeleteAd, useActivateAd, usePauseAd, useAdFrequency, useUpdateAdFrequency, type AudioAd } from '@/hooks/useAds';

const PAGE_SIZE = 10;

const statusLabels: Record<string, { label: string; badge: string }> = {
  draft: { label: 'Borrador', badge: 'bg-gray-100 text-gray-700' },
  active: { label: 'Activo', badge: 'bg-green-100 text-green-700' },
  paused: { label: 'Pausado', badge: 'bg-yellow-100 text-yellow-700' },
  expired: { label: 'Expirado', badge: 'bg-red-100 text-red-700' },
};

export default function AdsPage() {
  const router = useRouter();
  const [page, setPage] = useState(1);
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState<string>('');
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [showFrequencySettings, setShowFrequencySettings] = useState(false);
  const [newFrequency, setNewFrequency] = useState<number | null>(null);
  const [selectedStatsAd, setSelectedStatsAd] = useState<AudioAd | null>(null);

  const { data, isLoading, refetch } = useAds(page, PAGE_SIZE, statusFilter || undefined);
  const deleteAd = useDeleteAd();
  const activateAd = useActivateAd();
  const pauseAd = usePauseAd();

  // Hooks para frecuencia de anuncios
  const { data: frequencyData, isLoading: frequencyLoading } = useAdFrequency();
  const updateFrequency = useUpdateAdFrequency();

  const ads = data?.ads || [];
  const total = data?.total || 0;
  const totalPages = Math.ceil(total / PAGE_SIZE);

  const handleDelete = async (ad: AudioAd) => {
    if (!confirm(`¿Estás seguro de eliminar el anuncio "${ad.title}"?`)) {
      return;
    }

    setDeletingId(ad.id);
    try {
      await deleteAd.mutateAsync(ad.id);
    } finally {
      setDeletingId(null);
    }
  };

  const handleActivate = async (id: string) => {
    try {
      await activateAd.mutateAsync(id);
    } catch (error) {
      // Error ya manejado en el hook
    }
  };

  const handlePause = async (id: string) => {
    try {
      await pauseAd.mutateAsync(id);
    } catch (error) {
      // Error ya manejado en el hook
    }
  };

  const filteredAds = ads.filter((ad: AudioAd) =>
    ad.title.toLowerCase().includes(searchTerm.toLowerCase()) ||
    ad.advertiserName.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const handleFrequencyUpdate = async () => {
    if (newFrequency === null || newFrequency < 1 || newFrequency > 20) {
      toast.error('La frecuencia debe estar entre 1 y 20 canciones');
      return;
    }
    await updateFrequency.mutateAsync(newFrequency);
    setShowFrequencySettings(false);
    setNewFrequency(null);
  };

  const currentFrequency = frequencyData?.frequency ?? 3;

  return (
    <div className="p-6">
      <div className="mb-6 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Anuncios de Audio</h1>
          <p className="text-sm text-gray-500 mt-1">Gestiona los anuncios que se reproducen en la app</p>
        </div>
        <div className="flex items-center gap-3">
          <button
            onClick={() => {
              setNewFrequency(currentFrequency);
              setShowFrequencySettings(!showFrequencySettings);
            }}
            className="flex items-center gap-2 px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors border border-gray-300"
          >
            <Cog6ToothIcon className="w-5 h-5" />
            Configurar Frecuencia
          </button>
          <button
            onClick={() => router.push('/dashboard/ads/create')}
            className="flex items-center gap-2 px-4 py-2 bg-brown-600 text-white rounded-lg hover:bg-brown-700 transition-colors"
          >
            <PlusIcon className="w-5 h-5" />
            Crear Anuncio
          </button>
        </div>
      </div>

      {/* Panel de configuración de frecuencia */}
      {showFrequencySettings && (
        <div className="mb-6 bg-gradient-to-r from-amber-50 to-orange-50 border border-amber-200 rounded-xl p-6 shadow-sm">
          <div className="flex items-start justify-between">
            <div className="flex items-center gap-3">
              <div className="p-3 bg-amber-100 rounded-lg">
                <MusicalNoteIcon className="w-6 h-6 text-amber-600" />
              </div>
              <div>
                <h3 className="text-lg font-semibold text-gray-900">Frecuencia de Anuncios</h3>
                <p className="text-sm text-gray-600 mt-1">
                  Define cada cuántas canciones se reproduce un anuncio en la app
                </p>
              </div>
            </div>
            <button
              onClick={() => setShowFrequencySettings(false)}
              className="text-gray-400 hover:text-gray-600"
            >
              ✕
            </button>
          </div>

          <div className="mt-6 flex items-center gap-6">
            <div className="flex-1">
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Canciones entre anuncios
              </label>
              <div className="flex items-center gap-4">
                <input
                  type="range"
                  min="1"
                  max="20"
                  value={newFrequency ?? currentFrequency}
                  onChange={(e) => setNewFrequency(parseInt(e.target.value))}
                  className="flex-1 h-2 bg-amber-200 rounded-lg appearance-none cursor-pointer accent-amber-500"
                />
                <div className="flex items-center gap-2">
                  <input
                    type="number"
                    min="1"
                    max="20"
                    value={newFrequency ?? currentFrequency}
                    onChange={(e) => setNewFrequency(parseInt(e.target.value) || 1)}
                    className="w-20 px-3 py-2 text-center text-lg font-bold border border-gray-300 rounded-lg focus:ring-2 focus:ring-amber-500 focus:border-transparent"
                  />
                  <span className="text-gray-500">canciones</span>
                </div>
              </div>
              <p className="mt-2 text-xs text-gray-500">
                Valor actual: <span className="font-semibold text-amber-600">{currentFrequency}</span> canciones entre cada anuncio
              </p>
            </div>

            <div className="flex flex-col gap-2">
              <button
                onClick={handleFrequencyUpdate}
                disabled={updateFrequency.isLoading || newFrequency === currentFrequency}
                className="px-6 py-2 bg-amber-500 text-white font-medium rounded-lg hover:bg-amber-600 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
              >
                {updateFrequency.isLoading ? (
                  <>
                    <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                    Guardando...
                  </>
                ) : (
                  'Guardar cambios'
                )}
              </button>
              <button
                onClick={() => {
                  setShowFrequencySettings(false);
                  setNewFrequency(null);
                }}
                className="px-6 py-2 text-gray-600 font-medium rounded-lg hover:bg-gray-100 transition-colors"
              >
                Cancelar
              </button>
            </div>
          </div>

          <div className="mt-4 p-3 bg-white/60 rounded-lg border border-amber-100">
            <p className="text-xs text-gray-600">
              💡 <strong>Tip:</strong> Un valor más alto (ej: 5-10) mejora la experiencia del usuario pero reduce los ingresos por publicidad.
              Un valor más bajo (ej: 2-3) aumenta los ingresos pero puede afectar la retención de usuarios.
            </p>
          </div>
        </div>
      )}

      {/* Indicador rápido de frecuencia actual (siempre visible) */}
      {!showFrequencySettings && (
        <div className="mb-4 flex items-center gap-2 text-sm text-gray-600">
          <MusicalNoteIcon className="w-4 h-4 text-amber-500" />
          <span>
            Frecuencia actual: <strong className="text-amber-600">{frequencyLoading ? '...' : currentFrequency}</strong> canciones entre anuncios
          </span>
        </div>
      )}

      {/* Filtros */}
      <div className="mb-6 flex gap-4">
        <div className="flex-1 relative">
          <MagnifyingGlassIcon className="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" />
          <input
            type="text"
            placeholder="Buscar por título o anunciante..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-brown-500 focus:border-transparent"
          />
        </div>
        <select
          value={statusFilter}
          onChange={(e) => {
            setStatusFilter(e.target.value);
            setPage(1);
          }}
          className="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-brown-500 focus:border-transparent"
        >
          <option value="">Todos los estados</option>
          <option value="draft">Borrador</option>
          <option value="active">Activo</option>
          <option value="paused">Pausado</option>
          <option value="expired">Expirado</option>
        </select>
      </div>

      {/* Tabla */}
      {isLoading ? (
        <div className="text-center py-12">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-brown-600 mx-auto"></div>
          <p className="mt-4 text-gray-500">Cargando anuncios...</p>
        </div>
      ) : filteredAds.length === 0 ? (
        <div className="text-center py-12 bg-gray-50 rounded-lg">
          <p className="text-gray-500">No hay anuncios disponibles</p>
          <button
            onClick={() => router.push('/dashboard/ads/create')}
            className="mt-4 text-brown-600 hover:text-brown-700 font-medium"
          >
            Crear tu primer anuncio
          </button>
        </div>
      ) : (
        <>
          <div className="bg-white rounded-lg shadow overflow-hidden">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Anuncio
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Anunciante
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Duración
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Estado
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Estadísticas
                  </th>
                  <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Acciones
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {filteredAds.map((ad: AudioAd) => {
                  // Normalizar el estado a minúsculas para la comparación
                  const normalizedStatus = (ad.status || '').toLowerCase();
                  const statusInfo = statusLabels[normalizedStatus] || statusLabels.draft;
                  return (
                    <tr key={ad.id} className="hover:bg-gray-50">
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="flex items-center">
                          {ad.coverImageUrl ? (
                            <img
                              src={ad.coverImageUrl}
                              alt={ad.title}
                              className="w-10 h-10 rounded object-cover mr-3"
                            />
                          ) : (
                            <div className="w-10 h-10 rounded bg-gray-200 flex items-center justify-center mr-3">
                              <span className="text-gray-400 text-xs">📢</span>
                            </div>
                          )}
                          <div>
                            <div className="text-sm font-medium text-gray-900">{ad.title}</div>
                            <div className="text-xs text-gray-500">
                              {ad.targeting === 'all' ? 'Todos' :
                                ad.targeting === 'genre' ? 'Por género' :
                                  ad.targeting === 'artist' ? 'Por artista' : 'Por playlist'}
                            </div>
                          </div>
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="text-sm text-gray-900">{ad.advertiserName}</div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="text-sm text-gray-900">{ad.durationSeconds}s</div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <span className={`px-2 py-1 text-xs font-medium rounded-full ${statusInfo.badge}`}>
                          {statusInfo.label}
                        </span>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="text-sm text-gray-900">
                          <div>Reproducciones: {ad.totalPlays}</div>
                          <div className="text-xs text-gray-500">Clicks: {ad.totalClicks}</div>
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                        <div className="flex items-center justify-end gap-2">
                          <button
                            onClick={() => setSelectedStatsAd(ad)}
                            className="p-2 text-blue-600 hover:text-blue-900 hover:bg-blue-50 rounded transition-colors"
                            title="Ver estadísticas"
                          >
                            <ChartBarIcon className="w-5 h-5" />
                          </button>
                          {/* Botón de Activar/Pausar - Más visible */}
                          {(ad.status?.toLowerCase() === 'active' || ad.status === 'ACTIVE') ? (
                            <button
                              onClick={() => handlePause(ad.id)}
                              className="flex items-center gap-1 px-3 py-2 bg-yellow-50 text-yellow-700 hover:bg-yellow-100 rounded-lg transition-colors font-medium"
                              title="Pausar anuncio"
                            >
                              <PauseIcon className="w-5 h-5" />
                              <span className="text-sm">Pausar</span>
                            </button>
                          ) : (
                            <button
                              onClick={() => handleActivate(ad.id)}
                              className="flex items-center gap-1 px-3 py-2 bg-green-50 text-green-700 hover:bg-green-100 rounded-lg transition-colors font-medium"
                              title="Activar anuncio"
                            >
                              <PlayIcon className="w-5 h-5" />
                              <span className="text-sm">Activar</span>
                            </button>
                          )}
                          <button
                            onClick={() => router.push(`/dashboard/ads/${ad.id}`)}
                            className="p-2 text-blue-600 hover:text-blue-900 hover:bg-blue-50 rounded transition-colors"
                            title="Editar"
                          >
                            <PencilIcon className="w-5 h-5" />
                          </button>
                          <button
                            onClick={() => handleDelete(ad)}
                            disabled={deletingId === ad.id}
                            className="p-2 text-red-600 hover:text-red-900 hover:bg-red-50 rounded transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                            title="Eliminar"
                          >
                            <TrashIcon className="w-5 h-5" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>

          {/* Paginación */}
          {totalPages > 1 && (
            <div className="mt-6 flex items-center justify-between">
              <div className="text-sm text-gray-500">
                Mostrando {(page - 1) * PAGE_SIZE + 1} a {Math.min(page * PAGE_SIZE, total)} de {total} anuncios
              </div>
              <div className="flex gap-2">
                <button
                  onClick={() => setPage((p) => Math.max(1, p - 1))}
                  disabled={page === 1}
                  className="px-4 py-2 border border-gray-300 rounded-lg disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50"
                >
                  Anterior
                </button>
                <button
                  onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                  disabled={page === totalPages}
                  className="px-4 py-2 border border-gray-300 rounded-lg disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50"
                >
                  Siguiente
                </button>
              </div>
            </div>
          )}
        </>
      )}

      {/* Stats Modal */}
      {selectedStatsAd && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50 animate-fade-in">
          <div className="bg-white rounded-2xl max-w-lg w-full shadow-2xl overflow-hidden transform transition-all scale-100">
            <div className="bg-gradient-to-r from-blue-600 to-indigo-700 p-6 text-white">
              <div className="flex items-start justify-between">
                <div>
                  <h3 className="text-xl font-bold flex items-center gap-2">
                    <ChartBarIcon className="w-6 h-6" />
                    Estadísticas del Anuncio
                  </h3>
                  <p className="text-blue-100 mt-1 text-sm">{selectedStatsAd.title}</p>
                </div>
                <button
                  onClick={() => setSelectedStatsAd(null)}
                  className="bg-white/20 hover:bg-white/30 rounded-full p-1 transition-colors"
                >
                  <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>
            </div>

            <div className="p-6">
              {/* Key Metrics Grid */}
              <div className="grid grid-cols-3 gap-4 mb-8">
                <StatCard
                  label="Reproducciones"
                  value={selectedStatsAd.totalPlays.toString()}
                  color="bg-green-50 text-green-700"
                  icon={<PlayIcon className="w-5 h-5" />}
                />
                <StatCard
                  label="Clicks"
                  value={selectedStatsAd.totalClicks.toString()}
                  color="bg-orange-50 text-orange-700"
                  icon={<div className="w-5 h-5 font-bold text-center cursor-default">🖱️</div>}
                />
                <StatCard
                  label="CTR"
                  value={selectedStatsAd.totalPlays > 0
                    ? `${((selectedStatsAd.totalClicks / selectedStatsAd.totalPlays) * 100).toFixed(2)}%`
                    : '0.00%'}
                  color="bg-blue-50 text-blue-700"
                  icon={<ChartBarIcon className="w-5 h-5" />}
                />
              </div>

              {/* Details List */}
              <div className="space-y-4 bg-gray-50 rounded-xl p-4">
                <DetailRow
                  icon={<div className="w-5 h-5">👤</div>}
                  label="Anunciante"
                  value={selectedStatsAd.advertiserName}
                />
                <DetailRow
                  icon={<div className="w-5 h-5">⏱️</div>}
                  label="Duración"
                  value={`${selectedStatsAd.durationSeconds} segundos`}
                />
                <DetailRow
                  icon={<div className="w-5 h-5">⏭️</div>}
                  label="Skippable"
                  value={selectedStatsAd.isSkippable ? `Sí (tras ${selectedStatsAd.skipAfterSeconds}s)` : 'No'}
                />
                {selectedStatsAd.clickThroughUrl && (
                  <div className="pt-2 border-t border-gray-200 mt-2">
                    <p className="text-xs text-gray-500 mb-1">URL de destino</p>
                    <a
                      href={selectedStatsAd.clickThroughUrl}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-blue-600 hover:text-blue-800 text-sm truncate block"
                    >
                      {selectedStatsAd.clickThroughUrl}
                    </a>
                  </div>
                )}
              </div>
            </div>

            <div className="bg-gray-50 p-4 flex justify-end">
              <button
                onClick={() => setSelectedStatsAd(null)}
                className="px-5 py-2 bg-white border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 font-medium transition-colors shadow-sm"
              >
                Cerrar
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function StatCard({ label, value, color, icon }: { label: string, value: string, color: string, icon: React.ReactNode }) {
  return (
    <div className={`p-4 rounded-xl ${color} flex flex-col items-center justify-center text-center shadow-sm border border-transparent hover:border-current transition-colors`}>
      <div className="mb-2 opacity-80">{icon}</div>
      <div className="text-xl font-bold mb-0.5">{value}</div>
      <div className="text-xs font-medium uppercase tracking-wide opacity-70">{label}</div>
    </div>
  );
}

function DetailRow({ icon, label, value }: { icon: React.ReactNode, label: string, value: string }) {
  return (
    <div className="flex items-center justify-between">
      <div className="flex items-center gap-3">
        <span className="text-gray-400">{icon}</span>
        <span className="text-gray-600 font-medium text-sm">{label}</span>
      </div>
      <span className="text-gray-900 font-semibold text-sm">{value}</span>
    </div>
  );
}


