'use client';

import { useState, useRef } from 'react';
import { ShieldCheck, Zap, Music2, ChevronLeft, ChevronRight } from 'lucide-react';

export default function Benefits({ t }: { t: any }) {
    const [activeIndex, setActiveIndex] = useState(0);
    const scrollRef = useRef<HTMLDivElement>(null);
    const sectionRef = useRef<HTMLElement>(null);

    const icons = [<Music2 key="1" />, <ShieldCheck key="2" />, <Zap key="3" />];
    const data = [
        { title: t.q1, desc: t.a1 },
        { title: t.q2, desc: t.a2 },
        { title: t.q3, desc: t.a3 }
    ];

    const scrollToItem = (index: number) => {
        if (scrollRef.current) {
            const container = scrollRef.current;
            const scrollAmount = container.offsetWidth * 0.85 + 24; // card width + gap
            container.scrollTo({
                left: index * scrollAmount,
                behavior: 'smooth'
            });
            setActiveIndex(index);

            // Siempre volver a la parte principal al navegar
            if (sectionRef.current) {
                sectionRef.current.scrollIntoView({ behavior: 'smooth' });
            }
        }
    };

    const next = () => {
        if (activeIndex < data.length - 1) {
            scrollToItem(activeIndex + 1);
        } else {
            scrollToItem(0);
        }
    };

    const prev = () => {
        if (activeIndex > 0) {
            scrollToItem(activeIndex - 1);
        } else {
            scrollToItem(data.length - 1);
        }
    };

    return (
        <section ref={sectionRef} className="section-padding bg-dark-bg scroll-mt-20">
            <div className="max-w-6xl mx-auto">
                <div className="text-center mb-16">
                    <h2 className="text-3xl md:text-5xl font-bold mb-4">{t.title}</h2>
                </div>

                <div className="relative">
                    <div 
                        ref={scrollRef}
                        className="flex md:grid md:grid-cols-3 gap-6 overflow-x-auto md:overflow-visible pb-8 md:pb-0 px-4 md:px-0 snap-x snap-mandatory custom-scrollbar-hide"
                    >
                        {data.map((item, i) => (
                            <div 
                                key={i}
                                className="card-dark p-6 md:p-8 flex flex-col items-center text-center group min-w-[85%] md:min-w-0 snap-center"
                            >
                                <div className="w-14 h-14 md:w-16 md:h-16 rounded-2xl bg-coffee-medium/10 flex items-center justify-center text-coffee-medium mb-4 md:mb-6 group-hover:bg-coffee-medium group-hover:text-white transition-all duration-500">
                                    {icons[i]}
                                </div>
                                <h3 className="text-lg md:text-xl font-bold mb-3 md:mb-4">{item.title}</h3>
                                <p className="text-gray-400 text-xs md:text-sm leading-relaxed">{item.desc}</p>
                            </div>
                        ))}
                    </div>

                    {/* Navigation for Mobile */}
                    <div className="flex md:hidden items-center justify-center gap-6 mt-6">
                        <button 
                            onClick={prev}
                            className="w-10 h-10 rounded-full border border-white/10 flex items-center justify-center bg-white/5 active:bg-coffee-medium"
                        >
                            <ChevronLeft className="w-5 h-5" />
                        </button>
                        
                        <div className="flex gap-2">
                            {data.map((_, i) => (
                                <div 
                                    key={i} 
                                    className={`w-1.5 h-1.5 rounded-full transition-all duration-300 ${activeIndex === i ? 'w-4 bg-coffee-medium' : 'bg-white/20'}`} 
                                />
                            ))}
                        </div>

                        <button 
                            onClick={next}
                            className="w-10 h-10 rounded-full border border-white/10 flex items-center justify-center bg-white/5 active:bg-coffee-medium"
                        >
                            <ChevronRight className="w-5 h-5" />
                        </button>
                    </div>
                </div>
            </div>
        </section>
    );
}
