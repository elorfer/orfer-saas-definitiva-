'use client';

import { Suspense, useEffect, useMemo, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { toast } from 'react-hot-toast';
import {
    EyeIcon,
    EyeSlashIcon,
    ShieldCheckIcon,
    CheckCircleIcon,
} from '@heroicons/react/24/outline';

function ResetPasswordContent() {
    const [password, setPassword] = useState('');
    const [confirmPassword, setConfirmPassword] = useState('');
    const [showPassword, setShowPassword] = useState(false);
    const [showConfirmPassword, setShowConfirmPassword] = useState(false);
    const [isLoading, setIsLoading] = useState(false);
    const [isSuccess, setIsSuccess] = useState(false);
    const router = useRouter();
    const searchParams = useSearchParams();
    const token = searchParams.get('token');

    const currentYear = useMemo(() => new Date().getFullYear(), []);

    useEffect(() => {
        if (!token) {
            toast.error('Token de recuperación no válido');
            setTimeout(() => router.push('/login'), 2000);
        }
    }, [token, router]);

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();

        if (password !== confirmPassword) {
            toast.error('Las contraseñas no coinciden');
            return;
        }

        if (password.length < 6) {
            toast.error('La contraseña debe tener al menos 6 caracteres');
            return;
        }

        setIsLoading(true);

        try {
            const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001';
            const response = await fetch(`${apiUrl}/api/v1/auth/reset-password`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    token,
                    newPassword: password,
                }),
            });

            const data = await response.json();

            if (!response.ok) {
                throw new Error(data.message || 'Error al restablecer la contraseña');
            }

            toast.success('Contraseña restablecida correctamente');
            setIsSuccess(true);

            setTimeout(() => {
                router.push('/login');
            }, 3000);
        } catch (error) {
            console.error('Error resetting password:', error);
            toast.error(error instanceof Error ? error.message : 'Error al restablecer la contraseña');
            setIsLoading(false);
        }
    };

    if (isSuccess) {
        return (
            <div className='relative min-h-screen overflow-hidden bg-gradient-to-br from-green-800 via-green-700 to-green-900 flex items-center justify-center px-4 py-10'>
                <div className='absolute -top-32 -left-32 h-72 w-72 rounded-full bg-white/10 blur-3xl' />
                <div className='absolute -bottom-40 right-0 h-80 w-80 rounded-full bg-white/10 blur-3xl' />
                <div className='absolute inset-0 bg-[radial-gradient(circle_at_top,_rgba(255,255,255,0.18),_transparent_60%)]' />

                <div className='relative z-10 w-full max-w-lg'>
                    <div className='rounded-3xl border border-white/20 bg-white/90 px-8 py-10 shadow-2xl backdrop-blur-xl sm:px-12 sm:py-12'>
                        <div className='text-center'>
                            <div className='mx-auto mb-6 flex h-28 w-28 items-center justify-center rounded-2xl bg-gradient-to-br from-green-600 to-green-700 shadow-lg shadow-green-700/40'>
                                <CheckCircleIcon className='h-20 w-20 text-white' />
                            </div>
                            <h1 className='text-3xl font-black text-gray-900 sm:text-4xl'>¡Contraseña Restablecida!</h1>
                            <p className='mt-4 text-base font-medium text-gray-600'>
                                Tu contraseña ha sido actualizada correctamente.
                            </p>
                            <p className='mt-2 text-sm text-gray-500'>
                                Serás redirigido al login en unos segundos...
                            </p>
                            <button
                                onClick={() => router.push('/login')}
                                className='mt-6 inline-flex items-center gap-2 rounded-xl bg-gradient-to-r from-green-600 to-green-700 px-6 py-3 text-sm font-semibold text-white shadow-lg shadow-green-700/25 transition hover:shadow-xl focus:outline-none focus:ring-2 focus:ring-green-200'
                            >
                                Ir al Login
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        );
    }

    return (
        <div className='relative min-h-screen overflow-hidden bg-gradient-to-br from-brown-800 via-brown-700 to-brown-900 flex items-center justify-center px-4 py-10'>
            <div className='absolute -top-32 -left-32 h-72 w-72 rounded-full bg-white/10 blur-3xl' />
            <div className='absolute -bottom-40 right-0 h-80 w-80 rounded-full bg-white/10 blur-3xl' />
            <div className='absolute inset-0 bg-[radial-gradient(circle_at_top,_rgba(255,255,255,0.18),_transparent_60%)]' />

            <div className='relative z-10 w-full max-w-lg'>
                <div className='rounded-3xl border border-white/20 bg-white/90 px-8 py-10 shadow-2xl backdrop-blur-xl sm:px-12 sm:py-12'>
                    <div className='mb-10 text-center'>
                        <div className='mx-auto mb-6 flex h-28 w-28 items-center justify-center rounded-2xl bg-gradient-to-br from-brown-700 to-brown-800 shadow-lg shadow-brown-700/40'>
                            <img
                                src="/logo-icon.png"
                                alt="Logo"
                                className="h-24 w-24 object-contain"
                                onError={(e) => {
                                    console.error('Error cargando logo-icon.png');
                                    e.currentTarget.style.display = 'none';
                                }}
                            />
                        </div>
                        <h1 className='text-3xl font-black text-gray-900 sm:text-4xl'>Restablecer Contraseña</h1>
                        <p className='mt-2 text-base font-medium text-gray-500'>Ingresa tu nueva contraseña</p>
                    </div>

                    <form onSubmit={handleSubmit} className='space-y-6'>
                        <div className='space-y-2'>
                            <label className='block text-sm font-semibold text-gray-700' htmlFor='password'>
                                Nueva Contraseña
                            </label>
                            <div className='relative'>
                                <input
                                    id='password'
                                    type={showPassword ? 'text' : 'password'}
                                    value={password}
                                    onChange={(e) => setPassword(e.target.value)}
                                    placeholder='••••••••'
                                    className='w-full rounded-xl border border-gray-200 bg-white/85 px-4 py-3 text-sm font-medium text-gray-900 shadow-sm transition focus:border-brown-700 focus:outline-none focus:ring-2 focus:ring-brown-200'
                                    autoComplete='new-password'
                                    required
                                    minLength={6}
                                />
                                <button
                                    type='button'
                                    onClick={() => setShowPassword(!showPassword)}
                                    className='absolute inset-y-0 right-3 flex items-center text-gray-400 transition hover:text-brown-700'
                                >
                                    {showPassword ? <EyeSlashIcon className='h-5 w-5' /> : <EyeIcon className='h-5 w-5' />}
                                </button>
                            </div>
                            <p className='text-xs text-gray-500'>Mínimo 6 caracteres</p>
                        </div>

                        <div className='space-y-2'>
                            <label className='block text-sm font-semibold text-gray-700' htmlFor='confirmPassword'>
                                Confirmar Contraseña
                            </label>
                            <div className='relative'>
                                <input
                                    id='confirmPassword'
                                    type={showConfirmPassword ? 'text' : 'password'}
                                    value={confirmPassword}
                                    onChange={(e) => setConfirmPassword(e.target.value)}
                                    placeholder='••••••••'
                                    className='w-full rounded-xl border border-gray-200 bg-white/85 px-4 py-3 text-sm font-medium text-gray-900 shadow-sm transition focus:border-brown-700 focus:outline-none focus:ring-2 focus:ring-brown-200'
                                    autoComplete='new-password'
                                    required
                                    minLength={6}
                                />
                                <button
                                    type='button'
                                    onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                                    className='absolute inset-y-0 right-3 flex items-center text-gray-400 transition hover:text-brown-700'
                                >
                                    {showConfirmPassword ? <EyeSlashIcon className='h-5 w-5' /> : <EyeIcon className='h-5 w-5' />}
                                </button>
                            </div>
                        </div>

                        <button
                            type='submit'
                            className='flex w-full items-center justify-center gap-2 rounded-xl bg-gradient-to-r from-brown-700 via-brown-800 to-brown-900 px-4 py-3 text-sm font-semibold text-white shadow-lg shadow-brown-700/25 transition hover:shadow-xl focus:outline-none focus:ring-2 focus:ring-brown-200 disabled:cursor-not-allowed disabled:opacity-70'
                            disabled={isLoading}
                        >
                            <ShieldCheckIcon className='h-5 w-5' />
                            {isLoading ? 'Restableciendo...' : 'Restablecer Contraseña'}
                        </button>
                    </form>

                    <div className='mt-8 text-center text-sm text-gray-500'>
                        <button
                            onClick={() => router.push('/login')}
                            className='text-brown-700 hover:text-brown-800 font-semibold transition'
                        >
                            ← Volver al Login
                        </button>
                        <p className='mt-3 text-xs text-gray-400'>© {currentYear} Vintage Music. Todos los derechos reservados.</p>
                    </div>
                </div>
            </div>
        </div>
    );
}

export default function ResetPasswordPage() {
    return (
        <Suspense fallback={<div className='flex min-h-screen items-center justify-center text-white'>Cargando...</div>}>
            <ResetPasswordContent />
        </Suspense>
    );
}
