'use client';

import React, { useState, useEffect } from 'react';
import Header from '../../components/Header';
import ExtraServices from '../../components/ExtraServices';
import Footer from '../../components/Footer';
import { translations } from '../../lib/translations';
import { useSearchParams, useRouter } from 'next/navigation';
import { playSuccess, playWhoosh } from '../../lib/soundEngine';
import { Loader2, Mail, ArrowRight, X } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

export default function ServiciosContent() {
    const searchParams = useSearchParams();
    const router = useRouter();
    const [lang, setLang] = useState<'es' | 'en'>('es');
    const [isLoading, setIsLoading] = useState(false);
    const [showEmailModal, setShowEmailModal] = useState(false);
    const [selectedService, setSelectedService] = useState<{id: string, price: number} | null>(null);
    const [email, setEmail] = useState('');
    
    const t = translations[lang];

    useEffect(() => {
        const urlLang = searchParams.get('lang');
        if (urlLang === 'en' || urlLang === 'es') {
            setLang(urlLang as 'es' | 'en');
        }
    }, [searchParams]);

    const handleSelectService = (planId: string, price: number) => {
        playSuccess();
        setSelectedService({ id: planId, price });
        setShowEmailModal(true);
    };

    const handleCheckout = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!selectedService || !email) return;

        setIsLoading(true);
        try {
            const response = await fetch('/api/checkout', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    email,
                    plan: selectedService.id === 'youtube' ? (lang === 'es' ? 'Presencia YouTube' : 'YouTube Presence') : selectedService.id,
                    price: selectedService.price,
                    genre: 'YouTube/Social',
                    vocalist: 'N/A',
                    notes: 'Pedido desde página de servicios'
                }),
            });
            const data = await response.json();
            if (data.url) {
                window.location.href = data.url;
            } else {
                alert(lang === 'es' ? 'Error al procesar el pago' : 'Error processing payment');
            }
        } catch (error) {
            console.error('Checkout error:', error);
            alert(lang === 'es' ? 'Error de conexión' : 'Connection error');
        } finally {
            setIsLoading(false);
        }
    };

    return (
        <main className="min-h-screen bg-dark-bg font-sans selection:bg-coffee-medium selection:text-white relative overflow-x-hidden">
            <Header lang={lang} setLang={setLang} />
            
            {/* Persuasive Hero Section for Services */}
            <section className="pt-32 pb-16 px-4 relative">
                <div className="absolute top-0 left-1/2 -translate-x-1/2 w-full max-w-6xl h-[500px] bg-coffee-medium/5 blur-[120px] rounded-full pointer-events-none" />
                
                <div className="max-w-7xl mx-auto text-center relative z-10">
                    <motion.div
                        initial={{ opacity: 0, y: 20 }}
                        animate={{ opacity: 1, y: 0 }}
                        transition={{ duration: 0.6 }}
                    >
                        <h1 className="text-5xl md:text-8xl font-black text-white tracking-normal mb-6 leading-tight uppercase italic px-8 overflow-visible">
                            {(t as any).youtubeSales.hero.title}
                            <span className="text-gradient inline-block px-2">{(t as any).youtubeSales.hero.highlight}</span>
                        </h1>
                        <p className="text-gray-400 text-xl md:text-2xl max-w-3xl mx-auto mb-10 font-medium">
                            {(t as any).youtubeSales.hero.subtitle}
                        </p>
                    </motion.div>

                    {/* Quick Stats Section */}
                    <div className="grid grid-cols-1 md:grid-cols-3 gap-8 max-w-4xl mx-auto mb-20">
                        {(t as any).youtubeSales.stats.map((stat: any, i: number) => (
                            <motion.div
                                key={i}
                                initial={{ opacity: 0, scale: 0.9 }}
                                animate={{ opacity: 1, scale: 1 }}
                                transition={{ delay: i * 0.1 + 0.3 }}
                                className="bg-white/5 border border-white/10 p-8 rounded-[2rem] backdrop-blur-md"
                            >
                                <div className="text-4xl md:text-5xl font-black text-coffee-medium mb-1 tracking-tight">{stat.value}</div>
                                <div className="text-[10px] text-gray-500 uppercase font-black tracking-widest">{stat.label}</div>
                            </motion.div>
                        ))}
                    </div>
                </div>
            </section>

            {/* Benefits Grid */}
            <section className="py-20 bg-black/30 relative">
                <div className="max-w-7xl mx-auto px-4">
                    <div className="grid md:grid-cols-3 gap-12">
                        {(t as any).youtubeSales.benefits.map((benefit: any, i: number) => (
                            <motion.div
                                key={i}
                                initial={{ opacity: 0, x: -20 }}
                                whileInView={{ opacity: 1, x: 0 }}
                                transition={{ delay: i * 0.1 }}
                                viewport={{ once: true }}
                                className="space-y-4"
                            >
                                <div className="w-12 h-12 bg-coffee-medium/10 rounded-xl flex items-center justify-center text-coffee-medium font-black border border-coffee-medium/20">
                                    0{i + 1}
                                </div>
                                <h3 className="text-2xl font-black text-white uppercase tracking-tight">{benefit.title}</h3>
                                <p className="text-gray-400 leading-relaxed font-medium">{benefit.desc}</p>
                            </motion.div>
                        ))}
                    </div>
                </div>
            </section>

            {/* The Main Offer Section */}
            <div className="py-20">
                <ExtraServices 
                    lang={lang} 
                    t={t} 
                    onSelectPlan={handleSelectService} 
                />
            </div>

            <Footer lang={lang} />

            {/* Email Modal for Direct Checkout */}
            <AnimatePresence>
                {showEmailModal && (
                    <div className="fixed inset-0 z-[100] flex items-center justify-center p-4">
                        <motion.div 
                            initial={{ opacity: 0 }}
                            animate={{ opacity: 1 }}
                            exit={{ opacity: 0 }}
                            onClick={() => !isLoading && setShowEmailModal(false)}
                            className="absolute inset-0 bg-black/80 backdrop-blur-sm"
                        />
                        <motion.div 
                            initial={{ opacity: 0, scale: 0.9, y: 20 }}
                            animate={{ opacity: 1, scale: 1, y: 0 }}
                            exit={{ opacity: 0, scale: 0.9, y: 20 }}
                            className="relative w-full max-w-md bg-[#111] border border-white/10 rounded-[2.5rem] p-8 shadow-2xl overflow-hidden"
                        >
                            {/* Decor */}
                            <div className="absolute -top-24 -right-24 w-48 h-48 bg-coffee-medium/10 rounded-full blur-3xl" />
                            
                            <button 
                                onClick={() => setShowEmailModal(false)}
                                className="absolute top-6 right-6 text-gray-500 hover:text-white transition-colors"
                            >
                                <X className="w-6 h-6" />
                            </button>

                            <div className="relative">
                                <div className="w-16 h-16 bg-coffee-medium/10 rounded-2xl flex items-center justify-center text-coffee-medium mb-6 border border-coffee-medium/20">
                                    <Mail className="w-8 h-8" />
                                </div>

                                <h3 className="text-2xl font-black text-white uppercase tracking-tight mb-2">
                                    {lang === 'es' ? '¿A dónde enviamos los detalles?' : 'Where should we send the details?'}
                                </h3>
                                <p className="text-gray-400 text-sm mb-8 leading-relaxed">
                                    {lang === 'es' 
                                        ? 'Necesitamos tu email para enviarte el acceso a tu nuevo servicio y procesar el pago seguro.' 
                                        : 'We need your email to send you access to your new service and process secure payment.'}
                                </p>

                                <form onSubmit={handleCheckout} className="space-y-4">
                                    <div className="relative">
                                        <input 
                                            type="email"
                                            required
                                            placeholder="tu@email.com"
                                            value={email}
                                            onChange={(e) => setEmail(e.target.value)}
                                            className="w-full bg-white/5 border border-white/10 rounded-2xl px-6 py-4 outline-none focus:border-coffee-medium transition-all text-white"
                                        />
                                    </div>
                                    <button 
                                        type="submit"
                                        disabled={isLoading}
                                        className="w-full btn-primary !py-4 flex items-center justify-center gap-3 group"
                                    >
                                        {isLoading ? (
                                            <Loader2 className="w-6 h-6 animate-spin" />
                                        ) : (
                                            <>
                                                <span className="font-black uppercase tracking-widest">
                                                    {lang === 'es' ? 'Ir al Pago Seguro' : 'Go to Secure Payment'}
                                                </span>
                                                <ArrowRight className="w-5 h-5 group-hover:translate-x-1 transition-transform" />
                                            </>
                                        )}
                                    </button>
                                </form>

                                <div className="mt-8 pt-6 border-t border-white/5 flex items-center justify-center gap-4 grayscale opacity-50">
                                    <span className="text-[10px] text-gray-500 font-bold uppercase tracking-widest">Secure Payment by</span>
                                    <div className="text-white font-black text-xs">stripe</div>
                                </div>
                            </div>
                        </motion.div>
                    </div>
                )}
            </AnimatePresence>
        </main>
    );
}
