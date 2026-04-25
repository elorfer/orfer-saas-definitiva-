'use client';

import { useState, useRef } from 'react';
import { Edit3, Headphones, Download, ChevronLeft, ChevronRight } from 'lucide-react';

export default function HowItWorks({ t }: { t: any }) {
    const [activeIndex, setActiveIndex] = useState(0);
    const scrollRef = useRef<HTMLDivElement>(null);
    const sectionRef = useRef<HTMLElement>(null);

    const steps = [
        { icon: <Edit3 />, title: t.s1_t, desc: t.s1_d },
        { icon: <Headphones />, title: t.s2_t, desc: t.s2_d },
        { icon: <Download />, title: t.s3_t, desc: t.s3_d }
    ];

    const scrollToStep = (index: number) => {
        if (scrollRef.current) {
            const container = scrollRef.current;
            const scrollAmount = container.offsetWidth * 0.8 + 32; // card width + gap
            container.scrollTo({
                left: index * scrollAmount,
                behavior: 'smooth'
            });
            setActiveIndex(index);

            // Siempre volver a la parte principal de la sección al navegar
            if (sectionRef.current) {
                sectionRef.current.scrollIntoView({ behavior: 'smooth' });
            }
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
        <section ref={sectionRef} id="how-it-works" className="section-padding bg-dark-card/20 scroll-mt-20">
            <div className="max-w-6xl mx-auto">
                <div className="text-center mb-20">
                    <h2 className="text-3xl md:text-5xl font-bold mb-4">{t.title}</h2>
                </div>

                <div className="relative">
                    <div 
                        ref={scrollRef}
                        className="flex md:grid md:grid-cols-3 gap-8 md:gap-12 relative overflow-x-auto md:overflow-visible pb-12 md:pb-0 px-4 md:px-0 snap-x snap-mandatory custom-scrollbar-hide"
                    >
                        {/* Connection Line (Desktop) */}
                        <div className="hidden md:block absolute top-1/4 left-0 right-0 h-0.5 bg-gradient-to-r from-transparent via-coffee-medium/20 to-transparent z-0"></div>

                        {steps.map((step, i) => (
                            <div 
                                key={i}
                                className="relative z-10 flex flex-col items-center text-center min-w-[80%] md:min-w-0 snap-center"
                            >
                                <div className="w-16 h-16 md:w-20 md:h-20 rounded-full glass-morphism flex items-center justify-center text-coffee-light mb-6 md:mb-8 relative border-2 border-coffee-medium/40">
                                    <span className="absolute -top-1 -right-1 w-6 h-6 md:w-8 md:h-8 rounded-full bg-coffee-medium text-white text-[10px] md:text-xs font-bold flex items-center justify-center shadow-lg">
                                        {i + 1}
                                    </span>
                                    {step.icon}
                                </div>
                                <h3 className="text-xl md:text-2xl font-bold mb-3 md:mb-4">{step.title}</h3>
                                <p className="text-gray-400 text-sm md:text-base max-w-xs mx-auto">{step.desc}</p>
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

