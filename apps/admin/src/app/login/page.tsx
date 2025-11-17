'use client';

import { Suspense, useEffect, useMemo, useState } from 'react';
import { signIn, useSession } from 'next-auth/react';
import { useRouter, useSearchParams } from 'next/navigation';
import { toast } from 'react-hot-toast';
import {
  MusicalNoteIcon,
  EyeIcon,
  EyeSlashIcon,
  ShieldCheckIcon,
} from '@heroicons/react/24/outline';

function LoginContent() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const router = useRouter();
  const searchParams = useSearchParams();
  const { data: session, status } = useSession();

  useEffect(() => {
    if (status === 'authenticated' && session) {
      router.push('/dashboard');
      return;
    }

    const error = searchParams.get('error');
    if (error === 'Configuration') {
      toast.error('Error de configuración. Verifica NEXTAUTH_SECRET y NEXTAUTH_URL');
      console.error('Error de configuración de NextAuth. Verifica las variables de entorno.');
    }
  }, [session, status, router, searchParams]);

  const currentYear = useMemo(() => new Date().getFullYear(), []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);

    try {
      const result = await signIn('credentials', {
        email,
        password,
        redirect: false,
        callbackUrl: '/dashboard',
      });

      if (result?.error) {
        if (result.error === 'Configuration') {
          toast.error('Error de configuración. Verifica las variables de entorno.');
          console.error('Error de configuración de NextAuth. Verifica NEXTAUTH_SECRET y NEXTAUTH_URL');
        } else if (result.error === 'CredentialsSignin') {
          toast.error('Credenciales inválidas');
        } else {
          toast.error(`Error: ${result.error}`);
        }
        setIsLoading(false);
        return;
      }

      if (result?.ok || result?.url) {
        toast.success('Inicio de sesión exitoso');
        await new Promise((resolve) => setTimeout(resolve, 500));

        try {
          const sessionResponse = await fetch('/api/auth/session');
          const sessionData = await sessionResponse.json();

          if (sessionData && sessionData.user) {
            window.location.href = '/dashboard';
          } else {
            toast.error('Error: No se pudo establecer la sesión');
            setIsLoading(false);
          }
        } catch (sessionError) {
          console.error('[Login] Error al verificar sesión:', sessionError);
          window.location.href = '/dashboard';
        }
      } else {
        toast.error('Error al iniciar sesión');
        setIsLoading(false);
      }
    } catch (error) {
      console.error('Error en login:', error);
      toast.error('Error al iniciar sesión');
      setIsLoading(false);
    }
  };

  return (
    <div className='relative min-h-screen overflow-hidden bg-gradient-to-br from-indigo-600 via-purple-600 to-purple-800 flex items-center justify-center px-4 py-10'>
      <div className='absolute -top-32 -left-32 h-72 w-72 rounded-full bg-white/10 blur-3xl' />
      <div className='absolute -bottom-40 right-0 h-80 w-80 rounded-full bg-white/10 blur-3xl' />
      <div className='absolute inset-0 bg-[radial-gradient(circle_at_top,_rgba(255,255,255,0.18),_transparent_60%)]' />

      <div className='relative z-10 w-full max-w-lg'>
        <div className='rounded-3xl border border-white/20 bg-white/90 px-8 py-10 shadow-2xl backdrop-blur-xl sm:px-12 sm:py-12'>
          <div className='mb-10 text-center'>
            <div className='mx-auto mb-6 flex h-20 w-20 items-center justify-center rounded-2xl bg-gradient-to-br from-purple-500 to-purple-700 shadow-lg shadow-purple-600/40'>
              <MusicalNoteIcon className='h-10 w-10 text-white' />
            </div>
            <h1 className='text-3xl font-black text-gray-900 sm:text-4xl'>Vintage Music</h1>
            <p className='mt-2 text-base font-medium text-gray-500'>Panel de Administración</p>
          </div>

          <form onSubmit={handleSubmit} className='space-y-6'>
            <div className='space-y-2'>
              <label className='block text-sm font-semibold text-gray-700' htmlFor='email'>
                Correo electrónico
              </label>
              <div className='relative'>
                <input
                  id='email'
                  type='email'
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder='admin@vintagemusic.com'
                  className='w-full rounded-xl border border-gray-200 bg-white/85 px-4 py-3 text-sm font-medium text-gray-900 shadow-sm transition focus:border-purple-500 focus:outline-none focus:ring-2 focus:ring-purple-200'
                  autoComplete='username'
                  required
                />
              </div>
            </div>

            <div className='space-y-2'>
              <label className='block text-sm font-semibold text-gray-700' htmlFor='password'>
                Contraseña
              </label>
              <div className='relative'>
                <input
                  id='password'
                  type={showPassword ? 'text' : 'password'}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder='••••••••'
                  className='w-full rounded-xl border border-gray-200 bg-white/85 px-4 py-3 text-sm font-medium text-gray-900 shadow-sm transition focus:border-purple-500 focus:outline-none focus:ring-2 focus:ring-purple-200'
                  autoComplete='current-password'
                  required
                />
                <button
                  type='button'
                  onClick={() => setShowPassword(!showPassword)}
                  className='absolute inset-y-0 right-3 flex items-center text-gray-400 transition hover:text-purple-500'
                >
                  {showPassword ? <EyeSlashIcon className='h-5 w-5' /> : <EyeIcon className='h-5 w-5' />}
                </button>
              </div>
            </div>

            <button
              type='submit'
              className='flex w-full items-center justify-center gap-2 rounded-xl bg-gradient-to-r from-purple-500 via-purple-600 to-indigo-500 px-4 py-3 text-sm font-semibold text-white shadow-lg shadow-purple-500/25 transition hover:shadow-xl focus:outline-none focus:ring-2 focus:ring-purple-200 disabled:cursor-not-allowed disabled:opacity-70'
              disabled={isLoading}
            >
              <ShieldCheckIcon className='h-5 w-5' />
              {isLoading ? 'Iniciando sesión...' : 'Acceder al Panel'}
            </button>
          </form>

          <div className='mt-8 text-center text-sm text-gray-500'>
            <p>Solo administradores autorizados</p>
            <p className='mt-3 text-xs text-gray-400'>© {currentYear} Vintage Music. Todos los derechos reservados.</p>
          </div>
        </div>
      </div>
    </div>
  );
}

export default function LoginPage() {
  return (
    <Suspense fallback={<div className='flex min-h-screen items-center justify-center text-white'>Cargando...</div>}>
      <LoginContent />
    </Suspense>
  );
}
