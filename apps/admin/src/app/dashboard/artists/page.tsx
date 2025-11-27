'use client';

import React, { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { apiClient } from '@/lib/api';

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
  const pts = Array.from(cc).map(c => 127397 + c.charCodeAt(0));
  return String.fromCodePoint(...pts);
};

export default function ArtistsPage() {
  const [items, setItems] = useState<ArtistLite[]>([]);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(false);


  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return items;
    return items.filter(a => a.name.toLowerCase().includes(q));
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
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchArtists();
  }, []);

  const toggleFeatured = async (artist: ArtistLite) => {
    const next = !artist.featured;
    setItems(prev => prev.map(i => i.id === artist.id ? { ...i, featured: next } : i));
    try {
      await apiClient.toggleArtistFeatured(artist.id, next);
    } catch {
      // revert on error
      setItems(prev => prev.map(i => i.id === artist.id ? { ...i, featured: !next } : i));
    }
  };

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
          <div className="flex items-center gap-3">
            <input
              value={search}
              onChange={e => setSearch(e.target.value)}
              placeholder="Buscar artista..."
              className="w-full md:w-80 rounded-full border border-gray-200 bg-gray-50 px-4 py-2 text-sm"
            />
            <button onClick={fetchArtists} className="px-3 py-2 rounded-lg border bg-white">{loading ? 'Actualizando...' : 'Actualizar'}</button>
          </div>

          <div className="bg-white rounded-2xl shadow-lg ring-1 ring-black/5 overflow-hidden hc-card">
            <table className="min-w-full text-sm">
              <thead className="bg-gray-50/80">
                <tr>
                  <th className="text-left p-3 font-semibold text-gray-700">Perfil</th>
                  <th className="text-left p-3 font-semibold text-gray-700">Nombre</th>
                  <th className="text-left p-3 font-semibold text-gray-700">País</th>
                  <th className="text-left p-3 font-semibold text-gray-700">Destacado</th>
                  <th className="text-left p-3 font-semibold text-gray-700">Acciones</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {filtered.map((a) => (
                  <tr key={a.id} className="bg-white hover:bg-gray-50 transition-colors">
                    <td className="p-3">
                      {a.profilePhotoUrl ? (
                        <img src={a.profilePhotoUrl} alt={a.name} className="h-10 w-10 rounded-full object-cover" />
                      ) : (
                        <div className="h-10 w-10 rounded-full bg-gray-200 ring-1 ring-inset ring-gray-300 hc-ring" />
                      )}
                    </td>
                    <td className="p-3">{a.name}</td>
                    <td className="p-3">{flagEmoji(a.nationalityCode)}</td>
                    <td className="p-3">
                      <button
                        onClick={() => toggleFeatured(a)}
                        className={`px-2 py-1 rounded-md ${a.featured ? 'bg-yellow-200 text-yellow-800' : 'bg-gray-100 text-gray-600'}`}
                      >
                        {a.featured ? 'Sí' : 'No'}
                      </button>
                    </td>
                    <td className="p-3">
                      <Link href={`/dashboard/artists/${a.id}/edit`} className="px-2 py-1 rounded-md border">
                        Editar
                      </Link>
                    </td>
                  </tr>
                ))}
                {filtered.length === 0 && (
                  <tr>
                    <td colSpan={5} className="p-6 text-center text-gray-500">Sin resultados</td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
    </div>
  );
}


