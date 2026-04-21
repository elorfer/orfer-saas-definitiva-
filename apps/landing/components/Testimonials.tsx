'use client';

import { useState, useRef } from 'react';
import { Star, Quote } from 'lucide-react';
import { motion } from 'framer-motion';

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

    const list = [
        { text: t.t1, author: t.t1_a, img: "https://randomuser.me/api/portraits/men/1.jpg" },
        { text: t.t2_t, author: t.t2_a, img: "https://randomuser.me/api/portraits/women/2.jpg" },
        { text: t.t3_t, author: t.t3_a, img: "https://randomuser.me/api/portraits/men/3.jpg" },
        { text: t.t4_t, author: t.t4_a, img: "https://randomuser.me/api/portraits/women/4.jpg" }
    ];

    return (
        <section className="section-padding bg-dark-bg overflow-hidden">
            <div className="max-w-6xl mx-auto">
                <div className="text-center mb-16">
                    <h2 className="text-3xl md:text-5xl font-bold mb-4">{t.title}</h2>
                    <p className="text-gray-500 max-w-2xl mx-auto">
                        Más de 500 artistas han transformado su música con nosotros.
                    </p>
                </div>

                <div 
                    ref={scrollRef}
                    onScroll={handleScroll}
                    className="flex md:grid md:grid-cols-2 gap-6 overflow-x-auto md:overflow-visible pb-12 md:pb-0 px-4 md:px-0 snap-x snap-mandatory custom-scrollbar-hide"
                >
                    {list.map((item, i) => (
                        <motion.div 
                            key={i}
                            initial={{ opacity: 1 }} // Prevent flicker on mount/scroll
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
                                <div className="w-12 h-12 rounded-full overflow-hidden border-2 border-coffee-medium/30">
                                    <img src={item.img} alt={item.author} className="w-full h-full object-cover" />
                                </div>
                                <div className="flex flex-col">
                                    <span className="font-bold text-white">{item.author}</span>
                                    <span className="text-xs text-coffee-light uppercase tracking-widest font-bold">Artista Verificado</span>
                                </div>
                            </div>
                        </motion.div>
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
