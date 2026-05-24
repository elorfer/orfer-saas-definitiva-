import Link from 'next/link';
import Script from 'next/script';
import Stripe from 'stripe';
import { redirect } from 'next/navigation';
import { headers, cookies } from 'next/headers';
import { sendMetaEvent } from '@/lib/meta-capi';

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
    const email = session.customer_details?.email || '';
    const phone = session.metadata?.phone || '';

    // --- CAPI Purchase (redundant with webhook for higher Meta coverage score) ---
    const headersList = await headers();
    const cookieStore = await cookies();
    const ip = headersList.get('x-forwarded-for')?.split(',')[0] || '';
    const userAgent = headersList.get('user-agent') || '';
    const fbp = cookieStore.get('_fbp')?.value || session.metadata?.fbp || '';
    const fbc = cookieStore.get('_fbc')?.value || session.metadata?.fbc || '';

    // Same eventID as webhook (session.id) → Meta deduplicates automatically
    sendMetaEvent({
        eventName: 'Purchase',
        eventID: sessionId,
        userData: {
            email,
            phone,
            firstName: name,
            fbp,
            fbc,
            clientIpAddress: ip,
            clientUserAgent: userAgent,
            externalId: typeof session.customer === 'string' ? session.customer : ''
        },
        customData: {
            value: amount,
            currency: 'USD',
            content_name: `Plan ${plan}`,
            content_category: 'Music Production'
        },
        sourceUrl: 'https://www.struky.com/success'
    }).catch(err => console.error('Error in success page CAPI Purchase:', err));

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
                    
                    {/* Premium Avatar / Vinyl Photo */}
                    {/* Premium Static Logo */}
                    <div className="relative mx-auto mb-8 w-32 h-32">
                        <div className="absolute inset-0 rounded-full border border-white/5 bg-[#050505] flex items-center justify-center shadow-[0_0_50px_rgba(202,160,82,0.1)]">
                            <img 
                                src="https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/logoblanco%20web%20p25).webp" 
                                alt="Struky Logo" 
                                className="w-[60%] h-[60%] object-contain brightness-125" 
                            />
                        </div>
                        {/* Status Check Badge Overlay */}
                        <div className="absolute 0-bottom-1 -right-1 bg-green-500 text-black w-10 h-10 rounded-full flex items-center justify-center border-4 border-[#0a0a0a] text-xl shadow-[0_0_20px_rgba(34,197,94,0.3)] z-20">
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
                                    <p className="text-[10px] text-gray-600 mt-1">Recibirás un comprobante en <br className="md:hidden" /><span className="text-gray-400">{session.customer_email}</span></p>
                                </div>
                            </div>
                            <div className="flex items-start gap-4">
                                <div className="w-8 h-8 rounded-xl bg-coffee-medium/20 flex items-center justify-center text-xs text-coffee-medium border border-coffee-medium/20 shrink-0 font-black animate-pulse">2</div>
                                <div>
                                    <p className="text-xs text-white font-bold">Producción en curso</p>
                                    <p className="text-[10px] text-gray-600 mt-1">Nuestro equipo ya analiza tus letras y referencias artísticas.</p>
                                </div>
                            </div>
                            <div className="flex items-start gap-4">
                                <div className="w-8 h-8 rounded-xl bg-white/5 flex items-center justify-center text-xs text-gray-600 border border-white/5 shrink-0 font-black">3</div>
                                <div>
                                    <p className="text-xs text-gray-400 font-bold">Entrega por WhatsApp</p>
                                    <p className="text-[10px] text-gray-600 mt-1">Tu canción final llegará en un plazo estimado de:</p>
                                    <p className="text-[11px] text-coffee-light font-black mt-1 bg-coffee-medium/10 inline-block px-2 py-1 rounded-md">24 a 48 HORAS</p>
                                </div>
                            </div>
                        </div>
                    </div>

                    {/* SPECIAL STEP: CUSTOM MELODY */}
                    <div className="bg-coffee-medium/10 border border-coffee-medium/30 rounded-2xl p-6 mb-8 relative overflow-hidden group">
                        <div className="absolute -right-4 -top-4 opacity-10 group-hover:rotate-12 transition-transform">
                            <svg className="w-24 h-24" fill="currentColor" viewBox="0 0 24 24"><path d="M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z"/></svg>
                        </div>
                        
                        <h3 className="text-sm font-black text-coffee-light uppercase tracking-widest mb-3 flex items-center gap-2">
                             🎹 ¿Tienes una melodía propia?
                        </h3>
                        <p className="text-xs text-gray-400 leading-relaxed mb-4">
                            Si ya tienes una melodía tarareada o grabada y quieres que la usemos, **envíanosla ahora mismo por WhatsApp junto con la captura de pantalla de este pago.**
                        </p>
                        
                        <a 
                            href={`https://wa.me/573017509921?text=${encodeURIComponent(`Hola Struky! 👋 Acabo de pagar mi pedido de un Plan ${plan}. Aquí te envío mi captura de pago y el audio de mi melodía propia para que la usen en la producción. 🚀\n\nID: ${sessionId.substring(0,12)}`)}`}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="flex items-center justify-center gap-3 bg-[#25D366] hover:bg-[#20ba59] text-black font-black py-3 px-6 rounded-xl text-[11px] uppercase tracking-widest transition-all scale-100 hover:scale-[1.02] shadow-xl"
                        >
                            <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L0 24l6.335-1.662c1.72.94 3.659 1.437 5.63 1.438h.008c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z"/></svg>
                            ENVIAR CAPTURA Y MELODÍA
                        </a>
                        <p className="text-[9px] text-coffee-light/40 text-center mt-3 uppercase tracking-widest font-bold italic">
                            * Solo se admiten melodías con la captura del pago
                        </p>
                    </div>

                    {/* Meta Pixel Purchase Event with Deduplication & Advanced Matching */}
                    <Script id="fb-purchase" strategy="afterInteractive">
                        {`
                            if (typeof window !== 'undefined' && typeof window.fbq === 'function') {
                                const sessionId = '${sessionId}';
                                const externalId = '${typeof session.customer === 'string' ? session.customer : (session.customer as any)?.id || ''}';
                                
                                console.log('Struky: Sending Purchase Event', { eventID: sessionId });

                                // Advanced Matching
                                window.fbq('init', '${process.env.NEXT_PUBLIC_META_PIXEL_ID || "1681899642811715"}', {
                                    em: '${email.toLowerCase().trim()}',
                                    ph: '${phone.replace(/\D/g, '')}',
                                    external_id: externalId
                                });
                                
                                window.fbq('track', 'Purchase', {
                                    value: ${amount},
                                    currency: 'USD',
                                    content_name: 'Plan ${plan}',
                                    content_category: 'Music Production'
                                }, { 
                                    eventID: sessionId 
                                });
                            }
                        `}
                    </Script>

                    {/* Limpieza de localStorage de datos del formulario al completar la compra exitosamente */}
                    <Script id="clear-form-data" strategy="afterInteractive">
                        {`
                            if (typeof window !== 'undefined' && window.localStorage) {
                                localStorage.removeItem('struky_order_form_data');
                                localStorage.removeItem('struky_order_form_step');
                                localStorage.removeItem('struky_order_form_send_later');
                                localStorage.removeItem('struky_order_form_song_quantity');
                                localStorage.removeItem('struky_order_form_country_code');
                                console.log('Struky: Form data cleared from localStorage after successful payment.');
                            }
                        `}
                    </Script>

                    {/* CTA */}
                    <div className="flex flex-col gap-3">
                        <Link href="/" className="bg-white/5 hover:bg-white/10 text-white w-full py-4 rounded-xl text-[10px] font-black tracking-[0.2em] transition-all text-center border border-white/5 uppercase">
                            Volver al Inicio
                        </Link>
                        <p className="text-[9px] text-gray-700 uppercase tracking-[0.2em]">Referencia: {sessionId.substring(0, 16)}</p>
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
