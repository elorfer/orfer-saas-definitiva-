'use client';
// Build trigger: 2026-04-26 01:29


import Image from 'next/image';
import { motion } from 'framer-motion';
import { Star, ChevronDown, BadgeCheck } from 'lucide-react';
import { useState, useEffect } from 'react';

interface HeroProps {
    t: any;
    lang: 'es' | 'en';
}

export default function Hero({ t, lang }: HeroProps) {
    const [count, setCount] = useState(0);

    useEffect(() => {
        let timer: ReturnType<typeof setInterval> | null = null;
        const delay = setTimeout(() => {
            const target = 10000;
            const duration = 1500;
            const steps = 50;
            const increment = target / steps;
            let current = 0;
            timer = setInterval(() => {
                current += increment;
                if (current >= target) {
                    setCount(target);
                    if (timer) clearInterval(timer);
                } else {
                    setCount(Math.floor(current));
                }
            }, duration / steps);
        }, 900);
        return () => {
            clearTimeout(delay);
            if (timer) clearInterval(timer);
        };
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
                />
                <div className="absolute inset-0 bg-gradient-to-b from-dark-bg/20 via-dark-bg/60 to-dark-bg"></div>
                
                {/* Accent Orbs */}
                <div className="bg-orb-1 absolute -top-20 -left-20 w-96 h-96 blur-[120px] pointer-events-none opacity-40"></div>
                <div className="bg-orb-2 absolute top-1/3 -right-20 w-80 h-80 blur-[120px] pointer-events-none opacity-30"></div>
                <div className="bg-orb-coffee absolute bottom-0 left-1/2 -translate-x-1/2 w-[600px] h-[400px] blur-[150px] pointer-events-none opacity-20"></div>
            </div>

            <div className="relative z-10 max-w-6xl mx-auto px-6 text-center">
                <motion.div
                    initial={{ opacity: 0, y: 30 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ duration: 0.4 }}
                >
                    <span className="inline-block px-4 py-1.5 rounded-full bg-coffee-medium/20 text-coffee-light text-sm font-bold mb-8 border border-coffee-medium/30">
                        {t.tag}
                    </span>
                    
                    <h1 className="text-5xl md:text-8xl font-black mb-6 leading-tight tracking-tight">
                        {t.title}<br />
                        <span className="text-gradient hover:glow-text transition-all duration-300">
                            {t.subtitle}
                        </span>
                    </h1>

                    <p className="text-xl md:text-2xl text-gray-300 mb-12 max-w-3xl mx-auto leading-relaxed">
                        {t.description}
                    </p>

                    <div className="flex flex-col sm:flex-row items-center justify-center gap-6">
                        <button 
                            onClick={() => document.getElementById('order-form')?.scrollIntoView({ behavior: 'smooth' })}
                            className="btn-primary text-xl px-12 py-5"
                        >
                            {t.cta}
                        </button>
                        <a 
                            href="#examples" 
                            className="btn-secondary text-xl px-10 py-5"
                        >
                            {t.listen}
                        </a>
                    </div>

                    <motion.div 
                        initial={{ opacity: 0, y: 10 }}
                        animate={{ opacity: 1, y: 0 }}
                        transition={{ delay: 0.4, duration: 0.4 }}
                        className="mt-10 flex flex-col items-center justify-center gap-3"
                    >
                        <div className="flex flex-col items-center gap-3 mt-4">
                            <div className="flex items-end gap-1.5 leading-none">
                                <span className="text-6xl md:text-7xl font-black text-gradient tabular-nums">
                                    {count.toLocaleString(lang === 'es' ? 'es-ES' : 'en-US')}
                                </span>
                                <span className="text-3xl md:text-4xl font-black text-coffee-medium mb-1.5">+</span>
                            </div>
                            <div className="flex items-center gap-2 px-6 py-2 rounded-full bg-white/5 border border-white/5 backdrop-blur-sm">
                                <div className="flex gap-0.5">
                                    {[...Array(5)].map((_, i) => (
                                        <Star key={i} className="w-3 h-3 fill-current text-coffee-medium drop-shadow-[0_0_5px_rgba(202,160,82,0.6)]" />
                                    ))}
                                </div>
                                <div className="w-px h-3 bg-white/10 mx-1"></div>
                                <BadgeCheck className="w-3.5 h-3.5 text-[#3897f0] fill-[#3897f0]/10" />
                                <span className="text-[10px] font-black text-gray-400 uppercase tracking-[0.25em] whitespace-nowrap">
                                    {lang === 'en' ? 'songs delivered' : 'canciones entregadas'}
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
