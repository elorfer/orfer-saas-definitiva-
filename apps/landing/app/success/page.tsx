import Link from 'next/link';
import Stripe from 'stripe';
import { redirect } from 'next/navigation';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
    apiVersion: '2026-03-25.dahlia',
});

export default async function SuccessPage({ searchParams }: { searchParams: { session_id?: string } }) {
    const sessionId = searchParams?.session_id;

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

    return (
        <div className="min-h-screen flex items-center justify-center p-6 bg-dark-bg">
            <div className="card-dark max-w-lg w-full text-center py-12 relative overflow-hidden">
                <div className="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-coffee-medium to-coffee-light"></div>
                
                <div className="w-20 h-20 bg-green-500/20 text-green-400 rounded-full flex items-center justify-center mx-auto mb-6 text-4xl shadow-[0_0_20px_rgba(34,197,94,0.2)]">
                    ✓
                </div>

                <h1 className="text-3xl font-heading font-bold mb-2">¡Pago Exitoso!</h1>
                <p className="text-coffee-light font-bold mb-4 uppercase tracking-[0.2em] text-xs">Bienvenido a la Élite, {name}</p>
                
                <p className="text-gray-400 mb-8 text-sm leading-relaxed px-4">
                    Hemos recibido correctamente tu orden del <span className="text-white font-bold">Plan {plan}</span> por <span className="text-white font-bold">${amount} USD</span>. 
                    El proceso creativo ha comenzado.
                </p>

                <div className="bg-[#111] border border-white/5 rounded-2xl p-6 mb-8 text-left mx-4">
                    <h3 className="font-bold text-white mb-4 text-xs uppercase tracking-widest flex items-center gap-2">
                        <div className="w-1.5 h-1.5 rounded-full bg-coffee-medium animate-pulse"></div>
                        ¿Qué sigue ahora?
                    </h3>
                    <ul className="text-xs text-gray-500 space-y-4">
                        <li className="flex items-start gap-3">
                            <div className="w-5 h-5 rounded-full bg-white/5 flex items-center justify-center text-[10px] text-coffee-medium border border-white/10 shrink-0">1</div>
                            <p>Recibirás un comprobante oficial de Stripe en tu correo <span className="text-gray-300">({session.customer_email})</span>.</p>
                        </li>
                        <li className="flex items-start gap-3">
                            <div className="w-5 h-5 rounded-full bg-white/5 flex items-center justify-center text-[10px] text-coffee-medium border border-white/10 shrink-0">2</div>
                            <p>Nuestros productores analizarán tus letras y referencias para crear el primer máster.</p>
                        </li>
                        <li className="flex items-start gap-3">
                            <div className="w-5 h-5 rounded-full bg-white/5 flex items-center justify-center text-[10px] text-coffee-medium border border-white/10 shrink-0">3</div>
                            <p>Tu canción final llegará directamente a tu WhatsApp en <span className="text-gray-300 font-bold">24 a 48 horas</span>.</p>
                        </li>
                    </ul>
                </div>

                <div className="flex flex-col gap-3 px-4">
                    <Link href="/" className="btn-primary w-full py-4 rounded-xl text-sm font-bold tracking-widest">
                        VOLVER AL INICIO
                    </Link>
                    <p className="text-[10px] text-gray-600 uppercase tracking-widest">ID Operación: {sessionId.substring(0, 20)}...</p>
                </div>
            </div>
        </div>
    );
}
