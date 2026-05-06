'use client';

import { motion, AnimatePresence } from 'framer-motion';
import Image from 'next/image';
import { Calendar, Award, Globe, Music, X } from 'lucide-react';
import { useState } from 'react';

interface Event {
    id: number;
    year: string;
    title: string;
    description: string;
    image: string;
    icon: React.ReactNode;
}

const events: Event[] = [
    {
        id: 1,
        year: "2022",
        title: "El Origen de un Sueño",
        description: "Nace la Fundación Struky con la misión de democratizar la producción musical de alta gama para talentos sin recursos económicos. Empezamos con un solo micrófono y muchas ganas de cambiar el mundo.",
        image: "https://images.unsplash.com/photo-1598488035139-bdbb2231ce04?auto=format&fit=crop&q=80&w=800",
        icon: <Calendar className="w-4 h-4" />
    },
    {
        id: 2,
        year: "2023",
        title: "Primer Hit Social",
        description: "Juan, un joven compositor apoyado por la fundación, logra posicionar su primera canción producida por Struky en las listas locales, demostrando que la calidad no depende del presupuesto.",
        image: "https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/juan.webp",
        icon: <Music className="w-4 h-4" />
    },
    {
        id: 3,
        year: "2023",
        title: "Hito de 100 Canciones",
        description: "Alcanzamos la meta de 100 producciones entregadas gratuitamente. Cada canción representa una familia impactada y un sueño musical que ahora es profesional.",
        image: "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?auto=format&fit=crop&q=80&w=800",
        icon: <Award className="w-4 h-4" />
    },
    {
        id: 5,
        year: "2024",
        title: "Impacto Sin Fronteras",
        description: "La música de nuestros artistas empieza a sonar internacionalmente. Sofia es nuestra primera artista en ser entrevistada por medios fuera del país gracias a su producción con Struky.",
        image: "https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/sofia.png",
        icon: <Globe className="w-4 h-4" />
    }
];

export default function MemorableEvents({ lang }: { lang: 'es' | 'en' }) {
    const [selectedId, setSelectedId] = useState<number | null>(null);

    return (
        <section id="foundation" className="section-padding bg-dark-bg relative overflow-hidden py-32">
            <div className="max-w-4xl mx-auto px-4 relative z-10">
                <div className="text-center mb-24">
                    <motion.h2 
                        initial={{ opacity: 0, y: 20 }}
                        whileInView={{ opacity: 1, y: 0 }}
                        viewport={{ once: true }}
                        className="text-4xl md:text-7xl font-black text-white tracking-tighter uppercase mb-6"
                    >
                        {lang === 'es' ? 'Hechos Memorables' : 'Memorable Events'}
                    </motion.h2>
                    <motion.p 
                        initial={{ opacity: 0 }}
                        whileInView={{ opacity: 1 }}
                        viewport={{ once: true }}
                        transition={{ delay: 0.2 }}
                        className="text-coffee-medium text-[10px] md:text-xs font-black uppercase tracking-[0.4em]"
                    >
                        {lang === 'es' ? 'Toca para descubrir nuestra historia' : 'Tap to discover our story'}
                    </motion.p>
                </div>

                {/* UNIFIED SNAKE PATH TIMELINE */}
                <div className="relative">
                    {/* Central vertical line base (visible on all) */}
                    <div className="absolute left-1/2 -translate-x-1/2 top-0 bottom-0 w-[1px] bg-white/5" />

                    <div className="space-y-16 md:space-y-32">
                        {events.map((event, index) => {
                            const isEven = index % 2 === 0;
                            const isLast = index === events.length - 1;

                            return (
                                <div 
                                    key={event.id}
                                    className={`relative flex items-center w-full ${isEven ? 'justify-start' : 'justify-end'}`}
                                >
                                    {/* SNAKE CONNECTOR (Animated Path) - NOW UNIFIED */}
                                    {!isLast && (
                                        <div className="absolute top-1/2 left-0 right-0 h-40 md:h-64 pointer-events-none z-0">
                                            <svg className="w-full h-full overflow-visible" viewBox="0 0 100 100" preserveAspectRatio="none">
                                                <motion.path 
                                                    d={isEven 
                                                        ? "M 25 50 C 50 50, 50 150, 75 150" 
                                                        : "M 75 50 C 50 50, 50 150, 25 150"
                                                    }
                                                    fill="none"
                                                    stroke="white"
                                                    strokeWidth="0.5"
                                                    strokeOpacity="0.1"
                                                />
                                                <motion.path 
                                                    d={isEven 
                                                        ? "M 25 50 C 50 50, 50 150, 75 150" 
                                                        : "M 75 50 C 50 50, 50 150, 25 150"
                                                    }
                                                    fill="none"
                                                    stroke="white"
                                                    strokeWidth="1.5"
                                                    strokeDasharray="10 20"
                                                    animate={{ strokeDashoffset: [-30, 0] }}
                                                    transition={{ duration: 2, repeat: Infinity, ease: "linear" }}
                                                    className="drop-shadow-[0_0_8px_rgba(255,255,255,0.8)]"
                                                />
                                            </svg>
                                        </div>
                                    )}

                                    {/* The Card */}
                                    <motion.div
                                        layoutId={`card-${event.id}`}
                                        onClick={() => setSelectedId(event.id)}
                                        initial={{ opacity: 0, scale: 0.9 }}
                                        whileInView={{ opacity: 1, scale: 1 }}
                                        viewport={{ once: true, margin: "-50px" }}
                                        className="relative w-[75%] md:w-[45%] aspect-[16/10] rounded-2xl overflow-hidden cursor-pointer group bg-dark-card border border-white/10 shadow-2xl z-20"
                                    >
                                        <Image 
                                            src={event.image}
                                            alt={event.title}
                                            fill
                                            className="object-cover opacity-50 group-hover:opacity-100 transition-all duration-1000 group-hover:scale-110"
                                            unoptimized={event.image.startsWith('http')}
                                        />
                                        <div className="absolute inset-0 bg-gradient-to-t from-black via-black/20 to-transparent" />
                                        
                                        <div className="absolute bottom-4 left-5 right-5 md:bottom-6 md:left-8 md:right-8">
                                            <span className="text-coffee-medium font-black text-[9px] md:text-xs mb-1 block uppercase tracking-widest">{event.year}</span>
                                            <h4 className="text-[13px] md:text-xl font-black text-white uppercase leading-tight group-hover:text-coffee-light transition-colors">{event.title}</h4>
                                        </div>

                                        {/* Node Dot on Card Edge (Desktop/Mobile) */}
                                        <div className={`absolute top-1/2 -translate-y-1/2 w-2 h-2 rounded-full bg-white shadow-[0_0_10px_white] z-30 ${isEven ? 'right-0' : 'left-0'}`} />
                                    </motion.div>
                                </div>
                            );
                        })}
                    </div>
                </div>

                {/* Expansion Overlay */}
                <AnimatePresence>
                    {selectedId && (
                        <>
                            <motion.div
                                initial={{ opacity: 0 }}
                                animate={{ opacity: 1 }}
                                exit={{ opacity: 0 }}
                                onClick={() => setSelectedId(null)}
                                className="fixed inset-0 bg-black/98 backdrop-blur-xl z-[100] cursor-zoom-out"
                            />
                            <div className="fixed inset-0 z-[110] flex items-center justify-center p-4 md:p-8 pointer-events-none">
                                <motion.div
                                    layoutId={`card-${selectedId}`}
                                    className="bg-dark-bg w-full max-w-4xl max-h-[85vh] rounded-3xl overflow-hidden pointer-events-auto shadow-2xl border border-white/10 flex flex-col"
                                >
                                    <div className="relative h-[250px] md:h-[450px] w-full shrink-0">
                                        <Image 
                                            src={events.find(e => e.id === selectedId)?.image || ''}
                                            alt="Expanded"
                                            fill
                                            className="object-cover"
                                            unoptimized={events.find(e => e.id === selectedId)?.image.startsWith('http')}
                                        />
                                        <button 
                                            onClick={() => setSelectedId(null)}
                                            className="absolute top-6 right-6 w-10 h-10 rounded-full bg-black/50 backdrop-blur-md flex items-center justify-center text-white hover:bg-coffee-medium transition-colors"
                                        >
                                            <X className="w-6 h-6" />
                                        </button>
                                        <div className="absolute bottom-0 left-0 right-0 h-32 bg-gradient-to-t from-dark-bg to-transparent" />
                                    </div>

                                    <div className="p-8 md:p-16 overflow-y-auto">
                                        <div className="mb-10 text-center md:text-left">
                                            <span className="text-coffee-medium font-black text-sm md:text-xl mb-2 block uppercase tracking-widest">{events.find(e => e.id === selectedId)?.year}</span>
                                            <h3 className="text-3xl md:text-6xl font-black text-white uppercase tracking-tighter leading-none">
                                                {events.find(e => e.id === selectedId)?.title}
                                            </h3>
                                        </div>
                                        
                                        <p className="text-gray-200 text-lg md:text-2xl leading-relaxed font-medium">
                                            {events.find(e => e.id === selectedId)?.description}
                                        </p>

                                        <div className="mt-12 flex flex-wrap gap-4 justify-center md:justify-start">
                                            <div className="px-5 py-2.5 rounded-full bg-white/5 border border-white/10 text-gray-400 text-[10px] font-black uppercase tracking-widest">
                                                Fundación Struky
                                            </div>
                                            <div className="px-5 py-2.5 rounded-full bg-coffee-medium/10 border border-coffee-medium/20 text-coffee-medium text-[10px] font-black uppercase tracking-widest">
                                                ✓ Hecho Real
                                            </div>
                                        </div>
                                    </div>
                                </motion.div>
                            </div>
                        </>
                    )}
                </AnimatePresence>
            </div>
        </section>
    );
}
