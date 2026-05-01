'use client';

import { BadgeCheck } from 'lucide-react';
import { useRef, useEffect } from 'react';

export default function StudioShowcase({ lang }: { lang: 'es' | 'en' }) {
    const videoRef = useRef<HTMLVideoElement>(null);

    useEffect(() => {
        const observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting && videoRef.current) {
                    // Solo intenta reproducir si está visible
                    videoRef.current.play().catch(e => console.log('Autoplay prevented:', e));
                } else if (!entry.isIntersecting && videoRef.current) {
                    // Pausa si sale de la vista para ahorrar recursos
                    videoRef.current.pause();
                }
            });
        }, { threshold: 0.1, rootMargin: '200px' });

        if (videoRef.current) {
            observer.observe(videoRef.current);
        }

        return () => {
            if (videoRef.current) {
                observer.unobserve(videoRef.current);
            }
        };
    }, []);

    return (
        <section className="section-padding bg-dark-bg relative overflow-hidden border-t border-b border-white/5">
            <div className="absolute top-1/2 left-0 w-1/2 h-1/2 bg-coffee-dark/10 blur-[150px] rounded-full translate-y(-50%)"></div>
            
            <div className="max-w-7xl mx-auto grid lg:grid-cols-2 gap-12 items-center relative z-10">
                <div className="text-center lg:text-left flex flex-col items-center lg:items-start">
                    <h2 className="text-3xl md:text-5xl font-bold mb-6 font-heading">
                        {lang === 'es' ? 'Bienvenido a' : 'Welcome to'} <br/>
                        <div className="flex items-center justify-center lg:justify-start gap-2 mt-2">
                            <span className="text-gradient tracking-tight">Struky Studios</span>
                            <BadgeCheck className="w-8 h-8 md:w-10 md:h-10 text-[#3897f0] fill-[#3897f0]/10" />
                        </div>
                    </h2>
                    
                    <p className="text-gray-400 text-lg mb-8 leading-relaxed">
                        {lang === 'es' 
                            ? 'No somos solo un algoritmo. Detrás de cada canción generada por nuestra IA avanzada, hay un estudio físico de primer nivel equipado con hardware analógico, donde productores reales perfeccionan cada frecuencia.' 
                            : 'We are not just an algorithm. Behind every AI-generated song, there is a physical top-tier studio equipped with analog hardware, where real producers perfect every frequency.'}
                    </p>
                    
                    <ul className="space-y-5 mb-8 w-full max-w-md mx-auto lg:mx-0">
                        {[
                            lang === 'es' ? 'Equipamiento analógico de clase mundial' : 'World-class analog equipment',
                            lang === 'es' ? 'Monitoreo acústico de alta fidelidad' : 'High-fidelity acoustic monitoring',
                            lang === 'es' ? 'Sinergia perfecta entre IA y oído humano' : 'Perfect synergy between AI and human ear'
                        ].map((item, i) => (
                            <li key={i} className="flex items-center justify-center lg:justify-start gap-4 text-sm md:text-base font-medium text-gray-300 group cursor-default text-left">
                                <div className="w-8 h-8 rounded-full bg-coffee-medium/10 flex items-center justify-center shrink-0 border border-coffee-medium/20 group-hover:bg-coffee-medium/20 transition-colors shadow-[0_0_10px_rgba(202,160,82,0.1)]">
                                    <svg className="w-4 h-4 text-coffee-light" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M5 13l4 4L19 7"/></svg>
                                </div>
                                <span className="group-hover:text-white transition-colors">{item}</span>
                            </li>
                        ))}
                    </ul>
                </div>

                <div className="relative aspect-video rounded-3xl overflow-hidden shadow-2xl shadow-purple-500/10 border border-white/10 bg-black/40 group">
                    <video 
                        ref={videoRef}
                        key="studio-video"
                        loop 
                        muted 
                        playsInline 
                        preload="none"
                        className="absolute inset-0 w-full h-full object-cover"
                    >
                        <source src="https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/IMG_3967.mp4" type="video/mp4" />
                        <source src="https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/IMG_3963.webm" type="video/webm" />
                    </video>
                    <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-transparent to-transparent pointer-events-none"></div>
                </div>
            </div>
        </section>
    );
}
