import Link from 'next/link';
import Stripe from 'stripe';
import { redirect } from 'next/navigation';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY || 'sk_test_dummy', {
    apiVersion: '2026-03-25.dahlia',
});

export default async function SuccessPage({ searchParams }: { searchParams: Promise<{ session_id?: string }> }) {
    const params = await searchParams;
    const sessionId = params?.session_id;

    if (!sessionId) {
        redirect('/');
    }

    let session;
    try {
        session = await stripe.checkout.sessions.retrieve(sessionId);
    } catch (e) {
        redirect('/');
    }

    const name = session.metadata?.name || 'Cliente';
    const plan = session.metadata?.plan || 'Starter';
    const amount = (session.amount_total || 0) / 100;
    const genre = session.metadata?.genre || '';
    const vocalist = session.metadata?.vocalist || '';

    return (
        <div className="min-h-screen flex items-center justify-center p-4 md:p-6 bg-dark-bg relative overflow-hidden">
            {/* Background effects */}
            <div className="absolute inset-0 pointer-events-none">
                <div className="absolute top-1/4 left-1/4 w-96 h-96 bg-green-500/5 rounded-full blur-[120px]"></div>
                <div className="absolute bottom-1/4 right-1/4 w-96 h-96 bg-coffee-medium/5 rounded-full blur-[120px]"></div>
            </div>

            <div className="max-w-xl w-full relative z-10">
                {/* Success Card */}
                <div className="bg-black/60 backdrop-blur-xl border border-white/10 rounded-3xl p-8 md:p-12 text-center relative overflow-hidden shadow-2xl">
                    {/* Top gradient bar */}
                    <div className="absolute top-0 left-0 w-full h-1.5 bg-gradient-to-r from-green-500 via-coffee-medium to-coffee-light"></div>
                    
                    {/* Animated check icon */}
                    <div className="relative mx-auto mb-8 w-24 h-24">
                        <div className="absolute inset-0 bg-green-500/20 rounded-full animate-ping"></div>
                        <div className="relative w-24 h-24 bg-gradient-to-br from-green-500/30 to-green-600/10 text-green-400 rounded-full flex items-center justify-center text-5xl border border-green-500/30 shadow-[0_0_40px_rgba(34,197,94,0.15)]">
                            ✓
                        </div>
                    </div>

                    {/* Title */}
                    <h1 className="text-3xl md:text-4xl font-black text-white mb-2 tracking-tight">¡Pago Exitoso!</h1>
                    <p className="text-coffee-light font-black mb-2 uppercase tracking-[0.3em] text-[10px]">
                        Bienvenido a la Élite Musical
                    </p>
                    <p className="text-white/60 text-lg mb-8">{name}</p>

                    {/* Order summary mini */}
                    <div className="grid grid-cols-3 gap-3 mb-8">
                        <div className="bg-white/5 rounded-2xl p-4 border border-white/5">
                            <p className="text-[9px] text-gray-600 uppercase tracking-widest mb-1">Plan</p>
                            <p className="text-sm font-black text-coffee-light">{plan}</p>
                        </div>
                        <div className="bg-white/5 rounded-2xl p-4 border border-white/5">
                            <p className="text-[9px] text-gray-600 uppercase tracking-widest mb-1">Total</p>
                            <p className="text-sm font-black text-white">${amount} USD</p>
                        </div>
                        <div className="bg-white/5 rounded-2xl p-4 border border-white/5">
                            <p className="text-[9px] text-gray-600 uppercase tracking-widest mb-1">Género</p>
                            <p className="text-sm font-black text-white">{genre || '—'}</p>
                        </div>
                    </div>

                    {/* Timeline */}
                    <div className="bg-[#0a0a0a] border border-white/5 rounded-2xl p-6 mb-8 text-left">
                        <h3 className="font-black text-white mb-5 text-[10px] uppercase tracking-[0.3em] flex items-center gap-2">
                            <div className="w-2 h-2 rounded-full bg-green-500 animate-pulse"></div>
                            Tu producción está en marcha
                        </h3>
                        <div className="space-y-5">
                            <div className="flex items-start gap-4">
                                <div className="w-8 h-8 rounded-xl bg-green-500/20 flex items-center justify-center text-xs text-green-400 border border-green-500/20 shrink-0 font-black">✓</div>
                                <div>
                                    <p className="text-xs text-white font-bold">Pago confirmado</p>
                                    <p className="text-[10px] text-gray-600">Recibirás un comprobante en <span className="text-gray-400">{session.customer_email}</span></p>
                                </div>
                            </div>
                            <div className="flex items-start gap-4">
                                <div className="w-8 h-8 rounded-xl bg-coffee-medium/20 flex items-center justify-center text-xs text-coffee-medium border border-coffee-medium/20 shrink-0 font-black animate-pulse">2</div>
                                <div>
                                    <p className="text-xs text-white font-bold">Producción en curso</p>
                                    <p className="text-[10px] text-gray-600">Nuestro equipo ya analiza tus letras y referencias artísticas</p>
                                </div>
                            </div>
                            <div className="flex items-start gap-4">
                                <div className="w-8 h-8 rounded-xl bg-white/5 flex items-center justify-center text-xs text-gray-600 border border-white/5 shrink-0 font-black">3</div>
                                <div>
                                    <p className="text-xs text-gray-500 font-bold">Entrega por WhatsApp</p>
                                    <p className="text-[10px] text-gray-600">Tu canción final llegará en <span className="text-coffee-light font-bold">24 a 48 horas</span></p>
                                </div>
                            </div>
                        </div>
                    </div>

                    {/* CTA */}
                    <div className="flex flex-col gap-3">
                        <Link href="/" className="btn-primary w-full py-4 rounded-xl text-sm font-black tracking-widest">
                            VOLVER AL INICIO
                        </Link>
                        <p className="text-[9px] text-gray-700 uppercase tracking-[0.2em]">ID: {sessionId.substring(0, 24)}...</p>
                    </div>
                </div>

                {/* Trust footer */}
                <div className="flex items-center justify-center gap-6 mt-6 opacity-40">
                    <div className="flex items-center gap-2">
                        <svg className="w-4 h-4 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.5" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/></svg>
                        <span className="text-[9px] text-gray-600 uppercase tracking-widest">Pago Seguro</span>
                    </div>
                    <div className="flex items-center gap-2">
                        <svg className="w-4 h-4 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.5" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"/></svg>
                        <span className="text-[9px] text-gray-600 uppercase tracking-widest">Garantía Total</span>
                    </div>
                </div>
            </div>
        </div>
    );
}
