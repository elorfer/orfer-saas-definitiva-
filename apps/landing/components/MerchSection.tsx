'use client';

import { useState } from 'react';
import Image from 'next/image';
import { ShoppingBag, Globe, Send } from 'lucide-react';
import { motion } from 'framer-motion';

export default function MerchSection({ lang }: { lang: 'es' | 'en' }) {
    const [email, setEmail] = useState('');
    const [status, setStatus] = useState<'idle' | 'loading' | 'success'>('idle');
    const [isLightboxOpen, setIsLightboxOpen] = useState(false);

    const content = {
        es: {
            title: "Encarga nuestra",
            highlight: "Sudadera Oficial",
            description: "No es solo ropa, es el uniforme de los que crean el futuro de la música. Edición ultra-limitada con acabados premium.",
            price: "150",
            currency: "USD",
            shipping: "Envíos a todo el mundo",
            placeholder: "Tu email para avisarte",
            cta: "Reservar Ahora",
            success: "¡Recibido! Te contactaremos pronto.",
        },
        en: {
            title: "Order our",
            highlight: "Official Hoodie",
            description: "It's not just clothing, it's the uniform of those creating the future of music. Ultra-limited edition with premium finishes.",
            price: "150",
            currency: "USD",
            shipping: "Worldwide Shipping",
            placeholder: "Your email for updates",
            cta: "Pre-order Now",
            success: "Received! We'll contact you soon.",
        }
    }[lang];

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!email) return;
        setStatus('loading');
        
        try {
            const response = await fetch('/api/merch-lead', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ email }),
            });

            if (response.ok) {
                setStatus('success');
                setEmail('');
            } else {
                throw new Error('Failed to send lead');
            }
        } catch (error) {
            console.error('Error sending lead:', error);
            setStatus('idle');
            alert(lang === 'es' ? 'Hubo un error. Inténtalo de nuevo.' : 'Something went wrong. Please try again.');
        }
    };

    return (
        <section className="section-padding bg-dark-bg relative overflow-hidden border-t border-white/5">
            {/* Background Glow */}
            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[500px] h-[500px] bg-coffee-medium/5 blur-[150px] rounded-full pointer-events-none"></div>

            <div className="max-w-7xl mx-auto px-4 relative z-10">
                <div className="grid lg:grid-cols-2 gap-12 items-center">
                    
                    {/* Image Side */}
                    <motion.div 
                        initial={{ opacity: 0, x: -50 }}
                        whileInView={{ opacity: 1, x: 0 }}
                        viewport={{ once: true }}
                        transition={{ duration: 0.8 }}
                        onClick={() => setIsLightboxOpen(true)}
                        className="relative aspect-square rounded-3xl overflow-hidden group shadow-2xl shadow-black/50 border border-white/10 cursor-zoom-in"
                    >
                        <Image 
                            src="/images/sudadera.webp"
                            alt="Official Struky Hoodie"
                            fill
                            className="object-cover transition-transform duration-700 group-hover:scale-110"
                        />
                        <div className="absolute inset-0 bg-gradient-to-t from-black/60 via-transparent to-transparent"></div>
                        
                        {/* Price Tag Overlay */}
                        <div className="absolute bottom-6 left-6 bg-black/80 backdrop-blur-md border border-coffee-medium/30 px-4 py-2 rounded-full">
                            <span className="text-coffee-light font-black text-xl">{content.price} {content.currency}</span>
                        </div>
                    </motion.div>

                    {/* Content Side */}
                    <motion.div 
                        initial={{ opacity: 0, x: 50 }}
                        whileInView={{ opacity: 1, x: 0 }}
                        viewport={{ once: true }}
                        transition={{ duration: 0.8, delay: 0.2 }}
                        className="text-center lg:text-left flex flex-col items-center lg:items-start"
                    >
                        <div className="flex items-center gap-2 text-coffee-light mb-4 bg-coffee-medium/10 px-3 py-1 rounded-full border border-coffee-medium/20">
                            <ShoppingBag className="w-4 h-4" />
                            <span className="text-[10px] font-black uppercase tracking-[0.2em]">Official Merch</span>
                        </div>

                        <h2 className="text-3xl md:text-5xl lg:text-6xl font-black mb-6 leading-tight">
                            {content.title} <br className="hidden md:block" />
                            <span className="text-gradient">{content.highlight}</span>
                        </h2>

                        <p className="text-gray-400 text-base md:text-lg mb-8 leading-relaxed max-w-xl">
                            {content.description}
                        </p>

                        <div className="flex items-center gap-3 text-gray-300 mb-10 bg-white/5 w-fit px-4 py-2 rounded-lg border border-white/10">
                            <Globe className="w-4 h-4 text-coffee-medium" />
                            <span className="text-xs md:text-sm font-medium">{content.shipping}</span>
                        </div>

                        {/* Order Form */}
                        <div className="w-full max-w-md">
                            {status === 'success' ? (
                                <motion.div 
                                    initial={{ opacity: 0, y: 10 }}
                                    animate={{ opacity: 1, y: 0 }}
                                    className="p-4 bg-green-500/10 border border-green-500/20 rounded-xl text-green-400 font-medium flex items-center justify-center lg:justify-start gap-3"
                                >
                                    <div className="w-8 h-8 rounded-full bg-green-500/20 flex items-center justify-center">
                                        <Send className="w-4 h-4" />
                                    </div>
                                    {content.success}
                                </motion.div>
                            ) : (
                                <form onSubmit={handleSubmit} className="flex flex-col sm:flex-row gap-3 w-full">
                                    <input 
                                        type="email" 
                                        placeholder={content.placeholder}
                                        value={email}
                                        onChange={(e) => setEmail(e.target.value)}
                                        required
                                        className="flex-grow bg-white/5 border border-white/10 rounded-xl py-4 px-5 outline-none focus:border-coffee-medium/50 transition-all text-white placeholder:text-gray-600 text-sm"
                                    />
                                    <button 
                                        type="submit"
                                        disabled={status === 'loading'}
                                        className="btn-primary py-4 px-8 text-black font-black uppercase text-xs tracking-widest rounded-xl transition-all active:scale-95 disabled:opacity-50 whitespace-nowrap"
                                    >
                                        {status === 'loading' ? '...' : content.cta}
                                    </button>
                                </form>
                            )}
                            <p className="text-[9px] text-gray-500 mt-4 px-2 uppercase tracking-widest">
                                Al suscribirte aceptas recibir noticias sobre lanzamientos de merch.
                            </p>
                        </div>
                    </motion.div>

                </div>
            </div>

            {/* Lightbox Modal */}
            {isLightboxOpen && (
                <motion.div 
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    className="fixed inset-0 z-[100] bg-black/95 backdrop-blur-sm flex items-center justify-center p-4 md:p-12"
                    onClick={() => setIsLightboxOpen(false)}
                >
                    <motion.div 
                        initial={{ scale: 0.9, opacity: 0 }}
                        animate={{ scale: 1, opacity: 1 }}
                        className="relative w-full max-w-5xl aspect-square"
                    >
                        <Image 
                            src="/images/sudadera.webp"
                            alt="Official Struky Hoodie Full View"
                            fill
                            className="object-contain"
                        />
                    </motion.div>
                    <button 
                        className="absolute top-8 right-8 text-white/50 hover:text-white transition-colors"
                        onClick={() => setIsLightboxOpen(false)}
                    >
                        <svg className="w-10 h-10" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M6 18L18 6M6 6l12 12"/></svg>
                    </button>
                </motion.div>
            )}
        </section>
    );
}
