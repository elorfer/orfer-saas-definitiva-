'use client';

import { motion, AnimatePresence } from 'framer-motion';
import { BadgeCheck, Zap, Mic, Check, Music, Plus } from 'lucide-react';
import { useState, useEffect, useRef } from 'react';
import { playPop, initSoundEngine } from '@/lib/soundEngine';
import Image from 'next/image';

interface HeroProps {
    t: any;
    lang: 'es' | 'en';
}

export default function Hero({ t, lang }: HeroProps) {
    const videoRef = useRef<HTMLVideoElement>(null);

    useEffect(() => {
        const handler = () => { initSoundEngine(); window.removeEventListener('click', handler); };
        window.addEventListener('click', handler, { once: true });
        return () => window.removeEventListener('click', handler);
    }, []);

    return (
        <section className="relative z-10 min-h-[90vh] md:min-h-screen flex items-center bg-black pt-20 lg:pt-36 pb-12 lg:pb-32 overflow-hidden">
            {/* Background Studio Image Overlay */}
            <div className="absolute inset-0 z-0 overflow-hidden">
                <div className="absolute inset-0 bg-gradient-to-r from-black via-black/80 to-transparent z-10 hidden lg:block"></div>
                <div className="absolute inset-0 bg-gradient-to-b from-black/60 via-transparent to-black z-10 lg:hidden"></div>
                <div className="absolute inset-0 animate-hero-drift">
                    <Image 
                        src="/examples/nuevohero.webp"
                        alt="Studio Background"
                        fill
                        priority
                        unoptimized
                        className="object-cover opacity-60 lg:opacity-80 object-center lg:object-right scale-110"
                    />
                </div>
            </div>

            {/* Hero drift animation */}
            <style jsx global>{`
                @keyframes hero-drift {
                    0% {
                        transform: scale(1) translate(0, 0);
                    }
                    33% {
                        transform: scale(1.08) translate(-1.5%, -1%);
                    }
                    66% {
                        transform: scale(1.05) translate(1%, -0.5%);
                    }
                    100% {
                        transform: scale(1) translate(0, 0);
                    }
                }
                .animate-hero-drift {
                    animation: hero-drift 25s ease-in-out infinite;
                    will-change: transform;
                }
            `}</style>

            <div className="relative z-20 max-w-7xl mx-auto px-6 w-full">
                <div className="grid lg:grid-cols-2 gap-12 items-center">
                    {/* Left Content */}
                    <motion.div
                        initial={{ opacity: 0, x: -30 }}
                        animate={{ opacity: 1, x: 0 }}
                        transition={{ duration: 0.6 }}
                        className="flex flex-col items-start text-left w-full max-w-full min-w-0"
                    >
                        {/* Logo/Tag - Optional, but following the "clean" vibe */}


                        {/* Giant Headline */}
                        <h1 className="text-5xl md:text-8xl lg:text-[80px] font-black leading-[0.9] tracking-tighter uppercase mb-6 font-heading w-full">
                            <span className="block text-white">{lang === 'es' ? 'TU LETRA' : 'YOUR LYRICS'}</span>
                            <span className="block text-white">{lang === 'es' ? 'MERECE' : 'DESERVE TO'}</span>
                            <span className="block text-coffee-medium drop-shadow-[0_0_30px_rgba(141,110,99,0.4)]">{lang === 'es' ? 'SONAR' : 'BE HEARD'}</span>
                        </h1>

                        {/* Subheadline */}
                        <p className="text-lg md:text-2xl text-gray-300 mb-6 max-w-xl font-medium leading-tight w-full">
                            {lang === 'es' 
                                ? 'Tú escribes la idea. Nosotros la convertimos en una canción profesional.' 
                                : 'You write the idea. We turn it into a professional song.'}
                        </p>

                        {/* Genres - Word-by-word Dynamic Ticker */}
                        <div className="h-8 md:h-10 mb-8 overflow-hidden">
                            <motion.div 
                                className="flex items-center gap-3 text-sm md:text-lg font-black uppercase tracking-[0.2em] text-white"
                            >
                                <Music className="w-4 h-4 md:w-6 md:h-6 text-coffee-medium fill-coffee-medium/20" />
                                <div className="flex items-center gap-3">
                                    <div className="min-w-[110px] md:min-w-[160px] flex justify-start">
                                        <GenreTicker lang={lang} />
                                    </div>
                                    <div className="w-px h-4 bg-white/20"></div>
                                    <div className="flex-shrink-0">
                                        <SongCounter lang={lang} />
                                    </div>
                                </div>
                            </motion.div>
                        </div>

                        {/* Platform Logos - Controlled Marquee */}
                        <div className="w-full max-w-full mb-2 py-1 relative">
                            <div className="flex items-center justify-start gap-8 md:gap-16 py-4">
                                {[
                                    { name: 'Spotify', color: '#1DB954', path: "M12 0C5.4 0 0 5.4 0 12s5.4 12 12 12 12-5.4 12-12S18.66 0 12 0zm5.521 17.34c-.24.359-.66.48-1.021.24-2.82-1.74-6.36-2.101-10.561-1.141-.418.122-.779-.179-.899-.539-.12-.421.18-.78.54-.9 4.56-1.021 8.52-.6 11.64 1.32.42.18.479.659.301 1.02zm1.44-3.3c-.301.42-.841.6-1.262.3-3.239-1.98-8.159-2.58-11.939-1.38-.479.12-1.02-.12-1.14-.6-.12-.48.12-1.021.6-1.141C9.6 9.9 15 10.561 18.72 12.84c.361.181.54.78.241 1.2zm.12-3.36C15.24 8.4 8.82 8.16 5.16 9.301c-.6.179-1.2-.181-1.38-.721-.18-.601.18-1.2.72-1.381 4.26-1.26 11.28-1.02 15.721 1.621.539.3.719 1.02.419 1.56-.299.421-1.02.599-1.559.3z" },
                                    { name: 'Music', color: 'white', path: "M19.006 8.252c-.021-2.483 2.033-3.676 2.126-3.731-1.154-1.685-2.943-1.913-3.578-1.939-1.516-.153-2.959.894-3.726.894-.768 0-1.97-.876-3.25-.851-1.685.025-3.238.98-4.106 2.488-1.752 3.039-.448 7.535 1.258 9.996.835 1.205 1.826 2.558 3.13 2.51 1.253-.05 1.728-.809 3.245-.809 1.516 0 1.944.809 3.268.784 1.348-.025 2.196-1.229 3.024-2.439.957-1.398 1.352-2.753 1.373-2.823-.03-.012-2.639-1.012-2.665-4.034M17.371 1.01c.683-.827 1.144-1.975.922-3.123-1.01.041-2.235.673-2.959 1.516-.648.749-1.216 1.921-.99 3.033 1.127.087 2.259-.683 2.959-1.426" },
                                    { name: 'YouTube', color: '#FF0000', path: "M12 0C5.376 0 0 5.376 0 12s5.376 12 12 12 12-5.4 12-12S18.624 0 12 0zm0 19.104c-3.924 0-7.104-3.18-7.104-7.104S8.076 4.896 12 4.896s7.104 3.18 7.104 7.104-3.18 7.104-7.104 7.104zm0-13.332c-3.432 0-6.228 2.796-6.228 6.228S8.568 18.228 12 18.228s6.228-2.796 6.228-6.228S15.432 5.772 12 5.772zm-1.4 10.14V8.46L14.8 12l-4.2 3.54z" }
                                ].map((platform, i) => (
                                    <motion.div
                                        key={platform.name}
                                        initial={{ opacity: 0, scale: 0.9, y: 10 }}
                                        animate={{ 
                                            opacity: 1, 
                                            scale: 1, 
                                            y: [0, -6, 0],
                                        }}
                                        transition={{ 
                                            duration: 0.5, 
                                            delay: i * 0.1,
                                            y: {
                                                repeat: Infinity,
                                                duration: 4,
                                                ease: "easeInOut",
                                                delay: i * 0.5
                                            }
                                        }}
                                        className="flex items-center gap-2 md:gap-3 group cursor-default will-change-transform"
                                    >
                                        <div className="relative">
                                            <div className="absolute inset-0 bg-white/5 rounded-full opacity-0 group-hover:opacity-100 transition-opacity duration-300"></div>
                                            <svg viewBox="0 0 24 24" fill={platform.color} className="w-5 h-5 md:w-8 md:h-8 relative z-10 transform group-hover:scale-110 transition-transform duration-300">
                                                <path d={platform.path} transform={platform.name === 'Music' ? "translate(0, 4)" : ""} />
                                            </svg>
                                        </div>
                                        <span className="text-white font-black text-xs md:text-xl tracking-tighter opacity-70 group-hover:opacity-100 transition-all duration-300">
                                            {platform.name}
                                        </span>
                                    </motion.div>
                                ))}
                                
                                <motion.div
                                    initial={{ opacity: 0 }}
                                    animate={{ opacity: 1 }}
                                    className="flex items-center justify-center"
                                >
                                    <div className="w-px h-6 bg-white/10 mx-2"></div>
                                    <div className="w-6 h-6 md:w-9 md:h-9 rounded-full border border-white/20 bg-white/5 flex items-center justify-center hover:border-coffee-medium/50 transition-colors">
                                        <Plus className="w-3 h-3 md:w-5 md:h-5 text-coffee-medium" strokeWidth={3} />
                                    </div>
                                </motion.div>
                            </div>
                        </div>

                        {/* Price & Time Boxes - Compact for Mobile */}
                        <div className="flex flex-row gap-2 mb-6 w-full max-w-full">
                            {/* Price Box */}
                            <div className="flex-[1] min-h-[90px] md:min-h-[140px] bg-black/60 border border-coffee-medium/40 rounded-xl md:rounded-3xl p-3 md:p-6 flex flex-col items-center justify-center relative overflow-hidden group">
                                <span className="text-[8px] md:text-xs font-black uppercase tracking-[0.2em] text-white/70">{lang === 'es' ? 'DESDE' : 'FROM'}</span>
                                <div className="flex items-end gap-1 md:gap-3">
                                    <span className="text-3xl md:text-6xl font-black text-white drop-shadow-[0_0_15px_rgba(255,255,255,0.2)] tracking-tighter leading-none">$50</span>
                                    <span className="text-[10px] md:text-2xl font-black text-[#E9DCC9] mb-1 tracking-tighter">USD</span>
                                </div>
                            </div>

                            {/* Time Box */}
                            <div className="flex-[1] min-h-[90px] md:min-h-[140px] bg-black/60 border border-white/10 rounded-xl md:rounded-3xl p-3 md:p-6 flex flex-row items-center justify-center gap-2 md:gap-6">
                                <div className="flex items-center flex-shrink-0">
                                    <Mic className="w-4 h-4 md:w-7 md:h-7 text-white fill-white/10" />
                                </div>
                                <div className="flex flex-col items-start justify-center">
                                    <span className="text-[8px] md:text-[10px] font-black uppercase tracking-tight text-white/90 leading-tight">{lang === 'es' ? 'HIT EN' : 'HIT IN'}</span>
                                    <span className="text-2xl md:text-5xl font-black text-white drop-shadow-[0_0_15px_rgba(255,255,255,0.2)] leading-none tracking-tighter">48H</span>
                                </div>
                            </div>
                        </div>

                        {/* CTA & Trust Icons */}
                        <div className="w-full flex flex-col items-center md:items-start gap-6">
                            <motion.button 
                                onClick={() => {
                                    playPop();
                                    document.getElementById('order-form')?.scrollIntoView({ behavior: 'smooth' });
                                }}
                                whileHover={{ scale: 1.05 }}
                                whileTap={{ scale: 0.95 }}
                                animate={{ x: [0, -6, 6, -6, 6, 0] }}
                                transition={{
                                    duration: 0.5,
                                    repeat: Infinity,
                                    repeatDelay: 3,
                                    ease: "easeInOut"
                                }}
                                className="w-full md:w-auto bg-gradient-to-r from-coffee-medium to-coffee-dark hover:from-coffee-medium/90 hover:to-coffee-dark/90 text-white font-black uppercase tracking-[0.1em] md:tracking-[0.2em] py-4 md:py-5 px-8 md:px-12 rounded-full transition-colors duration-300 shadow-[0_20px_40px_rgba(141,110,99,0.4)] text-[12px] md:text-lg flex items-center justify-center whitespace-nowrap z-30"
                            >
                                {lang === 'es' ? 'QUIERO MI CANCIÓN' : 'I WANT MY SONG'}
                            </motion.button>

                            {/* Compact Trust Icons */}
                            <div className="flex flex-row items-center gap-4 md:gap-8 opacity-80">
                                <div className="flex items-center gap-2">
                                    <BadgeCheck className="w-4 h-4 md:w-5 md:h-5 text-coffee-medium" />
                                    <span className="text-[8px] md:text-[10px] font-black uppercase tracking-widest text-white/90">{lang === 'es' ? 'DERECHOS 100%' : '100% RIGHTS'}</span>
                                </div>
                                <div className="w-px h-3 bg-white/20"></div>
                                <div className="flex items-center gap-2">
                                    <Zap className="w-4 h-4 md:w-5 md:h-5 text-coffee-medium" />
                                    <span className="text-[8px] md:text-[10px] font-black uppercase tracking-widest text-white/90">{lang === 'es' ? 'ENTREGA RÁPIDA' : 'FAST DELIVERY'}</span>
                                </div>
                                <div className="w-px h-3 bg-white/20"></div>
                                <div className="flex items-center gap-2">
                                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" className="w-4 h-4 md:w-5 md:h-5 text-coffee-medium">
                                        <path d="M3 12h1m2 0h1m2 0h1m2 0h1m2 0h1m2 0h1m2 0h1m2 0h1m2 0h1" />
                                        <path d="M7 8v8m4-10v12m4-14v16m4-10v4" />
                                    </svg>
                                    <span className="text-[8px] md:text-[10px] font-black uppercase tracking-widest text-white/90">{lang === 'es' ? 'PROD. REAL' : 'REAL PROD.'}</span>
                                </div>
                            </div>

                            {/* Social Proof Bar */}
                            <div className="flex items-center gap-3 mt-4">
                                <div className="flex -space-x-2">
                                    {[
                                        { initials: 'MR', gradient: 'from-amber-500 to-orange-600' },
                                        { initials: 'VS', gradient: 'from-purple-500 to-pink-600' },
                                        { initials: 'JP', gradient: 'from-blue-500 to-cyan-600' },
                                        { initials: 'SL', gradient: 'from-amber-600 to-amber-800' },
                                        { initials: 'AC', gradient: 'from-red-500 to-rose-600' },
                                    ].map((avatar, i) => (
                                        <div 
                                            key={i}
                                            className={`w-7 h-7 md:w-8 md:h-8 rounded-full border-2 border-black flex items-center justify-center text-[8px] font-black text-white bg-gradient-to-br ${avatar.gradient}`}
                                        >
                                            {avatar.initials}
                                        </div>
                                    ))}
                                </div>
                                <p className="text-[10px] md:text-xs text-gray-400 font-bold">
                                    <span className="text-white font-black">+127</span> {lang === 'es' ? 'artistas esta semana' : 'artists this week'}
                                </p>
                            </div>
                        </div>
                    </motion.div>

                    {/* Right Content - Visual Emphasis for Desktop */}
                    <motion.div
                        initial={{ opacity: 0, scale: 0.9 }}
                        animate={{ opacity: 1, scale: 1 }}
                        transition={{ duration: 0.8, delay: 0.2 }}
                        className="hidden lg:flex justify-center relative"
                    >
                        {/* Decorative floating elements could go here */}
                    </motion.div>
                </div>
            </div>
        </section>
    );
}

function SongCounter({ lang }: { lang: 'es' | 'en' }) {
    const [count, setCount] = useState(0);

    useEffect(() => {
        let start = 0;
        const end = 10000;
        const duration = 2000; // 2 seconds
        const increment = end / (duration / 16); // 60fps approx

        const timer = setInterval(() => {
            start += increment;
            if (start >= end) {
                setCount(end);
                clearInterval(timer);
            } else {
                setCount(Math.floor(start));
            }
        }, 16);

        return () => clearInterval(timer);
    }, []);

    return (
        <div className="flex items-center gap-1.5">
            <span className="text-white font-black text-sm md:text-lg tabular-nums">
                +{count.toLocaleString()}
            </span>
            <span className="text-gray-500 text-[10px] md:text-xs font-bold uppercase tracking-widest">
                {lang === 'es' ? 'CANCIONES' : 'SONGS'}
            </span>
        </div>
    );
}

function GenreTicker({ lang }: { lang: 'es' | 'en' }) {
    const genres = lang === 'es' 
        ? ["URBANO", "CORRIDOS", "SALSA", "POP", "BACHATA", "CRISTIANO", "Y MÁS"]
        : ["POP", "HIP HOP", "R&B", "EDM", "COUNTRY", "ROCK", "AND MORE"];
    const [index, setIndex] = useState(0);

    useEffect(() => {
        const timer = setInterval(() => {
            setIndex((prev) => (prev + 1) % genres.length);
        }, 2500);
        return () => clearInterval(timer);
    }, [genres.length]);

    return (
        <div className="relative inline-block overflow-hidden h-full">
            <AnimatePresence mode='wait'>
                <motion.span
                    key={genres[index]}
                    initial={{ y: 20, opacity: 0 }}
                    animate={{ y: 0, opacity: 1 }}
                    exit={{ y: -20, opacity: 0 }}
                    transition={{ duration: 0.5, ease: "easeOut" }}
                    className="block text-white font-black"
                >
                    {genres[index]}
                </motion.span>
            </AnimatePresence>
        </div>
    );
}
