'use client';

import { useState, useRef } from 'react';
import Image from 'next/image';
import { Star, Quote, BadgeCheck, ChevronLeft, ChevronRight } from 'lucide-react';
import { playTick } from '../lib/soundEngine';

export default function Testimonials({ t }: { t: any }) {
    const [activeIndex, setActiveIndex] = useState(0);
    const scrollRef = useRef<HTMLDivElement>(null);

    const sectionRef = useRef<HTMLElement>(null);
    const list = [
        { text: t.t1, author: t.t1_a, img: "https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/mateo.webp", initials: "MR" },
        { text: t.t2_t, author: t.t2_a, img: "https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/valeria.webp", initials: "VS" },
        { text: t.t3_t, author: t.t3_a, img: "https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/juan.webp", initials: "JP" },
        { text: t.t4_t, author: t.t4_a, img: "https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/sofia.png", initials: "SL" }
    ];

    const avatarColors = [
        'from-amber-500 to-orange-600',
        'from-purple-500 to-pink-600',
        'from-blue-500 to-cyan-600',
        'from-green-500 to-emerald-600',
    ];

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
        if (activeIndex < list.length - 1) {
            scrollToItem(activeIndex + 1);
        } else {
            scrollToItem(0);
        }
    };

    const prev = () => {
        if (activeIndex > 0) {
            scrollToItem(activeIndex - 1);
        } else {
            scrollToItem(list.length - 1);
        }
    };

    return (
        <section ref={sectionRef} className="section-padding bg-dark-bg overflow-hidden scroll-mt-20">
            <div className="max-w-6xl mx-auto">
                <div className="text-center mb-16">
                    <h2 className="text-3xl md:text-5xl font-bold mb-4">{t.title}</h2>
                    <p className="text-gray-500 max-w-2xl mx-auto">
                        Más de 10.000 canciones entregadas con éxito.
                    </p>
                </div>

                <div className="relative">
                    <div 
                        ref={scrollRef}
                        onScroll={handleScroll}
                        className="flex md:grid md:grid-cols-2 gap-6 overflow-x-auto md:overflow-visible pb-8 md:pb-0 px-4 md:px-0 snap-x snap-mandatory custom-scrollbar-hide"
                    >
                        {list.map((item, i) => (
                            <div 
                                key={i}
                                className="card-dark p-8 relative flex flex-col justify-between hover:bg-white/[0.04] transition-all border-white/5 flex-shrink-0 w-[85%] md:w-auto snap-center"
                            >
                                <Quote className="absolute top-6 right-8 w-10 h-10 text-coffee-medium/10 rotate-180" />
                                
                                <div className="mb-6">
                                    <div className="flex gap-1 text-coffee-medium mb-4">
                                        {[1, 2, 3, 4, 5].map(star => <Star key={star} className="w-4 h-4 fill-current" />)}
                                    </div>
                                    <p className="text-lg text-gray-300 italic leading-relaxed text-center md:text-left">
                                        "{item.text}"
                                    </p>
                                </div>

                                <div className="flex items-center justify-center md:justify-start gap-4 mt-auto">
                                    <div className="relative w-12 h-12 rounded-full overflow-hidden border-2 border-coffee-medium/40 shrink-0">
                                        <Image 
                                            src={item.img} 
                                            alt={item.author} 
                                            fill
                                            className="object-cover"
                                            quality={75}
                                            sizes="48px"
                                            onError={(e) => {
                                                const target = e.currentTarget as any;
                                                target.style.display = 'none';
                                                const parent = target.parentElement;
                                                if (parent) {
                                                    parent.innerHTML = `<div class="w-full h-full bg-gradient-to-br ${avatarColors[i % avatarColors.length]} flex items-center justify-center"><span class="text-white font-black text-sm">${item.initials}</span></div>`;
                                                }
                                            }}
                                        />
                                    </div>
                                    <div className="flex flex-col items-start">
                                        <span className="font-bold text-white text-left">{item.author}</span>
                                        <div className="flex items-center gap-1 mt-1">
                                            <span className="text-xs text-coffee-light uppercase tracking-widest font-bold">Artista Verificado</span>
                                            <BadgeCheck className="w-4 h-4 text-[#3897f0] fill-[#3897f0]/10" />
                                        </div>
                                    </div>
                                </div>
                            </div>
                        ))}
                    </div>

                    {/* Navigation for Mobile */}
                    <div className="flex md:hidden items-center justify-center gap-6 mt-8 relative z-[60]">
                        <button 
                            onClick={prev}
                            className="w-10 h-10 rounded-full border border-white/10 flex items-center justify-center bg-white/5 active:bg-coffee-medium transition-all"
                        >
                            <ChevronLeft className="w-5 h-5" />
                        </button>
                        
                        <div className="flex gap-2">
                            {list.map((_, i) => (
                                <div 
                                    key={i} 
                                    className={`w-1.5 h-1.5 rounded-full transition-all duration-300 ${activeIndex === i ? 'w-6 bg-coffee-medium' : 'bg-white/20'}`} 
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
