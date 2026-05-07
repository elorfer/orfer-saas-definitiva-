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

    const [activeProduct, setActiveProduct] = useState<'hoodie' | 'cap'>('hoodie');

    return (
        <section className="section-padding bg-[#050505] relative overflow-hidden border-t border-white/5">
            <div className="max-w-4xl mx-auto px-4 relative z-10">
                
                {/* 1. MIDDLE - PRODUCT GALLERY */}
                <div className="relative flex flex-col items-center mb-12">
                    {/* Main Display Container */}
                    <div className="relative w-full">
                        <motion.div 
                            key={activeProduct}
                            initial={{ opacity: 0 }}
                            animate={{ opacity: 1 }}
                            onClick={() => setIsLightboxOpen(true)}
                            className="relative w-full aspect-square md:aspect-[4/3] rounded-[2.5rem] overflow-hidden bg-[#111] border border-white/5 cursor-zoom-in group"
                        >
                            <Image 
                                src={activeProduct === 'hoodie' ? "https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/sudadera.webp" : "https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/gorra-pronto.webp"}
                                alt={activeProduct === 'hoodie' ? "Official Struky Hoodie" : "Official Struky Cap"}
                                fill
                                className="object-cover"
                                sizes="(max-width: 768px) 100vw, 800px"
                                unoptimized
                            />

                            {/* Floating Price Tag */}
                            <div className="absolute top-6 left-6 bg-black/80 px-5 py-2 rounded-full border border-white/10 z-20">
                                <span className="text-xl md:text-2xl font-black italic uppercase text-white tracking-tighter">
                                    {content.price}<span className="text-white/80 text-xs md:text-sm ml-[3px] not-italic font-black">{content.currency}</span>
                                </span>
                            </div>
                            
                            {activeProduct === 'cap' && (
                                <div className="absolute inset-0 flex items-center justify-center bg-black/20">
                                    <div className="bg-purple-600 text-white px-8 py-3 rounded-full text-sm md:text-lg font-black italic uppercase tracking-tighter shadow-2xl border border-white/20">
                                        {lang === 'es' ? 'Próximamente' : 'Coming Soon'}
                                    </div>
                                </div>
                            )}

                            <div className="absolute bottom-16 right-8 bg-black/80 p-4 rounded-full border border-white/10 opacity-0 group-hover:opacity-100 transition-opacity">
                                <svg className="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0zM10 7v3m0 0v3m0-3h3m-3 0H7"/></svg>
                            </div>
                        </motion.div>

                        {/* Thumbnails Switcher (Half-In, Half-Out) */}
                        <div className="absolute bottom-0 left-1/2 -translate-x-1/2 translate-y-1/2 flex gap-4 p-2 bg-[#111] border border-white/10 rounded-2xl shadow-2xl z-30">
                            <button 
                                onClick={(e) => { e.stopPropagation(); setActiveProduct('hoodie'); }}
                                className={`relative w-16 h-16 rounded-xl overflow-hidden border-2 transition-all ${activeProduct === 'hoodie' ? 'border-coffee-medium scale-110' : 'border-transparent opacity-40 hover:opacity-100'}`}
                            >
                                <Image src="https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/sudadera.webp" alt="Hoodie" fill className="object-cover" sizes="64px" unoptimized />
                            </button>
                            <button 
                                onClick={(e) => { e.stopPropagation(); setActiveProduct('cap'); }}
                                className={`relative w-16 h-16 rounded-xl overflow-hidden border-2 transition-all ${activeProduct === 'cap' ? 'border-purple-500 scale-110' : 'border-transparent opacity-40 hover:opacity-100'}`}
                            >
                                <Image src="https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/gorra-pronto.webp" alt="Cap" fill className="object-cover" sizes="64px" unoptimized />
                                <div className="absolute inset-0 bg-black/60 flex items-center justify-center text-[8px] font-black text-white uppercase italic">Soon</div>
                            </button>
                        </div>
                    </div>
                </div>

                {/* 2. MIDDLE - HEADER (MOVED BELOW PRODUCT) */}
                <div className="flex flex-col items-center text-center mt-20 mb-16">
                    <div className="flex items-center gap-2 text-coffee-light mb-8 bg-white/5 px-6 py-2 rounded-full border border-white/10 w-fit">
                        <ShoppingBag className="w-4 h-4" />
                        <span className="text-[11px] font-black italic uppercase tracking-tighter">Official Collection</span>
                    </div>

                    <h2 className="text-5xl md:text-7xl font-black mb-8 leading-[0.95] tracking-tighter text-white">
                        {content.title} <br />
                        <span className="text-gradient">{content.highlight}</span>
                    </h2>

                    <p className="text-gray-500 text-lg md:text-xl leading-relaxed max-w-2xl font-bold">
                        {content.description}
                    </p>
                </div>

                {/* 3. BOTTOM - CALL TO ACTION & PRICE */}

                {/* 3. BOTTOM - CALL TO ACTION & PRICE */}
                <div className="w-full max-w-xl mx-auto flex flex-col items-center">
                    <div className="w-full space-y-8 bg-[#0A0A0A] border border-white/5 p-8 md:p-12 rounded-[2.5rem] shadow-2xl mb-12">
                        <div className="flex flex-wrap items-center justify-between gap-6">
                            <div className="text-5xl font-black text-white tracking-tighter">
                                {content.price}<span className="text-white/60 text-lg ml-[3px]">{content.currency}</span>
                            </div>
                            <div className="flex items-center gap-2 text-gray-500 text-[10px] md:text-xs uppercase font-black tracking-[0.2em] bg-white/5 px-4 py-2 rounded-lg border border-white/5">
                                <Globe className="w-4 h-4" />
                                {content.shipping}
                            </div>
                        </div>

                        {status === 'success' ? (
                            <div className="p-6 bg-green-500/10 border border-green-500/20 rounded-2xl text-green-400 font-bold text-center">
                                {content.success}
                            </div>
                        ) : (
                            <form onSubmit={handleSubmit} className="flex flex-col gap-4">
                                <div className="relative">
                                    <input 
                                        type="email" 
                                        placeholder={content.placeholder}
                                        value={email}
                                        onChange={(e) => setEmail(e.target.value)}
                                        required
                                        className="w-full bg-[#111] border border-white/10 rounded-2xl py-6 px-8 outline-none focus:border-coffee-medium transition-all text-white placeholder:text-gray-700 font-medium text-lg"
                                    />
                                </div>
                                <button 
                                    type="submit"
                                    disabled={status === 'loading'}
                                    className="w-full bg-[#8B6A5A] hover:bg-[#9E7B6B] text-black font-black uppercase text-lg tracking-[0.2em] py-6 rounded-2xl transition-all active:scale-[0.98]"
                                >
                                    {status === 'loading' ? '...' : content.cta}
                                </button>
                            </form>
                        )}
                    </div>

                    {/* Final Footer Decor */}
                    <div className="grid grid-cols-2 gap-8 w-full">
                        <div className="text-center">
                            <div className="text-coffee-light font-black text-2xl italic uppercase">Ultra Limited</div>
                            <div className="text-gray-500 text-[10px] uppercase font-bold tracking-[0.3em]">50 Units per Drop</div>
                        </div>
                        <div className="text-center">
                            <div className="text-white font-black text-2xl italic uppercase">Struky Quality</div>
                            <div className="text-gray-500 text-[10px] uppercase font-bold tracking-[0.3em]">Premium Finishes</div>
                        </div>
                    </div>
                </div>
            </div>

            {/* Lightbox Modal */}
            {isLightboxOpen && (
                <motion.div 
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    className="fixed inset-0 z-[100] bg-black/95 flex items-center justify-center p-4 md:p-12"
                    onClick={() => setIsLightboxOpen(false)}
                >
                    <motion.div 
                        initial={{ scale: 0.9, opacity: 0 }}
                        animate={{ scale: 1, opacity: 1 }}
                        className="relative w-full max-w-5xl aspect-square"
                    >
                        <Image 
                            src={activeProduct === 'hoodie' ? "https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/sudadera.webp" : "https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/gorra-pronto.webp"}
                            alt={activeProduct === 'hoodie' ? "Official Struky Hoodie Full View" : "Official Struky Cap Full View"}
                            fill
                            className="object-contain"
                            sizes="(max-width: 1200px) 100vw, 1200px"
                            unoptimized
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
