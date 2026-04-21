'use client';

import Image from 'next/image';
import { motion } from 'framer-motion';
import { Star } from 'lucide-react';

interface HeroProps {
    t: any;
    lang: 'es' | 'en';
}

export default function Hero({ t, lang }: HeroProps) {
    return (
        <section className="relative min-h-screen flex items-center justify-center overflow-hidden pt-20">
            {/* Background */}
            <div className="absolute inset-0 z-0">
                <Image
                    src="/hero-bg.png"
                    alt="Music Studio"
                    fill
                    className="object-cover opacity-40 scale-110"
                    priority
                    quality={100}
                />
                <div className="absolute inset-0 bg-gradient-to-b from-dark-bg/20 via-dark-bg/60 to-dark-bg"></div>
            </div>

            <div className="relative z-10 max-w-6xl mx-auto px-6 text-center">
                <motion.div
                    initial={{ opacity: 0, y: 30 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ duration: 0.8 }}
                >
                    <span className="inline-block px-4 py-1.5 rounded-full bg-coffee-medium/20 text-coffee-light text-sm font-bold mb-8 border border-coffee-medium/30">
                        {t.tag}
                    </span>
                    
                    <h1 className="text-5xl md:text-8xl font-black mb-6 leading-tight tracking-tight">
                        {t.title}<br />
                        <span className="text-gradient hover:glow-text transition-all duration-500">
                            {t.subtitle}
                        </span>
                    </h1>

                    <p className="text-xl md:text-2xl text-gray-400 mb-12 max-w-3xl mx-auto leading-relaxed">
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
                        transition={{ delay: 0.8, duration: 0.8 }}
                        className="mt-10 flex flex-col items-center justify-center gap-3"
                    >
                        <div className="flex gap-1 text-[#CAA052]">
                            {[...Array(5)].map((_, i) => (
                                <Star key={i} className="w-5 h-5 fill-current" />
                            ))}
                        </div>
                        <span className="text-xs md:text-sm font-bold text-gray-400 uppercase tracking-widest">
                            {lang === 'en' ? 'More than 50 custom songs delivered' : 'Más de 50 canciones personalizadas entregadas'}
                        </span>
                    </motion.div>
                </motion.div>

                <motion.div 
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    transition={{ delay: 1.2, duration: 1 }}
                    className="mt-20 animate-float"
                >
                    <div className="w-1 h-12 rounded-full bg-gradient-to-b from-coffee-medium/80 to-transparent mx-auto"></div>
                </motion.div>
            </div>
        </section>
    );
}
