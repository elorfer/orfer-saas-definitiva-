'use client';

import { useState, useMemo, useRef, useEffect } from 'react';
import { MagnifyingGlassIcon, ChevronDownIcon, CheckIcon, XMarkIcon } from '@heroicons/react/24/outline';
import type { ArtistModel } from '@/types/artist';

interface ArtistSelectorProps {
  artists: ArtistModel[];
  value: string;
  onChange: (artistId: string) => void;
  disabled?: boolean;
  isLoading?: boolean;
  required?: boolean;
}

export default function ArtistSelector({
  artists,
  value,
  onChange,
  disabled = false,
  isLoading = false,
  required = false,
}: ArtistSelectorProps) {
  const [isOpen, setIsOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const dropdownRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  // Cerrar dropdown al hacer click fuera
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setIsOpen(false);
        setSearchQuery('');
      }
    };

    if (isOpen) {
      document.addEventListener('mousedown', handleClickOutside);
    }

    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, [isOpen]);

  // Filtrar artistas basado en la búsqueda
  const filteredArtists = useMemo(() => {
    if (!searchQuery.trim()) {
      return artists;
    }

    const query = searchQuery.toLowerCase();
    return artists.filter((artist) => {
      const stageName = artist.stageName?.toLowerCase() || '';
      const email = artist.user?.email?.toLowerCase() || '';
      const username = artist.user?.username?.toLowerCase() || '';
      const fullName = `${artist.user?.firstName || ''} ${artist.user?.lastName || ''}`.toLowerCase().trim();

      return (
        stageName.includes(query) ||
        email.includes(query) ||
        username.includes(query) ||
        fullName.includes(query)
      );
    });
  }, [artists, searchQuery]);

  // Obtener el artista seleccionado
  const selectedArtist = useMemo(() => {
    return artists.find((artist) => artist.id === value);
  }, [artists, value]);

  // Obtener texto a mostrar
  const displayText = useMemo(() => {
    if (!selectedArtist) {
      return 'Selecciona un artista';
    }

    if (selectedArtist.stageName) {
      return selectedArtist.stageName;
    }

    if (selectedArtist.user?.email) {
      return selectedArtist.user.email;
    }

    return `Artista ${selectedArtist.id.substring(0, 8)}`;
  }, [selectedArtist]);

  const handleSelect = (artistId: string) => {
    onChange(artistId);
    setIsOpen(false);
    setSearchQuery('');
  };

  const handleClear = (e: React.MouseEvent) => {
    e.stopPropagation();
    onChange('');
    setSearchQuery('');
  };

  return (
    <div className="relative" ref={dropdownRef}>
      <label className="block text-xs font-semibold uppercase tracking-wide text-gray-500 mb-1">
        Artista {required && <span className="text-red-500">*</span>}
      </label>
      
      <div className="relative">
        <button
          type="button"
          onClick={() => !disabled && !isLoading && setIsOpen(!isOpen)}
          disabled={disabled || isLoading}
          className={`w-full rounded-lg border ${
            disabled || isLoading
              ? 'border-gray-200 bg-gray-50 cursor-not-allowed'
              : isOpen
              ? 'border-purple-500 ring-2 ring-purple-100'
              : 'border-gray-200 hover:border-purple-300'
          } bg-white px-3 py-2 text-sm text-left transition focus:outline-none focus:ring-2 focus:ring-purple-100`}
        >
          <div className="flex items-center justify-between">
            <span className={selectedArtist ? 'text-gray-900' : 'text-gray-500'}>
              {isLoading ? 'Cargando artistas...' : displayText}
            </span>
            <div className="flex items-center gap-2">
              {selectedArtist && !disabled && !isLoading && (
                <button
                  type="button"
                  onClick={handleClear}
                  className="rounded p-0.5 text-gray-400 hover:text-red-600 hover:bg-red-50 transition"
                  aria-label="Limpiar selección"
                >
                  <XMarkIcon className="h-4 w-4" />
                </button>
              )}
              <ChevronDownIcon
                className={`h-4 w-4 text-gray-400 transition-transform ${isOpen ? 'rotate-180' : ''}`}
              />
            </div>
          </div>
        </button>

        {isOpen && !disabled && !isLoading && (
          <div className="absolute z-50 mt-1 w-full rounded-lg border border-gray-200 bg-white shadow-lg max-h-80 overflow-hidden">
            {/* Barra de búsqueda */}
            <div className="p-2 border-b border-gray-200">
              <div className="relative">
                <MagnifyingGlassIcon className="h-4 w-4 text-gray-400 absolute left-3 top-1/2 -translate-y-1/2" />
                <input
                  ref={inputRef}
                  type="text"
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  placeholder="Buscar artista por nombre, email..."
                  className="w-full rounded-lg border border-gray-200 bg-gray-50 pl-9 pr-3 py-2 text-sm text-gray-900 placeholder-gray-400 focus:border-purple-500 focus:outline-none focus:ring-2 focus:ring-purple-100"
                  autoFocus
                />
              </div>
            </div>

            {/* Lista de artistas */}
            <div className="max-h-64 overflow-y-auto">
              {filteredArtists.length === 0 ? (
                <div className="px-4 py-8 text-center text-sm text-gray-500">
                  {searchQuery ? (
                    <>
                      <p className="font-medium">No se encontraron artistas</p>
                      <p className="mt-1 text-xs">Intenta con otro término de búsqueda</p>
                    </>
                  ) : (
                    <>
                      <p className="font-medium">No hay artistas disponibles</p>
                      <p className="mt-1 text-xs">Crea un artista primero desde la sección de Artistas</p>
                    </>
                  )}
                </div>
              ) : (
                <div className="py-1">
                  {filteredArtists.map((artist) => {
                    const isSelected = artist.id === value;
                    const displayName =
                      artist.stageName ||
                      artist.user?.email ||
                      artist.user?.username ||
                      `Artista ${artist.id.substring(0, 8)}`;

                    return (
                      <button
                        key={artist.id}
                        type="button"
                        onClick={() => handleSelect(artist.id)}
                        className={`w-full px-4 py-2.5 text-left text-sm transition ${
                          isSelected
                            ? 'bg-purple-50 text-purple-700'
                            : 'text-gray-900 hover:bg-gray-50'
                        }`}
                      >
                        <div className="flex items-center justify-between">
                          <div className="flex-1 min-w-0">
                            <div className="flex items-center gap-2">
                              {isSelected && (
                                <CheckIcon className="h-4 w-4 text-purple-600 flex-shrink-0" />
                              )}
                              <span className="font-medium truncate">{displayName}</span>
                            </div>
                            {artist.user?.email && artist.stageName && (
                              <p className="text-xs text-gray-500 truncate mt-0.5">
                                {artist.user.email}
                              </p>
                            )}
                          </div>
                        </div>
                      </button>
                    );
                  })}
                </div>
              )}
            </div>

            {/* Footer con contador */}
            {filteredArtists.length > 0 && (
              <div className="px-4 py-2 border-t border-gray-200 bg-gray-50">
                <p className="text-xs text-gray-500 text-center">
                  {filteredArtists.length} {filteredArtists.length === 1 ? 'artista' : 'artistas'}
                  {searchQuery && ` encontrado${filteredArtists.length === 1 ? '' : 's'}`}
                </p>
              </div>
            )}
          </div>
        )}
      </div>

      {artists.length === 0 && !isLoading && (
        <p className="mt-1 text-xs text-gray-500">
          No hay artistas disponibles. Crea un artista desde la sección de Artistas.
        </p>
      )}
    </div>
  );
}



