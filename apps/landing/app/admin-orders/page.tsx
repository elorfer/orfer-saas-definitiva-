import Stripe from 'stripe';
import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import { TrendingUp, DollarSign, Package, Calendar } from 'lucide-react';
import ClientOrderManager from './ClientOrderManager';
import RechargeParticles from '@/components/RechargeParticles';
import { Suspense } from 'react';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY || 'sk_test_dummy', {
    apiVersion: '2026-03-25.dahlia',
});

// Forzamos a que no se cachee esta página
export const dynamic = 'force-dynamic';

export default async function AdminOrdersPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
    const cookieStore = await cookies();
    const adminPassword = process.env.ADMIN_PASSWORD;
    const isAdmin = adminPassword ? cookieStore.get('struky_admin_auth')?.value === adminPassword : false;
    
    // Debug: Verifica si la contraseña maestra está cargada
    if (!process.env.ADMIN_PASSWORD) {
        console.warn('⚠️ ALERTA: La contraseña de administrador no está configurada.');
    }

    // Si no está autenticado, mostramos un formulario de login súper simple en la misma página
    if (!isAdmin) {
        const error = (await searchParams).error;
        return (
            <div className="min-h-screen bg-[#0a0a0a] flex items-center justify-center p-4">
                <form action={async (formData) => {
                    'use server'
                    const password = formData.get('password');
                    const masterPassword = process.env.ADMIN_PASSWORD;

                    if (!masterPassword) {
                        redirect('/admin-orders?error=config');
                    }

                    if (password === masterPassword) {
                        const cookieStore = await cookies();
                        cookieStore.set('struky_admin_auth', password as string, {
                            httpOnly: true,
                            secure: process.env.NODE_ENV === 'production',
                            sameSite: 'lax',
                            maxAge: 60 * 60 * 24 // 24 horas
                        });
                        redirect('/admin-orders');
                    } else {
                        redirect('/admin-orders?error=wrong');
                    }
                }} className="glass-morphism p-8 rounded-3xl w-full max-w-md border border-white/10 shadow-2xl">
                    <div className="w-12 h-12 rounded-2xl bg-coffee-medium/20 flex items-center justify-center mx-auto mb-4 border border-coffee-medium/30">
                        <svg className="w-6 h-6 text-coffee-light" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/></svg>
                    </div>
                    <h1 className="text-2xl font-black mb-2 text-center text-white tracking-tight">Acceso Restringido</h1>
                    <p className="text-gray-500 text-[10px] text-center uppercase tracking-widest mb-8 text-pretty px-4">Ingresa la clave maestra para gestionar las producciones</p>
                    
                    {error === 'wrong' && (
                        <div className="bg-red-500/10 border border-red-500/20 text-red-400 text-[10px] font-black uppercase tracking-widest p-3 rounded-xl mb-4 text-center">
                            ❌ Contraseña Incorrecta
                        </div>
                    )}

                    {error === 'config' && (
                        <div className="bg-amber-500/10 border border-amber-500/20 text-amber-400 text-[10px] font-black uppercase tracking-widest p-3 rounded-xl mb-4 text-center">
                            ⚠️ Error: ADMIN_PASSWORD no configurada en Vercel
                        </div>
                    )}

                    <input 
                        type="password" 
                        name="password" 
                        required
                        placeholder="••••••••••••"
                        className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-4 mb-4 text-center text-white placeholder:text-gray-700 focus:border-coffee-light outline-none transition-all ring-0 focus:ring-4 focus:ring-coffee-light/10"
                    />
                    <button type="submit" className="btn-primary w-full py-4 rounded-xl text-xs font-black tracking-[0.2em]">
                        DESBLOQUEAR PANEL
                    </button>
                    
                    <p className="mt-8 text-[9px] text-gray-700 text-center uppercase tracking-widest font-bold">Struky Admin Protocol v2.5</p>
                </form>
            </div>
        );
    }

    // Si está autenticado, cargamos los pedidos de Stripe
    const sessions = await stripe.checkout.sessions.list({
        limit: 100, // Aumentamos límite para que el filtrado sea más útil
        status: 'complete',
        expand: ['data.payment_intent']
    });

    // Estadísticas
    const stats = {
        total: sessions.data.length,
        revenue: sessions.data.reduce((acc, s) => acc + ((s.amount_total || 0) / 100), 0),
        pending: sessions.data.filter(s => (s.metadata?.status || 'Pendiente') === 'Pendiente').length,
        inProgress: sessions.data.filter(s => s.metadata?.status === 'Producción').length,
        completed: sessions.data.filter(s => s.metadata?.status === 'Entregado').length,
    };

    return (
        <main className="min-h-screen bg-[#0a0a0a] text-white p-4 md:p-8">
            <div className="max-w-7xl mx-auto">
                <header className="flex flex-col md:flex-row justify-between items-start md:items-center mb-10 gap-6">
                    <div>
                        <div className="flex items-center gap-3 mb-2">
                            <div className="w-8 h-8 rounded-lg bg-coffee-medium flex items-center justify-center animate-pulse shadow-[0_0_15px_rgba(202,160,82,0.3)]">
                                <div className="w-4 h-4 bg-white rounded-sm"></div>
                            </div>
                            <h1 className="text-4xl font-black tracking-tighter text-gradient">Struky Admin</h1>
                        </div>
                        <p className="text-gray-500 text-sm">Control central de producciones musicales</p>
                    </div>
                    
                    <div className="flex flex-wrap gap-4 items-center">
                        <form action={async () => {
                            'use server'
                            const cookieStore = await cookies();
                            cookieStore.delete('struky_admin_auth');
                            redirect('/admin-orders');
                        }}>
                            <button type="submit" className="text-[9px] font-bold text-gray-600 hover:text-red-500 uppercase tracking-widest transition-colors border border-white/5 px-3 py-2 rounded-xl">
                                Cerrar Sesión
                            </button>
                        </form>

                        <div className="bg-white/5 border border-green-500/20 px-5 py-2 rounded-2xl flex flex-col items-center min-w-[120px] relative overflow-hidden group">
                            <RechargeParticles />
                            <span className="text-xl font-black text-green-400 relative z-10">${stats.revenue.toLocaleString()}</span>
                            <span className="text-[9px] text-green-500/50 font-bold uppercase tracking-widest relative z-10">Ingresos Totales</span>
                        </div>

                        {[
                            { label: 'Pendientes', value: stats.pending, color: 'text-coffee-light' },
                            { label: 'Producción', value: stats.inProgress, color: 'text-blue-400' },
                            { label: 'Entregados', value: stats.completed, color: 'text-green-400' }
                        ].map(stat => (
                            <div key={stat.label} className="bg-white/5 border border-white/10 px-5 py-2 rounded-2xl flex flex-col items-center min-w-[100px]">
                                <span className={`text-xl font-black ${stat.color}`}>{stat.value}</span>
                                <span className="text-[9px] text-gray-500 font-bold uppercase tracking-widest">{stat.label}</span>
                            </div>
                        ))}
                    </div>
                </header>

                <Suspense fallback={<div className="text-gray-500">Cargando gestión...</div>}>
                    <ClientOrderManager initialSessions={sessions.data} />
                </Suspense>
            </div>
            
            <style dangerouslySetInnerHTML={{ __html: `
                .custom-scrollbar::-webkit-scrollbar {
                    width: 4px;
                }
                .custom-scrollbar::-webkit-scrollbar-track {
                    background: rgba(255, 255, 255, 0.05);
                }
                .custom-scrollbar::-webkit-scrollbar-thumb {
                    background: #caa052;
                    border-radius: 10px;
                }
            `}} />
        </main>
    );
}
