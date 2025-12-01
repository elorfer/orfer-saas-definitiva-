'use client';

import React, { useEffect, useMemo, useState, useRef } from 'react';
import Link from 'next/link';
import { toast } from 'react-hot-toast';
import { apiClient } from '@/lib/api';
import { useQueryClient } from 'react-query';
import {
  TrashIcon,
  ArrowPathIcon,
} from '@heroicons/react/24/outline';

type ArtistLite = {
  id: string;
  name: string;
  profilePhotoUrl?: string | null;
  nationalityCode?: string | null;
  featured: boolean;
};

const flagEmoji = (code?: string | null) => {
  if (!code || code.length !== 2) return '🏳️';
  const cc = code.toUpperCase();
  const pts = Array.from(cc).map((c) => 127397 + c.charCodeAt(0));
  return String.fromCodePoint(...pts);
};

// Componente para checkbox con estado indeterminado
function SelectAllCheckbox({ 
  checked, 
  indeterminate, 
  onChange 
}: { 
  checked: boolean; 
  indeterminate: boolean; 
  onChange: (checked: boolean) => void;
}) {
  const checkboxRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (checkboxRef.current) {
      checkboxRef.current.indeterminate = indeterminate;
    }
  }, [indeterminate]);

  return (
    <input
      ref={checkboxRef}
      type="checkbox"
      checked={checked}
      onChange={(e) => onChange(e.target.checked)}
      className="h-4 w-4 rounded border-gray-300 text-purple-600 focus:ring-purple-500 cursor-pointer"
    />
  );
}

export default function ArtistsPage() {
  const queryClient = useQueryClient();
  const [items, setItems] = useState<ArtistLite[]>([]);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(false);
  const [selectedArtistIds, setSelectedArtistIds] = useState<Set<string>>(new Set());
  const [isDeletingMultiple, setIsDeletingMultiple] = useState(false);
  const [deletingId, setDeletingId] = useState<string | null>(null);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return items;
    return items.filter((a) => a.name.toLowerCase().includes(q));
  }, [items, search]);

  const fetchArtists = async () => {
    setLoading(true);
    try {
      const res = await apiClient.getArtists(1, 100);
      const data = res.data?.artists ?? res.data?.artists ?? res.data;
      const mapped: ArtistLite[] = (data?.artists ?? data ?? []).map((a: any) => ({
        id: a.id,
        name: a.name ?? a.stageName,
        profilePhotoUrl: a.profilePhotoUrl ?? a.user?.avatarUrl ?? null,
        nationalityCode: a.nationalityCode ?? null,
        featured: !!a.featured || !!a.isFeatured,
      }));
      setItems(mapped);
    } catch (error: any) {
      console.error('[ArtistsPage] Error al cargar artistas:', error);

      const status = error?.response?.status;
      const message = error?.response?.data?.message;

      if (status === 401) {
        toast.error('Sesión expirada o no autorizada. Por favor, vuelve a iniciar sesión.');
        if (typeof window !== 'undefined') {
          // Limpia el token por si el interceptor aún no lo hizo
          localStorage.removeItem('access_token');
          window.location.href = '/login';
        }
      } else {
        toast.error(
          typeof message === 'string'
            ? message
            : 'Error al cargar artistas. Intenta nuevamente más tarde.'
        );
      }
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchArtists();
  }, []);

  const handleSelectArtist = (artistId: string, selected: boolean) => {
    setSelectedArtistIds((prev) => {
      const newSet = new Set(prev);
      if (selected) {
        newSet.add(artistId);
      } else {
        newSet.delete(artistId);
      }
      return newSet;
    });
  };

  const handleSelectAll = (checked: boolean) => {
    if (checked) {
      const allIds = new Set(filtered.map((a) => a.id));
      setSelectedArtistIds(allIds);
    } else {
      setSelectedArtistIds(new Set());
    }
  };

  const handleDeleteArtist = async (artist: ArtistLite) => {
    const confirmed = window.confirm(`¿Seguro que deseas eliminar "${artist.name}"?`);
    if (!confirmed) return;

    try {
      setDeletingId(artist.id);
      await apiClient.deleteArtist(artist.id);
      
      // Remover de la lista
      setItems((prev) => prev.filter((i) => i.id !== artist.id));
      
      // Remover de selección si estaba seleccionado
      setSelectedArtistIds((prev) => {
        const newSet = new Set(prev);
        newSet.delete(artist.id);
        return newSet;
      });
      
      toast.success('Artista eliminado exitosamente');
    } catch (error: any) {
      console.error('[ArtistsPage] Error al eliminar artista:', error);
      const message = error?.response?.data?.message;
      toast.error(
        typeof message === 'string'
          ? message
          : 'Error al eliminar el artista'
      );
    } finally {
      setDeletingId(null);
    }
  };

  const handleDeleteSelected = async () => {
    if (selectedArtistIds.size === 0) return;

    const count = selectedArtistIds.size;
    const confirmed = window.confirm(
      `¿Seguro que deseas eliminar ${count} ${count === 1 ? 'artista' : 'artistas'}?`
    );
    if (!confirmed) return;

    try {
      setIsDeletingMultiple(true);
      const idsArray = Array.from(selectedArtistIds);
      
      // Eliminar todos los artistas seleccionados directamente con la API
      await Promise.all(idsArray.map((id) => apiClient.deleteArtist(id)));
      
      // Remover de la lista
      setItems((prev) => prev.filter((i) => !selectedArtistIds.has(i.id)));
      
      // Limpiar selección
      setSelectedArtistIds(new Set());
      
      // Mostrar solo una notificación con el conteo total
      toast.success(`${count} ${count === 1 ? 'artista eliminado' : 'artistas eliminados'} exitosamente`);
    } catch (error: any) {
      console.error('Error al eliminar artistas:', error);
      const message = error?.response?.data?.message;
      toast.error(
        typeof message === 'string'
          ? message
          : 'Error al eliminar algunos artistas'
      );
    } finally {
      setIsDeletingMultiple(false);
    }
  };

  const toggleFeatured = async (artist: ArtistLite) => {
    const next = !artist.featured;
    setItems((prev) => prev.map((i) => (i.id === artist.id ? { ...i, featured: next } : i)));
    try {
      await apiClient.toggleArtistFeatured(artist.id, next);
    } catch (error: any) {
      console.error('[ArtistsPage] Error al cambiar destacado:', error);
      setItems((prev) => prev.map((i) => (i.id === artist.id ? { ...i, featured: !next } : i)));
      const status = error?.response?.status;
      const message = error?.response?.data?.message;

      if (status === 401) {
        toast.error('Sesión expirada o no autorizada. Por favor, vuelve a iniciar sesión.');
        if (typeof window !== 'undefined') {
          localStorage.removeItem('access_token');
          window.location.href = '/login';
        }
      } else {
        toast.error(
          typeof message === 'string'
            ? message
            : 'No se pudo actualizar el estado destacado del artista.'
        );
      }
    }
  };

  const allSelected = filtered.length > 0 && filtered.every((a) => selectedArtistIds.has(a.id));
  const someSelected = selectedArtistIds.size > 0 && !allSelected;

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6 space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Artistas</h1>
          <p className="mt-1 text-sm text-gray-500">Gestiona y destaca artistas.</p>
        </div>
        <div className="flex gap-2">
          <Link href="/dashboard/artists/featured" className="px-3 py-2 rounded-lg border">
            Ver destacados
          </Link>
          <Link href="/dashboard/artists/create" className="px-3 py-2 rounded-lg bg-purple-600 text-white">
            Crear artista
          </Link>
        </div>
      </div>
      <div className="flex items-center justify-between gap-3 flex-wrap">
        <div className="flex items-center gap-3 flex-1">
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Buscar artista..."
            className="w-full md:w-80 rounded-full border border-gray-200 bg-gray-50 px-4 py-2 text-sm"
          />
          <button onClick={fetchArtists} className="px-3 py-2 rounded-lg border bg-white">
            {loading ? 'Actualizando...' : 'Actualizar'}
          </button>
        </div>
        {selectedArtistIds.size > 0 && (
          <div className="flex items-center gap-3">
            <span className="text-sm text-gray-600 font-medium">
              {selectedArtistIds.size} {selectedArtistIds.size === 1 ? 'artista seleccionado' : 'artistas seleccionados'}
            </span>
            <button
              onClick={handleDeleteSelected}
              disabled={isDeletingMultiple}
              className="inline-flex items-center gap-2 rounded-lg border border-red-300 bg-red-50 px-4 py-2 text-sm font-semibold text-red-700 transition hover:bg-red-100 disabled:cursor-not-allowed disabled:opacity-50"
            >
              {isDeletingMultiple ? (
                <>
                  <ArrowPathIcon className="h-4 w-4 animate-spin" />
                  Eliminando...
                </>
              ) : (
                <>
                  <TrashIcon className="h-4 w-4" />
                  Eliminar seleccionados
                </>
              )}
            </button>
          </div>
        )}
      </div>

      <div className="bg-white rounded-2xl shadow-lg ring-1 ring-black/5 overflow-hidden hc-card">
        <table className="min-w-full text-sm">
          <thead className="bg-gray-50/80">
            <tr>
              <th className="text-left p-3 font-semibold text-gray-700 w-12">
                <SelectAllCheckbox
                  checked={allSelected}
                  indeterminate={someSelected}
                  onChange={handleSelectAll}
                />
              </th>
              <th className="text-left p-3 font-semibold text-gray-700">Perfil</th>
              <th className="text-left p-3 font-semibold text-gray-700">Nombre</th>
              <th className="text-left p-3 font-semibold text-gray-700">País</th>
              <th className="text-left p-3 font-semibold text-gray-700">Destacado</th>
              <th className="text-left p-3 font-semibold text-gray-700">Acciones</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {filtered.map((a) => (
              <tr 
                key={a.id} 
                className={`bg-white hover:bg-gray-50 transition-colors ${selectedArtistIds.has(a.id) ? 'bg-blue-50' : ''}`}
              >
                <td className="p-3">
                  <input
                    type="checkbox"
                    checked={selectedArtistIds.has(a.id)}
                    onChange={(e) => handleSelectArtist(a.id, e.target.checked)}
                    className="h-4 w-4 rounded border-gray-300 text-purple-600 focus:ring-purple-500 cursor-pointer"
                  />
                </td>
                <td className="p-3">
                  {a.profilePhotoUrl ? (
                    <img
                      src={a.profilePhotoUrl}
                      alt={a.name}
                      className="h-10 w-10 rounded-full object-cover"
                    />
                  ) : (
                    <div className="h-10 w-10 rounded-full bg-gray-200 ring-1 ring-inset ring-gray-300 hc-ring" />
                  )}
                </td>
                <td className="p-3">{a.name}</td>
                <td className="p-3">{flagEmoji(a.nationalityCode)}</td>
                <td className="p-3">
                  <button
                    onClick={() => toggleFeatured(a)}
                    className={`px-2 py-1 rounded-md ${
                      a.featured ? 'bg-yellow-200 text-yellow-800' : 'bg-gray-100 text-gray-600'
                    }`}
                  >
                    {a.featured ? 'Sí' : 'No'}
                  </button>
                </td>
                <td className="p-3">
                  <div className="flex items-center gap-2">
                    <Link
                      href={`/dashboard/artists/${a.id}/edit`}
                      className="px-2 py-1 rounded-md border"
                    >
                      Editar
                    </Link>
                    <button
                      onClick={() => handleDeleteArtist(a)}
                      disabled={deletingId === a.id || isDeletingMultiple}
                      className="inline-flex items-center gap-1 px-2 py-1 rounded-md border border-red-200 bg-red-50 text-red-700 hover:bg-red-100 transition disabled:cursor-not-allowed disabled:opacity-50"
                    >
                      {deletingId === a.id ? (
                        <>
                          <ArrowPathIcon className="h-3 w-3 animate-spin" />
                          Eliminando...
                        </>
                      ) : (
                        <>
                          <TrashIcon className="h-3 w-3" />
                          Eliminar
                        </>
                      )}
                    </button>
                  </div>
                </td>
              </tr>
            ))}
            {filtered.length === 0 && (
              <tr>
                <td colSpan={6} className="p-6 text-center text-gray-500">
                  Sin resultados
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}


