'use client';

import { useState, useRef } from 'react';
import Image from 'next/image';

export default function ComposersSection({ lang }: { lang: 'es' | 'en' }) {
    const [activeIndex, setActiveIndex] = useState(0);
    const scrollRef = useRef<HTMLDivElement>(null);

    const handleScroll = () => {
        if (scrollRef.current) {
            const scrollPosition = scrollRef.current.scrollLeft;
            const containerWidth = scrollRef.current.offsetWidth;
            const cardWidth = containerWidth * 0.8 + 24; 
            const index = Math.round(scrollPosition / cardWidth);
            if (index !== activeIndex) {
                setActiveIndex(index);
            }
        }
    };

    const composers = [
        {
            name: "Marco 'The Ghost' Ruiz",
            role: lang === 'es' ? "Especialista en Mix Urbano" : "Urban Mix Specialist",
            description: lang === 'es' ? "12 años esculpiendo el sonido del trap y reggaetón comercial." : "12 years shaping the sound of commercial trap and reggaeton.",
            image: "/images/producer_1_v2.png"
        },
        {
            name: "Elena Santacruz",
            role: lang === 'es' ? "Compositora de Estructuras Pop" : "Pop Structure Composer",
            description: lang === 'es' ? "Experta en hooks memorables y armonías vocales de alta gama." : "Expert in memorable hooks and high-end vocal harmonies.",
            image: "/images/producer_2_v2.png"
        },
        {
            name: "Julian Master",
            role: lang === 'es' ? "Ingeniero de Mastering Analógico" : "Analog Mastering Engineer",
            description: lang === 'es' ? "El guardián de los LUFS exactos para Spotify y Apple Music." : "The guardian of exact LUFS for Spotify and Apple Music.",
            image: "/images/artist_latino_3_v2.png"
        }
    ];

    return (
        <section className="section-padding bg-dark-bg/50 relative overflow-hidden">
            <div className="absolute top-0 right-0 w-1/3 h-1/3 bg-coffee-medium/5 blur-[120px] rounded-full"></div>
            
            <div className="max-w-6xl mx-auto relative z-10">
                <div className="text-center mb-16">
                    <h2 className="text-3xl md:text-5xl font-bold mb-4 font-heading">
                        {lang === 'es' ? 'Nuestros Maestros de' : 'Our Production'} <span className="text-gradient">{lang === 'es' ? 'Producción' : 'Masters'}</span>
                    </h2>
                    <p className="text-gray-400 max-w-2xl mx-auto">
                        {lang === 'es' 
                            ? 'Humanizamos la tecnología. El toque final de tu canción pasa por los mejores oídos de la industria.' 
                            : 'We humanize technology. The final touch of your song goes through the best ears in the industry.'}
                    </p>
                </div>

                <div 
                    ref={scrollRef}
                    onScroll={handleScroll}
                    className="flex md:grid md:grid-cols-3 gap-6 overflow-x-auto md:overflow-visible pb-12 md:pb-0 px-4 md:px-0 snap-x snap-mandatory custom-scrollbar-hide"
                >
                    {composers.map((composer, i) => (
                        <div 
                            key={i}
                            className="card-dark text-center flex flex-col items-center flex-shrink-0 w-[85%] md:w-auto snap-center hover:bg-white/[0.02] transition-colors duration-300"
                        >
                            <div className="relative w-32 h-32 rounded-full border-2 border-coffee-medium/30 p-1 mb-6 overflow-hidden">
                                <Image 
                                    src={composer.image} 
                                    alt={composer.name}
                                    fill
                                    className="rounded-full object-cover transition-transform duration-500 hover:scale-110"
                                />
                            </div>
                            <h3 className="text-xl font-bold mb-1">{composer.name}</h3>
                            <p className="text-coffee-light text-xs font-bold uppercase tracking-widest mb-4">{composer.role}</p>
                            <p className="text-sm text-gray-400 italic">"{composer.description}"</p>
                        </div>
                    ))}
                </div>

                {/* Mobile Indicators */}
                <div className="flex justify-center gap-2 mt-8 md:hidden">
                    {composers.map((_, i) => (
                        <div 
                            key={i}
                            className={`h-1.5 rounded-full transition-all duration-300 ${
                                activeIndex === i ? 'w-6 bg-coffee-medium' : 'w-1.5 bg-white/10'
                            }`}
                        ></div>
                    ))}
                </div>
            </div>
        </section>
    );
}
