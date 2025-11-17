'use client';

import React, { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { apiClient } from '@/lib/api';
import {
  HomeIcon,
  UsersIcon,
  MusicalNoteIcon,
  ShieldCheckIcon,
  StarIcon,
  ListBulletIcon,
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
  const pts = Array.from(cc).map(c => 127397 + c.charCodeAt(0));
  return String.fromCodePoint(...pts);
};

export default function ArtistsPage() {
  const [items, setItems] = useState<ArtistLite[]>([]);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(false);

  const navItems = [
    { name: 'Dashboard', href: '/dashboard', icon: HomeIcon },
    { name: 'Administrar usuarios', href: '/dashboard/users', icon: UsersIcon },
    { name: 'Gestionar canciones', href: '/dashboard/songs', icon: MusicalNoteIcon },
    { name: 'Artistas', href: '/dashboard/artists', icon: UsersIcon },
    { name: 'Administrar Playlists', href: '/dashboard/playlists', icon: ListBulletIcon },
    { name: 'Contenido destacado', href: '/dashboard/featured', icon: StarIcon },
    { name: 'Aprobar contenido', href: '/dashboard/approvals', icon: ShieldCheckIcon },
  ];

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
    <div className="min-h-screen bg-gray-50 flex">
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
            const isActive = item.href === '/dashboard/artists';
            const Icon = item.icon as any;
            return (
              <Link
                key={item.href}
                href={item.href}
                className={`flex items-center w-full gap-3 rounded-xl px-3 py-2 text-sm font-medium transition ${
                  isActive ? 'bg-purple-100 text-purple-700' : 'text-gray-600 hover:bg-gray-100 hover:text-gray-900'
                }`}
              >
                <Icon className="h-5 w-5" />
                <span className="hidden xl:inline">{item.name}</span>
              </Link>
            );
          })}
        </nav>
      </aside>

      <div className="flex-1 flex flex-col">
        <header className="bg-white/95 backdrop-blur border-b border-gray-200 shadow-md">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
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
          </div>
        </header>

        <main className="flex-1 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6 space-y-6">
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
        </main>
      </div>
    </div>
  );
}


