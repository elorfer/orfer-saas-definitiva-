'use client';

import { Suspense, useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';
import { toast } from 'react-hot-toast';
import {
    EnvelopeIcon,
    ArrowLeftIcon,
    PaperAirplaneIcon,
} from '@heroicons/react/24/outline';

function ForgotPasswordContent() {
    const [email, setEmail] = useState('');
    const [isLoading, setIsLoading] = useState(false);
    const [emailSent, setEmailSent] = useState(false);
    const router = useRouter();

    const currentYear = useMemo(() => new Date().getFullYear(), []);

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setIsLoading(true);

        try {
            const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001';
            const response = await fetch(`${apiUrl}/api/v1/auth/forgot-password`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ email }),
            });

            const data = await response.json();

            if (!response.ok) {
                throw new Error(data.message || 'Error al enviar el email');
            }

            toast.success('Email de recuperación enviado');
            setEmailSent(true);
        } catch (error) {
            console.error('Error requesting password reset:', error);
            // Por seguridad, siempre mostramos éxito aunque el email no exista
            toast.success('Si el email existe, recibirás instrucciones para restablecer tu contraseña');
            setEmailSent(true);
        } finally {
            setIsLoading(false);
        }
    };

    if (emailSent) {
        return (
            <div className='relative min-h-screen overflow-hidden bg-gradient-to-br from-blue-800 via-blue-700 to-blue-900 flex items-center justify-center px-4 py-10'>
                <div className='absolute -top-32 -left-32 h-72 w-72 rounded-full bg-white/10 blur-3xl' />
                <div className='absolute -bottom-40 right-0 h-80 w-80 rounded-full bg-white/10 blur-3xl' />
                <div className='absolute inset-0 bg-[radial-gradient(circle_at_top,_rgba(255,255,255,0.18),_transparent_60%)]' />

                <div className='relative z-10 w-full max-w-lg'>
                    <div className='rounded-3xl border border-white/20 bg-white/90 px-8 py-10 shadow-2xl backdrop-blur-xl sm:px-12 sm:py-12'>
                        <div className='text-center'>
                            <div className='mx-auto mb-6 flex h-28 w-28 items-center justify-center rounded-2xl bg-gradient-to-br from-blue-600 to-blue-700 shadow-lg shadow-blue-700/40'>
                                <PaperAirplaneIcon className='h-20 w-20 text-white' />
                            </div>
                            <h1 className='text-3xl font-black text-gray-900 sm:text-4xl'>Email Enviado</h1>
                            <p className='mt-4 text-base font-medium text-gray-600'>
                                Si el email <strong>{email}</strong> existe en nuestro sistema, recibirás instrucciones para restablecer tu contraseña.
                            </p>
                            <p className='mt-3 text-sm text-gray-500'>
                                Revisa tu bandeja de entrada y spam.
                            </p>
                            <div className='mt-8 space-y-3'>
                                <button
                                    onClick={() => router.push('/login')}
                                    className='w-full inline-flex items-center justify-center gap-2 rounded-xl bg-gradient-to-r from-blue-600 to-blue-700 px-6 py-3 text-sm font-semibold text-white shadow-lg shadow-blue-700/25 transition hover:shadow-xl focus:outline-none focus:ring-2 focus:ring-blue-200'
                                >
                                    <ArrowLeftIcon className='h-5 w-5' />
                                    Volver al Login
                                </button>
                                <button
                                    onClick={() => {
                                        setEmailSent(false);
                                        setEmail('');
                                    }}
                                    className='w-full text-sm text-brown-700 hover:text-brown-800 font-medium transition'
                                >
                                    Intentar con otro email
                                </button>
                            </div>
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
                        <h1 className='text-3xl font-black text-gray-900 sm:text-4xl'>Recuperar Contraseña</h1>
                        <p className='mt-2 text-base font-medium text-gray-500'>
                            Ingresa tu email y te enviaremos instrucciones
                        </p>
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
                                    className='w-full rounded-xl border border-gray-200 bg-white/85 px-4 py-3 pl-11 text-sm font-medium text-gray-900 shadow-sm transition focus:border-brown-700 focus:outline-none focus:ring-2 focus:ring-brown-200'
                                    autoComplete='email'
                                    required
                                />
                                <EnvelopeIcon className='absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-gray-400' />
                            </div>
                        </div>

                        <button
                            type='submit'
                            className='flex w-full items-center justify-center gap-2 rounded-xl bg-gradient-to-r from-brown-700 via-brown-800 to-brown-900 px-4 py-3 text-sm font-semibold text-white shadow-lg shadow-brown-700/25 transition hover:shadow-xl focus:outline-none focus:ring-2 focus:ring-brown-200 disabled:cursor-not-allowed disabled:opacity-70'
                            disabled={isLoading}
                        >
                            <PaperAirplaneIcon className='h-5 w-5' />
                            {isLoading ? 'Enviando...' : 'Enviar Email de Recuperación'}
                        </button>
                    </form>

                    <div className='mt-8 text-center text-sm text-gray-500'>
                        <button
                            onClick={() => router.push('/login')}
                            className='inline-flex items-center gap-1 text-brown-700 hover:text-brown-800 font-semibold transition'
                        >
                            <ArrowLeftIcon className='h-4 w-4' />
                            Volver al Login
                        </button>
                        <p className='mt-3 text-xs text-gray-400'>© {currentYear} Vintage Music. Todos los derechos reservados.</p>
                    </div>
                </div>
            </div>
        </div>
    );
}

export default function ForgotPasswordPage() {
    return (
        <Suspense fallback={<div className='flex min-h-screen items-center justify-center text-white'>Cargando...</div>}>
            <ForgotPasswordContent />
        </Suspense>
    );
}
