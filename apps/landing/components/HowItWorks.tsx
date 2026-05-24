'use client';

import { useState, useRef, useEffect } from 'react';
import { Edit3, Headphones, Download, ChevronLeft, ChevronRight } from 'lucide-react';
import { playTick } from '../lib/soundEngine';

export default function HowItWorks({ t }: { t: any }) {
    const [activeIndex, setActiveIndex] = useState(0);
    const scrollRef = useRef<HTMLDivElement>(null);
    const sectionRef = useRef<HTMLElement>(null);
    const videoRef = useRef<HTMLVideoElement>(null);

    useEffect(() => {
        const observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting && videoRef.current) {
                    videoRef.current.play().catch(e => console.log('Autoplay prevented:', e));
                } else if (!entry.isIntersecting && videoRef.current) {
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

    const steps = [
        { icon: <Edit3 />, title: t.s1_t, desc: t.s1_d },
        { icon: <Headphones />, title: t.s2_t, desc: t.s2_d },
        { icon: <Download />, title: t.s3_t, desc: t.s3_d }
    ];

    const handleScroll = () => {
        if (scrollRef.current) {
            const scrollPosition = scrollRef.current.scrollLeft;
            const containerWidth = scrollRef.current.offsetWidth;
            const isMobile = typeof window !== 'undefined' && window.innerWidth < 768;
            const cardWidth = isMobile ? containerWidth : (containerWidth * 0.85 + 32);
            const index = Math.round(scrollPosition / cardWidth);
            if (index !== activeIndex) {
                setActiveIndex(index);
            }
        }
    };

    const scrollToStep = (index: number) => {
        playTick();
        if (scrollRef.current) {
            const container = scrollRef.current;
            const isMobile = typeof window !== 'undefined' && window.innerWidth < 768;
            const scrollAmount = isMobile ? container.offsetWidth : (container.offsetWidth * 0.85 + 32);
            container.scrollTo({
                left: index * scrollAmount,
                behavior: 'smooth'
            });
            setActiveIndex(index);
        }
    };

    const next = () => {
        if (activeIndex < steps.length - 1) {
            scrollToStep(activeIndex + 1);
        } else {
            scrollToStep(0); // Volver al inicio
        }
    };

    const prev = () => {
        if (activeIndex > 0) {
            scrollToStep(activeIndex - 1);
        } else {
            scrollToStep(steps.length - 1); // Ir al final
        }
    };

    return (
        <section ref={sectionRef} id="how-it-works" className="section-padding relative overflow-hidden bg-black/40 scroll-mt-20 border-t border-b border-white/5">
            {/* Background Video Overlay */}
            <div className="absolute inset-0 z-0 overflow-hidden pointer-events-none">
                <div className="absolute inset-0 bg-gradient-to-b from-dark-bg via-black/35 to-dark-bg z-10"></div>
                <video 
                    ref={videoRef}
                    loop 
                    muted 
                    playsInline 
                    preload="none"
                    className="absolute inset-0 w-full h-full object-cover opacity-65"
                >
                    <source src="https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/IMG_3967.mp4" type="video/mp4" />
                    <source src="https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/IMG_3963.webm" type="video/webm" />
                </video>
            </div>

            <div className="max-w-6xl mx-auto relative z-20">
                <div className="text-center mb-12 md:mb-20">
                    <h2 className="text-3xl md:text-5xl font-black mb-4 tracking-tighter">{t.title}</h2>
                </div>

                <div className="relative">
                    <div 
                        ref={scrollRef}
                        onScroll={handleScroll}
                        className="flex md:grid md:grid-cols-3 gap-0 md:gap-12 relative overflow-x-auto md:overflow-visible pb-12 md:pb-0 px-0 md:px-0 snap-x snap-mandatory scroll-px-0 custom-scrollbar-hide"
                    >
                        {/* Connection Line (Desktop) */}
                        <div className="hidden md:block absolute top-1/4 left-0 right-0 h-0.5 bg-gradient-to-r from-transparent via-coffee-medium/20 to-transparent z-0"></div>

                        {steps.map((step, i) => (
                            <div 
                                key={i}
                                className="relative z-10 flex flex-col items-center text-center min-w-full md:min-w-0 snap-center px-6 py-8 rounded-none md:rounded-3xl bg-black/60 backdrop-blur-md border-y border-white/10 md:border md:hover:border-coffee-medium/30 transition-all duration-300 shadow-[0_10px_30px_rgba(0,0,0,0.4)]"
                            >
                                <div className="w-16 h-16 md:w-24 md:h-24 rounded-full glass-morphism flex items-center justify-center text-coffee-light mb-6 md:mb-8 relative border-2 border-coffee-medium/40 shadow-[0_0_30px_rgba(202,160,82,0.1)]">
                                    <span className="absolute -top-1 -right-1 w-7 h-7 md:w-10 md:h-10 rounded-full bg-gradient-to-br from-coffee-medium to-coffee-dark text-white text-[10px] md:text-sm font-black flex items-center justify-center shadow-xl border border-white/10">
                                        {i + 1}
                                    </span>
                                    <div className="scale-[1.2] md:scale-[1.8]">
                                        {step.icon}
                                    </div>
                                </div>
                                <h3 className="text-xl md:text-3xl font-black mb-3 tracking-tight">{step.title}</h3>
                                <p className="text-gray-200 text-xs md:text-lg max-w-xs mx-auto leading-relaxed">
                                    {step.desc}
                                </p>
                            </div>
                        ))}
                    </div>

                    {/* Botones de Navegación (Solo Móvil) */}
                    <div className="flex md:hidden items-center justify-center gap-6 mt-4">
                        <button 
                            onClick={prev}
                            className="w-12 h-12 rounded-full border border-white/10 flex items-center justify-center bg-white/5 active:bg-coffee-medium active:text-white transition-all"
                        >
                            <ChevronLeft className="w-6 h-6" />
                        </button>
                        
                        <div className="flex gap-2">
                            {steps.map((_, i) => (
                                <div 
                                    key={i} 
                                    className={`w-2 h-2 rounded-full transition-all duration-300 ${activeIndex === i ? 'w-6 bg-coffee-medium' : 'bg-white/20'}`} 
                                />
                            ))}
                        </div>

                        <button 
                            onClick={next}
                            className="w-12 h-12 rounded-full border border-white/10 flex items-center justify-center bg-white/5 active:bg-coffee-medium active:text-white transition-all"
                        >
                            <ChevronRight className="w-6 h-6" />
                        </button>
                    </div>
                </div>
            </div>
        </section>
    );
}

