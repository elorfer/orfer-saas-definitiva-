'use client';
// Build trigger: 2026-04-26 01:29


import Image from 'next/image';
import { motion } from 'framer-motion';
import { Star, ChevronDown, BadgeCheck, Zap, Mic, BarChart3, Check } from 'lucide-react';
import { useEffect } from 'react';
import { playWhoosh, playPop, initSoundEngine } from '@/lib/soundEngine';

interface HeroProps {
    t: any;
    lang: 'es' | 'en';
}

export default function Hero({ t, lang }: HeroProps) {
    // Preload sounds on first user interaction
    useEffect(() => {
        const handler = () => { initSoundEngine(); window.removeEventListener('click', handler); };
        window.addEventListener('click', handler, { once: true });
        return () => window.removeEventListener('click', handler);
    }, []);
    return (
        <section className="relative min-h-screen flex items-center justify-center overflow-hidden pt-20">
            {/* Background */}
            <div className="absolute inset-0 z-0">
                <Image
                    src="/hero-bg.png"
                    alt="Music Studio"
                    fill
                    className="object-cover opacity-40"
                    priority
                    quality={85}
                    sizes="100vw"
                />
                <div className="absolute inset-0 bg-gradient-to-b from-dark-bg/20 via-dark-bg/60 to-dark-bg"></div>
                
                {/* Accent Orbs */}
                <div className="bg-orb-1 absolute -top-20 -left-20 w-96 h-96 blur-[120px] pointer-events-none opacity-40"></div>
                <div className="bg-orb-2 absolute top-1/3 -right-20 w-80 h-80 blur-[120px] pointer-events-none opacity-30"></div>
                <div className="bg-orb-coffee absolute bottom-0 left-1/2 -translate-x-1/2 w-[600px] h-[400px] blur-[150px] pointer-events-none opacity-20"></div>

                {/* Los soundwaves fueron removidos para un diseño más limpio y premium */}
            </div>

            <div className="relative z-10 max-w-6xl mx-auto px-6 text-center">
                <motion.div
                    initial={{ opacity: 0, y: 30 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ duration: 0.4 }}
                    className="flex flex-col items-center"
                >
                    <span className="inline-block px-6 py-2 rounded-full bg-coffee-medium/20 text-coffee-light text-[11px] font-black italic uppercase tracking-tighter mb-8 border border-coffee-medium/30">
                        {t.tag}
                    </span>
                    
                    {/* Main Headline */}
                    <h1 className="text-4xl md:text-6xl lg:text-7xl font-black mb-6 leading-[1.15] tracking-tight uppercase drop-shadow-[0_4px_20px_rgba(0,0,0,0.8)]">
                        <span className="text-white">{t.title1}</span>
                        <span className="text-[#1DB954] drop-shadow-[0_0_30px_rgba(29,185,84,0.3)]">
                            {t.titleHighlight}
                        </span>
                        <br />
                        <span className="text-coffee-light mt-2 inline-block">
                            {t.subtitle1}
                        </span>
                        <span className="text-[#1DB954] drop-shadow-[0_0_30px_rgba(29,185,84,0.3)]">
                            {t.subtitleHighlight}
                        </span>
                    </h1>

                    <p className="text-lg md:text-xl text-gray-300 mb-12 max-w-3xl mx-auto leading-relaxed px-4 sm:px-0 font-medium">
                        {t.description}
                    </p>

                    {/* CTA Button */}
                    <div className="flex flex-col sm:flex-row items-center justify-center gap-4 sm:gap-6 mt-4 w-full">
                        <button 
                            onClick={() => {
                                playPop();
                                document.getElementById('order-form')?.scrollIntoView({ behavior: 'smooth' });
                            }}
                            className="btn-primary text-lg md:text-xl px-8 md:px-12 py-4 md:py-5 w-full sm:w-auto leading-tight"
                        >
                            {t.cta}
                        </button>
                        <a 
                            href="#examples" 
                            onClick={() => playWhoosh()}
                            className="btn-secondary text-lg md:text-xl px-8 md:px-10 py-4 md:py-5 w-full sm:w-auto"
                        >
                            {t.listen}
                        </a>
                    </div>

                    {/* Trust indicators below CTA */}
                    <motion.div 
                        initial={{ opacity: 0, y: 10 }}
                        animate={{ opacity: 1, y: 0 }}
                        transition={{ delay: 0.4, duration: 0.4 }}
                        className="mt-8 flex flex-col items-center justify-center gap-3"
                    >
                        <div className="flex flex-col items-center gap-3">
                            <div className="flex items-center gap-2 px-6 py-2 rounded-full bg-white/5 border border-white/5 backdrop-blur-sm">
                                <div className="flex gap-0.5">
                                    {[...Array(5)].map((_, i) => (
                                        <Star key={i} className="w-3 h-3 fill-current text-coffee-medium drop-shadow-[0_0_5px_rgba(202,160,82,0.6)]" />
                                    ))}
                                </div>
                                <div className="w-px h-3 bg-white/10 mx-1"></div>
                                <BadgeCheck className="w-3.5 h-3.5 text-[#3897f0] fill-[#3897f0]/10" />
                                <span className="text-[10px] font-black italic text-gray-400 uppercase tracking-tighter whitespace-nowrap">
                                    {lang === 'en' ? 'verified client reviews' : 'reseñas de clientes verificadas'}
                                </span>
                            </div>
                        </div>
                    </motion.div>
                </motion.div>

                <motion.div 
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    transition={{ delay: 0.6, duration: 0.5 }}
                    className="mt-20 animate-float flex justify-center"
                >
                    <ChevronDown className="w-8 h-8 text-coffee-medium/80" />
                </motion.div>
            </div>
        </section>
    );
}
