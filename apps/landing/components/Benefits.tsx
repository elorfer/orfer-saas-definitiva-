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

    const handleScroll = () => {
        if (scrollRef.current) {
            const scrollPosition = scrollRef.current.scrollLeft;
            const containerWidth = scrollRef.current.offsetWidth;
            const cardWidth = containerWidth * 0.85 + 24; // card width + gap
            const index = Math.round(scrollPosition / cardWidth);
            if (index !== activeIndex) {
                setActiveIndex(index);
            }
        }
    };

    const scrollToItem = (index: number) => {
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
        <section ref={sectionRef} className="section-padding bg-dark-bg relative overflow-hidden scroll-mt-20">
            {/* Subtle background glow */}
            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-full h-full bg-coffee-medium/5 blur-[120px] rounded-full pointer-events-none opacity-30"></div>
            
            <div className="max-w-6xl mx-auto relative z-10">
                <div className="text-center mb-16">
                    <h2 className="text-3xl md:text-5xl font-bold mb-4 tracking-tight">{t.title}</h2>
                </div>

                <div className="relative">
                    <div 
                        className="flex flex-col md:grid md:grid-cols-3 gap-6 px-4 md:px-0"
                    >
                        {data.map((item, i) => (
                            <div 
                                key={i}
                                className="card-dark p-8 md:p-10 flex flex-col items-center text-center group border-white/5 hover:border-coffee-medium/20 transition-all duration-500"
                            >
                                <div className="w-14 h-14 md:w-16 md:h-16 rounded-2xl bg-coffee-medium/10 flex items-center justify-center text-coffee-medium mb-4 md:mb-6 group-hover:bg-coffee-medium group-hover:text-white transition-all duration-500">
                                    {icons[i]}
                                </div>
                                <h3 className="text-lg md:text-xl font-bold mb-3 md:mb-4">{item.title}</h3>
                                <p className="text-gray-400 text-xs md:text-sm leading-relaxed">{item.desc}</p>
                            </div>
                        ))}
                    </div>
                </div>
            </div>
        </section>
    );
}
