'use client';

import React, { useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';
import Image from 'next/image';
import { toast } from 'react-hot-toast';
import { apiClient } from '@/lib/api';
import { useGenres } from '@/hooks/useGenres';

const countries: { code: string; name: string; flag: string }[] = [
  { code: 'AR', name: 'Argentina', flag: '🇦🇷' },
  { code: 'BO', name: 'Bolivia', flag: '🇧🇴' },
  { code: 'BR', name: 'Brasil', flag: '🇧🇷' },
  { code: 'CL', name: 'Chile', flag: '🇨🇱' },
  { code: 'CO', name: 'Colombia', flag: '🇨🇴' },
  { code: 'CR', name: 'Costa Rica', flag: '🇨🇷' },
  { code: 'CU', name: 'Cuba', flag: '🇨🇺' },
  { code: 'DO', name: 'República Dominicana', flag: '🇩🇴' },
  { code: 'EC', name: 'Ecuador', flag: '🇪🇨' },
  { code: 'ES', name: 'España', flag: '🇪🇸' },
  { code: 'GT', name: 'Guatemala', flag: '🇬🇹' },
  { code: 'HN', name: 'Honduras', flag: '🇭🇳' },
  { code: 'MX', name: 'México', flag: '🇲🇽' },
  { code: 'NI', name: 'Nicaragua', flag: '🇳🇮' },
  { code: 'PA', name: 'Panamá', flag: '🇵🇦' },
  { code: 'PE', name: 'Perú', flag: '🇵🇪' },
  { code: 'PY', name: 'Paraguay', flag: '🇵🇾' },
  { code: 'UY', name: 'Uruguay', flag: '🇺🇾' },
  { code: 'VE', name: 'Venezuela', flag: '🇻🇪' },
];

export default function CreateArtistPage() {
  const router = useRouter();
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [phone, setPhone] = useState('');
  const [nationality, setNationality] = useState<string>('');
  const [biography, setBiography] = useState('');
  const [profile, setProfile] = useState<File | null>(null);
  const [cover, setCover] = useState<File | null>(null);
  const [loading, setLoading] = useState(false);
  const [errors, setErrors] = useState<{ name?: string; email?: string; password?: string; phone?: string; genres?: string }>({});
  const [linkedUserId, setLinkedUserId] = useState<string | null>(null);
  const [selectedGenres, setSelectedGenres] = useState<string[]>([]);
  
  // Obtener géneros disponibles
  const { data: genresData, isLoading: genresLoading } = useGenres({ all: true, limit: 100 });
  const availableGenres = genresData?.genres || [];

  const selectedCountry = useMemo(
    () => countries.find((c) => c.code === nationality),
    [nationality],
  );

  const validateEmailFormat = (value: string) => {
    if (!value) return undefined;
    const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/i;
    return re.test(value) ? undefined : 'Correo inválido';
  };
  const validatePassword = (value: string) => {
    if (!value) return 'La contraseña es requerida';
    if (value.length < 8) return 'Mínimo 8 caracteres';
    return undefined;
  };
  const validatePhone = (value: string) => {
    if (!value) return 'El teléfono es requerido';
    const re = /^[0-9+()\-\s]{7,20}$/;
    return re.test(value) ? undefined : 'Teléfono inválido';
  };

  const checkArtistNameAvailability = async (value: string) => {
    if (!value || value.trim().length < 2) {
      return 'Nombre muy corto';
    }
    try {
      // Traer muchos artistas y verificar duplicado (case-insensitive)
      const res = await apiClient.getArtists(1, 1000);
      const list = res.data?.artists ?? res.data ?? [];
      const exists = list.some((a: any) => (a.stageName || a.name || '').trim().toLowerCase() === value.trim().toLowerCase());
      return exists ? 'El nombre artístico ya existe' : undefined;
    } catch {
      // En caso de error de red no bloqueamos el envío
      return undefined;
    }
  };

  const tryLinkUserByEmail = async (value: string) => {
    setLinkedUserId(null);
    if (!value) return;
    try {
      const res = await apiClient.getUsers(1, 1000);
      const users = res.data?.users ?? res.data ?? [];
      const user = users.find((u: any) => (u.email || '').toLowerCase() === value.toLowerCase());
      setLinkedUserId(user?.id || null);
    } catch {
      // ignorar
      setLinkedUserId(null);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const nameErr = await checkArtistNameAvailability(name);
      const emailErr = validateEmailFormat(email);
      const passErr = validatePassword(password);
      const phoneErr = validatePhone(phone);
      const genresErr = selectedGenres.length === 0 ? 'Debe seleccionar al menos un género' : undefined;
      setErrors({ name: nameErr, email: emailErr, password: passErr, phone: phoneErr, genres: genresErr });
      if (nameErr || emailErr || passErr || phoneErr || genresErr) {
        toast.error('Corrige los errores del formulario');
        return;
      }
      setLoading(true);

      await tryLinkUserByEmail(email);

      // Si no existe usuario, registrarlo con rol artist
      if (!linkedUserId) {
        const usernameBase = name?.trim().toLowerCase().replace(/\s+/g, '.') || email.split('@')[0];
        const username = usernameBase.slice(0, 30);
        try {
          await apiClient.createUser({
            email,
            username,
            password,
            firstName: name.split(' ')[0] || 'Artist',
            lastName: name.split(' ').slice(1).join(' ') || 'Account',
            role: 'artist',
          });
        } catch (regErr: any) {
          // Si ya existe el email, simplemente buscamos el userId
          await tryLinkUserByEmail(email);
        }
        // reforzar búsqueda
        await tryLinkUserByEmail(email);
      }

      await apiClient.createArtist({
        name,
        nationalityCode: nationality || undefined,
        biography: [biography || '', phone ? `Tel: ${phone}` : ''].filter(Boolean).join('\n'),
        featured: false,
        genres: selectedGenres,
        profileFile: profile,
        coverFile: cover,
        userId: linkedUserId || undefined,
      });
      toast.success('Artista creado');
      router.push('/dashboard/artists');
      router.refresh();
    } catch (err: any) {
      const msg = err?.response?.data?.message || err?.message || 'Error al crear artista';
      console.error('createArtist error:', err);
      toast.error(typeof msg === 'string' ? msg : JSON.stringify(msg));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="p-6">
      <div className="max-w-4xl mx-auto">
        <div className="mb-6">
          <h1 className="text-2xl font-bold text-gray-900">Crear Artista</h1>
          <p className="text-sm text-gray-500">Completa la información y sube las imágenes.</p>
        </div>

        <form onSubmit={handleSubmit} className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="lg:col-span-2 space-y-4 bg-white border border-gray-200 rounded-2xl p-6 shadow-sm">
            <div>
              <label className="block text-sm font-medium text-gray-700">Nombre artístico</label>
              <input
                className="mt-1 w-full rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-sm focus:border-brown-700 focus:ring-brown-100"
                value={name}
                onChange={(e) => setName(e.target.value)}
                onBlur={async () => {
                  const err = await checkArtistNameAvailability(name);
                  setErrors((prev) => ({ ...prev, name: err }));
                }}
                required
              />
              {errors.name && <p className="mt-1 text-xs text-red-600">{errors.name}</p>}
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700">Correo del artista (opcional)</label>
              <input
                className="mt-1 w-full rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-sm focus:border-brown-700 focus:ring-brown-100"
                value={email}
                onChange={(e) => {
                  setEmail(e.target.value);
                  const err = validateEmailFormat(e.target.value);
                  setErrors((prev) => ({ ...prev, email: err }));
                }}
                onBlur={() => {
                  const err = validateEmailFormat(email);
                  setErrors((prev) => ({ ...prev, email: err }));
                  if (!err && email) {
                    tryLinkUserByEmail(email);
                  }
                }}
                placeholder="correo@dominio.com"
                type="email"
              />
              {errors.email ? (
                <p className="mt-1 text-xs text-red-600">{errors.email}</p>
              ) : email ? (
                <p className="mt-1 text-xs text-gray-500">
                  {linkedUserId ? 'Se asociará al usuario existente con este correo.' : 'No existe un usuario con este correo. Puedes crearlo luego y asociarlo.'}
                </p>
              ) : null}
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700">Contraseña</label>
                <input
                  className="mt-1 w-full rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-sm focus:border-brown-700 focus:ring-brown-100"
                  type="password"
                  value={password}
                  onChange={(e) => {
                    setPassword(e.target.value);
                    setErrors((prev) => ({ ...prev, password: validatePassword(e.target.value) }));
                  }}
                  onBlur={() => setErrors((prev) => ({ ...prev, password: validatePassword(password) }))}
                  placeholder="Mínimo 8 caracteres"
                  required
                />
                {errors.password && <p className="mt-1 text-xs text-red-600">{errors.password}</p>}
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700">Teléfono</label>
                <input
                  className="mt-1 w-full rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-sm focus:border-brown-700 focus:ring-brown-100"
                  value={phone}
                  onChange={(e) => {
                    setPhone(e.target.value);
                    setErrors((prev) => ({ ...prev, phone: validatePhone(e.target.value) }));
                  }}
                  onBlur={() => setErrors((prev) => ({ ...prev, phone: validatePhone(phone) }))}
                  placeholder="+57 300 123 4567"
                  required
                />
                {errors.phone && <p className="mt-1 text-xs text-red-600">{errors.phone}</p>}
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700">Nacionalidad</label>
              <div className="mt-1 flex items-center gap-2">
                <select
                  className="w-full rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-sm focus:border-brown-700 focus:ring-brown-100"
                  value={nationality}
                  onChange={(e) => setNationality(e.target.value)}
                >
                  <option value="">Seleccionar...</option>
                  {countries.map((c) => (
                    <option key={c.code} value={c.code}>
                      {c.flag} {c.name}
                    </option>
                  ))}
                </select>
                <span className="text-xl">{selectedCountry?.flag ?? '🏳️'}</span>
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700">
                Géneros <span className="text-red-500">*</span>
              </label>
              {genresLoading ? (
                <div className="mt-1 text-sm text-gray-500">Cargando géneros...</div>
              ) : (
                <div className="mt-1 space-y-2">
                  <div className="flex flex-wrap gap-2">
                    {availableGenres.map((genre) => (
                      <label
                        key={genre.id}
                        className={`inline-flex items-center px-3 py-1.5 rounded-lg border text-sm cursor-pointer transition ${
                          selectedGenres.includes(genre.name)
                            ? 'bg-brown-100 border-brown-500 text-brown-700'
                            : 'bg-white border-gray-200 text-gray-700 hover:border-brown-300'
                        }`}
                      >
                        <input
                          type="checkbox"
                          className="sr-only"
                          checked={selectedGenres.includes(genre.name)}
                          onChange={(e) => {
                            if (e.target.checked) {
                              setSelectedGenres([...selectedGenres, genre.name]);
                            } else {
                              setSelectedGenres(selectedGenres.filter((g) => g !== genre.name));
                            }
                            setErrors((prev) => ({ ...prev, genres: undefined }));
                          }}
                        />
                        <span>{genre.name}</span>
                      </label>
                    ))}
                  </div>
                  {errors.genres && <p className="text-xs text-red-600">{errors.genres}</p>}
                  {selectedGenres.length === 0 && (
                    <p className="text-xs text-gray-500">Selecciona al menos un género</p>
                  )}
                </div>
              )}
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700">Biografía</label>
              <textarea
                className="mt-1 w-full rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-sm focus:border-brown-700 focus:ring-brown-100"
                rows={6}
                value={biography}
                onChange={(e) => setBiography(e.target.value)}
                placeholder="Cuenta la historia del artista..."
              />
            </div>

            <div className="pt-2">
              <button
                disabled={loading}
                className="inline-flex items-center gap-2 rounded-lg bg-brown-700 px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-brown-800 disabled:opacity-50"
              >
                {loading ? 'Guardando...' : 'Crear'}
              </button>
            </div>
          </div>

          <div className="space-y-4">
            <div className="bg-white border border-gray-200 rounded-2xl p-4 shadow-sm">
              <label className="block text-sm font-medium text-gray-700 mb-2">Foto de perfil</label>
              <div className="aspect-square rounded-xl bg-gray-50 border border-dashed border-gray-300 flex items-center justify-center overflow-hidden mb-3">
                {profile ? (
                  <img
                    src={URL.createObjectURL(profile)}
                    alt="preview perfil"
                    className="h-full w-full object-cover"
                  />
                ) : (
                  <span className="text-gray-400 text-sm">Sin imagen</span>
                )}
              </div>
              <input type="file" accept="image/*" onChange={(e) => setProfile(e.target.files?.[0] || null)} />
            </div>

            <div className="bg-white border border-gray-200 rounded-2xl p-4 shadow-sm">
              <label className="block text-sm font-medium text-gray-700 mb-2">Portada</label>
              <div className="aspect-[16/9] rounded-xl bg-gray-50 border border-dashed border-gray-300 flex items-center justify-center overflow-hidden mb-3">
                {cover ? (
                  <img
                    src={URL.createObjectURL(cover)}
                    alt="preview portada"
                    className="h-full w-full object-cover"
                  />
                ) : (
                  <span className="text-gray-400 text-sm">Sin imagen</span>
                )}
              </div>
              <input type="file" accept="image/*" onChange={(e) => setCover(e.target.files?.[0] || null)} />
            </div>
          </div>
        </form>
      </div>
    </div>
  );
}


