'use client';

import { useState, useRef } from 'react';
import Image from 'next/image';
import { motion } from 'framer-motion';
import { BadgeCheck, ChevronLeft, ChevronRight } from 'lucide-react';
import { playTick } from '../lib/soundEngine';

export default function ComposersSection({ lang }: { lang: 'es' | 'en' }) {
    const [activeIndex, setActiveIndex] = useState(0);
    const scrollRef = useRef<HTMLDivElement>(null);
    const sectionRef = useRef<HTMLElement>(null);

    const handleScroll = () => {
        if (scrollRef.current) {
            const scrollPosition = scrollRef.current.scrollLeft;
            const containerWidth = scrollRef.current.offsetWidth;
            const cardWidth = containerWidth * 0.85 + 24; 
            const index = Math.round(scrollPosition / cardWidth);
            if (index !== activeIndex) {
                setActiveIndex(index);
            }
        }
    };

    const scrollToItem = (index: number) => {
        playTick();
        if (scrollRef.current) {
            const container = scrollRef.current;
            const scrollAmount = container.offsetWidth * 0.85 + 24;
            container.scrollTo({
                left: index * scrollAmount,
                behavior: 'smooth'
            });
            setActiveIndex(index);
        }
    };

    const next = () => {
        if (activeIndex < composers.length - 1) {
            scrollToItem(activeIndex + 1);
        } else {
            scrollToItem(0);
        }
    };

    const prev = () => {
        if (activeIndex > 0) {
            scrollToItem(activeIndex - 1);
        } else {
            scrollToItem(composers.length - 1);
        }
    };

    const composers = [
        {
            name: "Marco 'The Ghost' Ruiz",
            role: lang === 'es' ? "Especialista en Mix Urbano" : "Urban Mix Specialist",
            description: lang === 'es' ? "12 años esculpiendo el sonido del trap y reggaetón comercial." : "12 years shaping the sound of commercial trap and reggaeton.",
            image: "https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/producermarcos.webp"
        },
        {
            name: "Elena Santacruz",
            role: lang === 'es' ? "Ingeniera de Arreglos Vocales" : "Vocal Arrangement Engineer",
            description: lang === 'es' ? "Experta en crear armonías y capas vocales que envuelven al oyente." : "Expert in creating vocal harmonies and layers that surround the listener.",
            image: "https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/elena.webp"
        },
        {
            name: "Julian Master",
            role: lang === 'es' ? "Ingeniero de Mastering Analógico" : "Analog Mastering Engineer",
            description: lang === 'es' ? "El guardián de los LUFS exactos para Spotify y Apple Music." : "The guardian of exact LUFS for Spotify and Apple Music.",
            image: "https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/julian%20master.webp"
        }
    ];

    return (
        <section ref={sectionRef} className="section-padding bg-dark-bg/50 relative overflow-hidden scroll-mt-20">
            <div className="absolute top-0 right-0 w-1/3 h-1/3 bg-coffee-medium/5 blur-[120px] rounded-full"></div>
            
            <div className="max-w-6xl mx-auto relative z-10">
                {/* Mascot - Centered Above Title */}
                <div className="relative w-56 h-56 lg:w-72 lg:h-72 mx-auto mb-6 z-20 drop-shadow-[0_20px_30px_rgba(0,0,0,0.6)] pointer-events-none animate-float">
                    <Image 
                        src="https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/mascot-checkout.webp" 
                        alt="Struky Mascot" 
                        fill
                        className="object-contain drop-shadow-[0_0_20px_rgba(202,160,82,0.2)]"
                        sizes="(max-width: 768px) 224px, 288px"
                        unoptimized
                    />
                </div>
                <div className="text-center mb-16">
                    <h2 className="text-3xl md:text-5xl font-bold mb-4 font-heading">
                        {lang === 'es' ? 'Tu Equipo de' : 'Your Elite'} <span className="text-gradient">{lang === 'es' ? 'Élite Musical' : 'Production Team'}</span>
                    </h2>
                    <p className="text-gray-400 max-w-2xl mx-auto">
                        {lang === 'es' 
                            ? 'Tú pones la letra y el alma. Nosotros ponemos los mejores oídos y tecnología de la industria para que suenes como un profesional.' 
                            : 'You provide the lyrics and the soul. We provide the industry\'s best ears and technology so you sound like a professional.'}
                    </p>
                </div>

                <div className="relative">
                    <div 
                        ref={scrollRef}
                        onScroll={handleScroll}
                        className="flex md:grid md:grid-cols-3 gap-6 overflow-x-auto md:overflow-visible pb-12 md:pb-0 px-6 md:px-0 snap-x snap-mandatory scroll-px-6 custom-scrollbar-hide"
                    >
                        {composers.map((composer, i) => (
                            <div 
                                key={i}
                                className="card-dark text-center flex flex-col items-center flex-shrink-0 w-[88%] md:w-auto snap-center hover:bg-white/[0.02] transition-colors duration-300"
                            >
                                <div className="relative w-32 h-32 rounded-full border-2 border-coffee-medium/30 p-1 mb-6 overflow-hidden">
                                    <Image 
                                        src={composer.image} 
                                        alt={composer.name}
                                        fill
                                        className="rounded-full object-cover transition-transform duration-500 hover:scale-110"
                                        sizes="128px"
                                        unoptimized
                                    />
                                </div>
                                <h3 className="text-xl font-bold mb-1 flex items-center gap-1.5">
                                    {composer.name}
                                    <BadgeCheck className="w-5 h-5 text-[#3897f0] fill-[#3897f0]/10" />
                                </h3>
                                <p className="text-coffee-light text-xs font-bold uppercase tracking-widest mb-4">{composer.role}</p>
                                <p className="text-sm text-gray-400 italic">"{composer.description}"</p>
                            </div>
                        ))}
                    </div>

                    {/* Mobile Navigation */}
                    <div className="flex md:hidden items-center justify-center gap-6 mt-8 relative z-[60]">
                        <button 
                            onClick={prev}
                            className="w-10 h-10 rounded-full border border-white/10 flex items-center justify-center bg-white/5 active:bg-coffee-medium transition-all"
                        >
                            <ChevronLeft className="w-5 h-5" />
                        </button>
                        
                        <div className="flex gap-2">
                            {composers.map((_, i) => (
                                <div 
                                    key={i} 
                                    className={`w-1.5 h-1.5 rounded-full transition-all duration-300 ${activeIndex === i ? 'w-4 bg-coffee-medium' : 'bg-white/20'}`} 
                                />
                            ))}
                        </div>

                        <button 
                            onClick={next}
                            className="w-10 h-10 rounded-full border border-white/10 flex items-center justify-center bg-white/5 active:bg-coffee-medium transition-all"
                        >
                            <ChevronRight className="w-5 h-5" />
                        </button>
                    </div>
                </div>


            </div>
        </section>
    );
}
