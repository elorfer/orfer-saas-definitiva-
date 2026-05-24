'use client';

import { Music, Sparkles, Mic2, ArrowRight } from 'lucide-react';
import ProfessionalAudioPlayer from './ProfessionalAudioPlayer';

export default function AudioComparison({ lang }: { lang: 'es' | 'en' }) {
    return (
        <section id="audio-comparison" className="section-padding bg-[#050505] relative overflow-hidden border-t border-b border-white/5">
            {/* Background Decor */}
            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-full h-full bg-purple-600/5 blur-[120px] rounded-full pointer-events-none opacity-20"></div>
            
            <div className="max-w-7xl mx-auto px-4 relative z-10">
                <div className="text-center mb-16 px-4">
                    <h2 className="text-4xl md:text-6xl font-black mb-4 tracking-tighter uppercase italic py-2">
                        {lang === 'es' ? 'El Poder de la' : 'The Power of'} <span className="text-gradient pr-2">Transformación</span>
                    </h2>
                    <p className="text-gray-400 text-lg md:text-xl max-w-2xl mx-auto font-medium leading-tight">
                        {lang === 'es' 
                            ? 'Mira cómo convertimos una simple idea grabada en celular en una producción de clase mundial.' 
                            : 'See how we turn a simple mobile recording into a world-class production.'}
                    </p>
                </div>

                <div className="grid lg:grid-cols-2 gap-12 lg:gap-8 items-stretch relative">
                    {/* BEFORE - ACAPELA */}
                    <div className="relative group pt-4 flex justify-center">
                        <div className="w-full max-w-[300px]">
                            <div className="absolute top-0 left-1/2 -translate-x-1/2 z-20 flex items-center gap-2 px-5 py-1.5 bg-[#1A1A1A] text-gray-500 rounded-lg text-[10px] md:text-xs font-black italic uppercase tracking-tighter border border-white/5 shadow-2xl">
                                <Mic2 className="w-3.5 h-3.5" />
                                {lang === 'es' ? 'Antes: Acapela' : 'Before: Acapella'}
                            </div>
                            <div className="h-full rounded-xl overflow-hidden border border-white/5 bg-[#0A0A0A] transition-all group-hover:border-white/10">
                                <ProfessionalAudioPlayer 
                                    src="https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/acapela.mp3"
                                    title={lang === 'es' ? "Referencia Original" : "Original Reference"}
                                    description={lang === 'es' ? "Grabación sin procesos" : "Raw recording"}
                                    cover="https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/before-cover.png" 
                                />
                            </div>
                        </div>
                    </div>

                    {/* DECORATIVE ARROW (Desktop only) */}
                    <div className="hidden lg:flex absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-14 h-14 rounded-full bg-[#7C75FF] items-center justify-center z-30 shadow-[0_0_30px_rgba(124,117,255,0.4)] border-4 border-[#050505]">
                        <ArrowRight className="w-7 h-7 text-white" />
                    </div>

                    {/* AFTER - FINAL PRODUCTION */}
                    <div className="relative group pt-4 flex justify-center">
                        <div className="w-full max-w-[300px]">
                            <div className="absolute top-0 left-1/2 -translate-x-1/2 z-20 flex items-center gap-2 px-5 py-1.5 bg-[#7C75FF] text-white rounded-lg text-[10px] md:text-xs font-black italic uppercase tracking-tighter border border-white/20 shadow-[0_0_20px_rgba(124,117,255,0.3)]">
                                <Sparkles className="w-3.5 h-3.5" />
                                {lang === 'es' ? 'Después: Master Final' : 'After: Final Master'}
                            </div>
                            <div className="h-full rounded-xl overflow-hidden border border-[#7C75FF]/30 bg-[#0A0A0A] shadow-[0_0_50px_rgba(124,117,255,0.05)] transition-all group-hover:border-[#7C75FF]/50">
                                <ProfessionalAudioPlayer 
                                    src="https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/jardin-rosita-final.mp3"
                                    title="Jardín de Rosita"
                                    description={lang === 'es' ? "Producción Struky Completa" : "Full Struky Production"}
                                    cover="https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/after-cover.png" 
                                />
                            </div>
                        </div>
                    </div>
                </div>

                {/* Button hidden on mobile */}
                <div className="mt-20 hidden md:flex text-center justify-center">
                    <button 
                        onClick={() => document.getElementById('order-form')?.scrollIntoView({ behavior: 'smooth' })}
                        className="bg-[#8B6A5A] hover:bg-[#9E7B6B] text-black px-12 py-6 rounded-2xl text-base font-black italic uppercase tracking-tighter flex items-center gap-3 transition-all active:scale-95 shadow-2xl"
                    >
                        <Music className="w-6 h-6" />
                        {lang === 'es' ? 'Quiero mi producción así' : 'I want my production like this'}
                    </button>
                </div>
            </div>
        </section>
    );
}
