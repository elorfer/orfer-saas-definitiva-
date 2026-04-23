'use client';

import { useState, useRef } from 'react';
import { Star, Quote, BadgeCheck } from 'lucide-react';

export default function Testimonials({ t }: { t: any }) {
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

    const avatarColors = [
        'from-amber-500 to-orange-600',
        'from-purple-500 to-pink-600',
        'from-blue-500 to-cyan-600',
        'from-green-500 to-emerald-600',
    ];

    const list = [
        { text: t.t1, author: t.t1_a, img: "/images/producer_3_v2.png", initials: "JM" },
        { text: t.t2_t, author: t.t2_a, img: "/images/artist_latina_2_v2.png", initials: "SL" },
        { text: t.t3_t, author: t.t3_a, img: "/images/artist_latino_1_v2.png", initials: "CR" },
        { text: t.t4_t, author: t.t4_a, img: "/images/artist_latina_4_v2.png", initials: "AM" }
    ];

    return (
        <section className="section-padding bg-dark-bg overflow-hidden">
            <div className="max-w-6xl mx-auto">
                <div className="text-center mb-16">
                    <h2 className="text-3xl md:text-5xl font-bold mb-4">{t.title}</h2>
                    <p className="text-gray-500 max-w-2xl mx-auto">
                        Más de 10.000 canciones entregadas con éxito.
                    </p>
                </div>

                <div 
                    ref={scrollRef}
                    onScroll={handleScroll}
                    className="flex md:grid md:grid-cols-2 gap-6 overflow-x-auto md:overflow-visible pb-12 md:pb-0 px-4 md:px-0 snap-x snap-mandatory custom-scrollbar-hide"
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
                                <p className="text-lg text-gray-300 italic leading-relaxed">
                                    "{item.text}"
                                </p>
                            </div>

                            <div className="flex items-center gap-4 mt-auto">
                                <div className="relative w-12 h-12 rounded-full overflow-hidden border-2 border-coffee-medium/40 shrink-0">
                                    <img 
                                        src={item.img} 
                                        alt={item.author} 
                                        className="w-full h-full object-cover"
                                        onError={(e) => {
                                            const target = e.currentTarget;
                                            target.style.display = 'none';
                                            const parent = target.parentElement;
                                            if (parent) {
                                                parent.innerHTML = `<div class="w-full h-full bg-gradient-to-br ${avatarColors[i]} flex items-center justify-center"><span class="text-white font-black text-sm">${item.initials}</span></div>`;
                                            }
                                        }}
                                    />
                                </div>
                                <div className="flex flex-col">
                                    <div className="flex items-center gap-1.5">
                                        <span className="font-bold text-white">{item.author}</span>
                                        <BadgeCheck className="w-4 h-4 text-[#3897f0] fill-[#3897f0]/10" />
                                    </div>
                                    <span className="text-xs text-coffee-light uppercase tracking-widest font-bold">Artista Verificado</span>
                                </div>
                            </div>
                        </div>
                    ))}
                </div>

                {/* Mobile Indicators */}
                <div className="flex justify-center gap-2 mt-4 md:hidden">
                    {list.map((_, i) => (
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
