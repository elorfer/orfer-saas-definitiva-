'use client';

import { motion } from 'framer-motion';
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
        <section className="relative min-h-screen flex items-center bg-black overflow-hidden pt-20 lg:pt-36 pb-24 lg:pb-10">
            {/* Background Studio Image Overlay */}
            <div className="absolute inset-0 z-0">
                <div className="absolute inset-0 bg-gradient-to-r from-black via-black/80 to-transparent z-10 hidden lg:block"></div>
                <div className="absolute inset-0 bg-gradient-to-b from-black/60 via-transparent to-black z-10 lg:hidden"></div>
                <Image 
                    src="/examples/nuevohero.webp"
                    alt="Studio Background"
                    fill
                    priority
                    className="object-cover opacity-60 lg:opacity-80 object-center lg:object-right"
                    sizes="(max-width: 1024px) 100vw, 800px"
                />
            </div>

            <div className="relative z-20 max-w-7xl mx-auto px-6 w-full">
                <div className="grid lg:grid-cols-2 gap-12 items-center">
                    {/* Left Content */}
                    <motion.div
                        initial={{ opacity: 0, x: -30 }}
                        animate={{ opacity: 1, x: 0 }}
                        transition={{ duration: 0.6 }}
                        className="flex flex-col items-start text-left"
                    >
                        {/* Logo/Tag - Optional, but following the "clean" vibe */}


                        {/* Giant Headline */}
                        <h1 className="text-6xl md:text-8xl lg:text-[80px] font-black leading-[0.9] tracking-tighter uppercase mb-6 font-heading">
                            <span className="block text-white">TU LETRA</span>
                            <span className="block text-white">MERECE</span>
                            <span className="block text-spotify-green drop-shadow-[0_0_30px_rgba(29,185,84,0.4)]">SONAR</span>
                        </h1>

                        {/* Subheadline */}
                        <p className="text-xl md:text-2xl text-gray-300 mb-8 max-w-xl font-medium leading-tight">
                            {lang === 'es' 
                                ? 'Tú escribes la idea. Nosotros la convertimos en una canción profesional.' 
                                : 'You write the idea. We turn it into a professional song.'}
                        </p>

                        {/* Genres */}
                        <div className="flex flex-wrap gap-x-4 gap-y-2 mb-10 text-xs md:text-sm font-black uppercase tracking-[0.2em] text-white/80">
                            <span>URBANO</span>
                            <span className="text-spotify-green">•</span>
                            <span>CORRIDOS</span>
                            <span className="text-spotify-green">•</span>
                            <span>SALSA</span>
                            <span className="text-spotify-green">•</span>
                            <span>POP</span>
                            <span className="text-spotify-green">•</span>
                            <span>BACHATA</span>
                            <span className="text-spotify-green">•</span>
                            <span>CRISTIANO</span>
                            <span className="text-spotify-green">•</span>
                            <span>Y MÁS</span>
                        </div>

                        {/* Platform Logos - More compact for mobile */}
                        <div className="flex items-center justify-start gap-4 md:gap-8 mb-6 md:mb-10 flex-nowrap overflow-x-auto custom-scrollbar-hide">
                            <div className="flex items-center gap-2 flex-shrink-0">
                                <svg viewBox="0 0 24 24" fill="#1DB954" className="w-5 h-5 md:w-7 md:h-7">
                                    <path d="M12 0C5.4 0 0 5.4 0 12s5.4 12 12 12 12-5.4 12-12S18.66 0 12 0zm5.521 17.34c-.24.359-.66.48-1.021.24-2.82-1.74-6.36-2.101-10.561-1.141-.418.122-.779-.179-.899-.539-.12-.421.18-.78.54-.9 4.56-1.021 8.52-.6 11.64 1.32.42.18.479.659.301 1.02zm1.44-3.3c-.301.42-.841.6-1.262.3-3.239-1.98-8.159-2.58-11.939-1.38-.479.12-1.02-.12-1.14-.6-.12-.48.12-1.021.6-1.141C9.6 9.9 15 10.561 18.72 12.84c.361.181.54.78.241 1.2zm.12-3.36C15.24 8.4 8.82 8.16 5.16 9.301c-.6.179-1.2-.181-1.38-.721-.18-.601.18-1.2.72-1.381 4.26-1.26 11.28-1.02 15.721 1.621.539.3.719 1.02.419 1.56-.299.421-1.02.599-1.559.3z"/>
                                </svg>
                                <span className="text-white font-black text-sm md:text-xl tracking-tighter">Spotify</span>
                            </div>
                            <div className="w-px h-4 bg-white/20 flex-shrink-0"></div>
                            <div className="flex items-center gap-2 flex-shrink-0">
                                <svg viewBox="0 0 24 24" fill="white" className="w-5 h-5 md:w-7 md:h-7">
                                    <path d="M17.057 10.768c-.021-2.483 2.033-3.676 2.126-3.731-1.154-1.685-2.943-1.913-3.578-1.939-1.516-.153-2.959.894-3.726.894-.768 0-1.97-.876-3.25-.851-1.685.025-3.238.98-4.106 2.488-1.752 3.039-.448 7.535 1.258 9.996.835 1.205 1.826 2.558 3.13 2.51 1.253-.05 1.728-.809 3.245-.809 1.516 0 1.944.809 3.268.784 1.348-.025 2.196-1.229 3.024-2.439.957-1.398 1.352-2.753 1.373-2.823-.03-.012-2.639-1.012-2.665-4.034M15.421 3.51c.683-.827 1.144-1.975.922-3.123-1.01.041-2.235.673-2.959 1.516-.648.749-1.216 1.921-.99 3.033 1.127.087 2.259-.683 2.959-1.426"/>
                                </svg>
                                <span className="text-white font-black text-sm md:text-xl tracking-tighter">Music</span>
                            </div>
                            <div className="w-px h-4 bg-white/20 flex-shrink-0"></div>
                            <div className="flex items-center gap-2 flex-shrink-0">
                                <svg viewBox="0 0 24 24" fill="#FF0000" className="w-5 h-5 md:w-7 md:h-7">
                                    <path d="M12 0C5.376 0 0 5.376 0 12s5.376 12 12 12 12-5.376 12-12S18.624 0 12 0zm0 19.104c-3.924 0-7.104-3.18-7.104-7.104S8.076 4.896 12 4.896s7.104 3.18 7.104 7.104-3.18 7.104-7.104 7.104zm0-13.332c-3.432 0-6.228 2.796-6.228 6.228S8.568 18.228 12 18.228s6.228-2.796 6.228-6.228S15.432 5.772 12 5.772zM9.684 15.54V8.46L15.816 12l-6.132 3.54z"/>
                                </svg>
                                <span className="text-white font-black text-sm md:text-xl tracking-tighter">YouTube Music</span>
                            </div>
                            <div className="w-px h-4 bg-white/20 flex-shrink-0"></div>
                            <div className="flex items-center justify-center flex-shrink-0">
                                <div className="w-7 h-7 md:w-9 md:h-9 rounded-full border border-white/20 bg-white/5 flex items-center justify-center">
                                    <Plus className="w-4 h-4 md:w-5 md:h-5 text-spotify-green" strokeWidth={3} />
                                </div>
                            </div>
                        </div>

                        {/* Price & Time Boxes - Optimized for Desktop Grid */}
                        <div className="flex flex-row gap-2 md:gap-4 mb-6 md:mb-10 w-full max-w-xl lg:max-w-none overflow-hidden px-1 md:px-0">
                            {/* Price Box */}
                            <div className="flex-[1.6] min-h-[120px] md:min-h-[180px] lg:min-h-[140px] bg-black/60 border border-spotify-green/40 rounded-2xl md:rounded-3xl p-2 md:p-6 lg:p-4 flex flex-col items-center justify-center relative overflow-hidden group">
                                <span className="text-[10px] md:text-xs font-black uppercase tracking-[0.1em] md:tracking-[0.4em] text-white/70 mb-1 lg:mb-0">DESDE</span>
                                <div className="flex items-end gap-1 md:gap-3 lg:gap-2">
                                    <span className="text-5xl md:text-8xl lg:text-6xl font-black text-spotify-green tracking-tighter leading-none">$50</span>
                                    <span className="text-base md:text-4xl lg:text-2xl font-black text-[#E9DCC9] mb-1 md:mb-2 lg:mb-1 tracking-tighter">USD</span>
                                </div>
                            </div>

                            {/* Time Box */}
                            <div className="flex-[1.4] min-h-[120px] md:min-h-[180px] lg:min-h-[140px] bg-black/60 border border-white/10 rounded-2xl md:rounded-3xl p-2 md:p-6 lg:p-4 flex flex-row items-center justify-center gap-3 md:gap-6 group">
                                <div className="flex items-center flex-shrink-0">
                                    <div className="w-[1.5px] h-6 md:w-1 md:h-8 bg-spotify-green/50 rounded-full visualizer-bar mx-[0.5px] md:mx-[1px]" style={{ animationDelay: '0.1s' }}></div>
                                    <div className="relative mx-1 md:mx-2">
                                        <div className="w-10 h-16 md:w-14 md:h-24 lg:w-10 lg:h-16 rounded-xl md:rounded-[30px] lg:rounded-[20px] border border-spotify-green/60 flex items-center justify-center bg-black/40">
                                            <Mic className="w-5 h-5 md:w-7 md:h-7 lg:w-5 lg:h-5 text-spotify-green fill-spotify-green/10" />
                                        </div>
                                    </div>
                                    <div className="w-[1.5px] h-6 md:w-1 md:h-8 bg-spotify-green/50 rounded-full visualizer-bar mx-[0.5px] md:mx-[1px]" style={{ animationDelay: '0.2s' }}></div>
                                </div>
                                <div className="flex flex-col items-start justify-center">
                                    <div className="flex flex-col mb-1 lg:mb-0">
                                        <span className="text-[9px] md:text-xs lg:text-[8px] font-black uppercase tracking-tight text-white/90 leading-tight">DE NOTA</span>
                                        <span className="text-[9px] md:text-xs lg:text-[8px] font-black uppercase tracking-tight text-white/90 leading-tight">DE VOZ</span>
                                        <span className="text-[9px] md:text-xs lg:text-[8px] font-black uppercase tracking-tight text-white/90 leading-tight">A HIT EN</span>
                                    </div>
                                    <span className="text-3xl md:text-5xl lg:text-5xl font-black text-spotify-green leading-none tracking-tighter">48H</span>
                                </div>
                            </div>
                        </div>

                        {/* CTA */}
                        <button 
                            onClick={() => {
                                playPop();
                                document.getElementById('order-form')?.scrollIntoView({ behavior: 'smooth' });
                            }}
                            className="w-full sm:w-auto bg-spotify-green hover:bg-[#1ed760] text-black font-black uppercase tracking-[0.1em] md:tracking-[0.2em] py-5 md:py-6 lg:py-5 px-8 md:px-16 lg:px-12 rounded-full transition-all hover:scale-105 active:scale-95 shadow-[0_20px_40px_rgba(29,185,84,0.4)] mb-8 md:mb-12 text-[13px] sm:text-base md:text-xl lg:text-lg leading-relaxed flex items-center justify-center whitespace-nowrap"
                        >
                            {lang === 'es' ? 'QUIERO MI CANCIÓN' : 'I WANT MY SONG'}
                        </button>
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

            {/* Bottom Trust Bar - More impactful size */}
            <div className="absolute bottom-0 left-0 right-0 z-30 bg-black/95 border-t border-white/5 py-6 md:py-12">
                <div className="max-w-7xl mx-auto px-2 md:px-6">
                    <div className="flex flex-row justify-center items-center gap-3 md:gap-24">
                        <div className="flex flex-col md:flex-row items-center gap-2 md:gap-6 group text-center md:text-left">
                            <div className="w-10 h-10 md:w-16 md:h-16 rounded-full bg-spotify-green/5 flex items-center justify-center border border-spotify-green/10">
                                <BadgeCheck className="w-5 h-5 md:w-8 md:h-8 text-spotify-green" />
                            </div>
                            <div className="flex flex-col">
                                <span className="text-[9px] md:text-xs font-black uppercase tracking-widest text-white/90">DERECHOS</span>
                                <span className="text-[9px] md:text-xs font-black uppercase tracking-widest text-white/90">100% TUYOS</span>
                            </div>
                        </div>

                        <div className="w-px h-10 md:h-16 bg-white/10"></div>

                        <div className="flex flex-col md:flex-row items-center gap-2 md:gap-6 group text-center md:text-left">
                            <div className="w-10 h-10 md:w-16 md:h-16 rounded-full bg-spotify-green/5 flex items-center justify-center border border-spotify-green/10">
                                <Zap className="w-5 h-5 md:w-8 md:h-8 text-spotify-green fill-spotify-green/10" />
                            </div>
                            <div className="flex flex-col">
                                <span className="text-[9px] md:text-xs font-black uppercase tracking-widest text-white/90">ENTREGA</span>
                                <span className="text-[9px] md:text-xs font-black uppercase tracking-widest text-white/90">RÁPIDA</span>
                            </div>
                        </div>

                        <div className="w-px h-10 md:h-16 bg-white/10"></div>

                        <div className="flex flex-col md:flex-row items-center gap-2 md:gap-6 group text-center md:text-left">
                            <div className="w-10 h-10 md:w-16 md:h-16 rounded-full bg-spotify-green/5 flex items-center justify-center border border-spotify-green/10">
                                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" className="w-5 h-5 md:w-8 md:h-8 text-spotify-green">
                                    <path d="M3 12h1m2 0h1m2 0h1m2 0h1m2 0h1m2 0h1m2 0h1m2 0h1" />
                                    <path d="M7 8v8m4-10v12m4-14v16m4-10v4" />
                                </svg>
                            </div>
                            <div className="flex flex-col">
                                <span className="text-[9px] md:text-xs font-black uppercase tracking-widest text-white/90">PROD.</span>
                                <span className="text-[9px] md:text-xs font-black uppercase tracking-widest text-white/90">REALES</span>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </section>
    );
}
