'use client';

import React from 'react';
import Link from 'next/link';

export default function FeaturedArtistsPage() {
  return (
    <div className="p-6">
      <div className="flex items-center justify-between mb-4">
        <h1 className="text-2xl font-bold">Artistas destacados</h1>
        <Link href="/dashboard/artists" className="px-3 py-2 rounded-md border">Volver</Link>
      </div>
      <p className="text-sm text-gray-600">Próximamente: listado de destacados desde la API.</p>
    </div>
  );
}


