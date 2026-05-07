'use client';

import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Globe2, Users, Mic2, Headphones, MapPin } from 'lucide-react';

const studios = [
    { name: "Struky LA", x: "18%", y: "25%", delay: 0 },
    { name: "Struky Miami", x: "24%", y: "35%", delay: 1.2 },
    { name: "Struky CDMX", x: "20%", y: "42%", delay: 0.5 },
    { name: "Struky Bogotá", x: "28%", y: "55%", delay: 2.1 },
    { name: "Struky Medellín", x: "27%", y: "52%", delay: 0.8 },
    { name: "Struky Madrid", x: "48%", y: "25%", delay: 1.5 },
    { name: "Struky Barcelona", x: "50%", y: "22%", delay: 0.3 },
    { name: "Struky London", x: "47%", y: "15%", delay: 2.5 },
    { name: "Struky Buenos Aires", x: "32%", y: "75%", delay: 1.1 },
    { name: "Struky Santiago", x: "28%", y: "72%", delay: 0.6 },
    { name: "Struky Lima", x: "25%", y: "62%", delay: 1.8 },
];

export default function GlobalImpact({ t }: { t: any }) {
    const [activeStudio, setActiveStudio] = useState<number | null>(null);

    return (
        <section className="section-padding bg-dark-bg relative overflow-hidden" onClick={() => setActiveStudio(null)}>
            {/* Background Glows */}
            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-full h-full bg-coffee-medium/5 blur-[150px] rounded-full pointer-events-none opacity-20"></div>

            <div className="max-w-7xl mx-auto px-4 relative z-10">
                <div className="text-center mb-16 md:mb-24">
                    <motion.div
                        initial={{ opacity: 0, y: 20 }}
                        whileInView={{ opacity: 1, y: 0 }}
                        viewport={{ once: true }}
                        className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-coffee-medium/10 border border-coffee-medium/20 text-coffee-medium text-xs font-black uppercase tracking-widest mb-6"
                    >
                        <Globe2 className="w-4 h-4" />
                        Presencia Internacional
                    </motion.div>
                    <h2 className="text-4xl md:text-6xl font-black mb-6 tracking-tighter uppercase italic">
                        {t.title.split(' ')[0]} <span className="text-gradient">{t.title.split(' ').slice(1).join(' ')}</span>
                    </h2>
                    <p className="text-gray-400 text-lg md:text-xl max-w-3xl mx-auto font-medium leading-relaxed">
                        {t.subtitle}
                    </p>
                </div>

                {/* The Map Container */}
                <div className="relative w-full max-w-5xl mx-auto mb-20 md:mb-32 group aspect-[2/1] cursor-default" style={{ WebkitMaskImage: 'radial-gradient(ellipse at center, black 40%, transparent 100%)', maskImage: 'radial-gradient(ellipse at center, black 40%, transparent 100%)' }}>
                    {/* Professional Dotted World Map Image */}
                    <div className="absolute inset-0 opacity-40 grayscale group-hover:grayscale-0 transition-all duration-1000">
                        <img 
                            src="https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/world-map.png" 
                            alt="Global Network" 
                            className="w-full h-full object-contain mix-blend-screen"
                        />
                    </div>

                    {/* Connecting Lines - Static for performance */}
                    <div className="absolute inset-0 z-0 pointer-events-none opacity-20">
                        <svg viewBox="0 0 1000 500" className="w-full h-full">
                            <path d="M 240 175 Q 210 120 180 125" fill="none" stroke="#CAA052" strokeWidth="1" strokeDasharray="5 5" vectorEffect="non-scaling-stroke" />
                            <path d="M 240 175 Q 360 100 480 125" fill="none" stroke="#CAA052" strokeWidth="1" strokeDasharray="4 8" vectorEffect="non-scaling-stroke" />
                            <path d="M 200 210 Q 240 250 280 275" fill="none" stroke="#CAA052" strokeWidth="1" strokeDasharray="3 6" vectorEffect="non-scaling-stroke" />
                            <path d="M 280 275 Q 380 150 480 125" fill="none" stroke="#CAA052" strokeWidth="1" opacity="0.6" vectorEffect="non-scaling-stroke" />
                            <path d="M 480 125 Q 475 100 470 75" fill="none" stroke="#CAA052" strokeWidth="1" strokeDasharray="2 4" vectorEffect="non-scaling-stroke" />
                            <path d="M 280 275 Q 300 350 320 375" fill="none" stroke="#CAA052" strokeWidth="1" vectorEffect="non-scaling-stroke" />
                        </svg>
                    </div>

                    {/* Pulsing Studios */}
                    {studios.map((studio, i) => (
                        <div 
                            key={i}
                            className="absolute"
                            style={{ left: studio.x, top: studio.y }}
                            onClick={(e) => {
                                e.stopPropagation();
                                setActiveStudio(activeStudio === i ? null : i);
                            }}
                        >
                            <div className="relative cursor-pointer group/dot">
                                {/* Simple CSS Pulse */}
                                <div className="absolute inset-0 w-8 h-8 -ml-4 -mt-4 rounded-full bg-coffee-medium/20 animate-pulse-slow" />
                                <div className="absolute inset-0 w-4 h-4 -ml-2 -mt-2 rounded-full bg-coffee-light/10" />
                                {/* Core Dot */}
                                <div className={`relative z-10 w-3.5 h-3.5 -ml-[7px] -mt-[7px] rounded-full transition-all duration-300 ${activeStudio === i ? 'bg-white scale-125' : 'bg-coffee-medium'} shadow-[0_0_20px_rgba(202,160,82,1)] border border-white/40`}></div>
                                
                                {/* Label (Visible ONLY when active) */}
                                <AnimatePresence>
                                    {activeStudio === i && (
                                        <motion.div 
                                            initial={{ opacity: 0, y: 10, x: '-50%' }}
                                            animate={{ opacity: 1, y: 0, x: '-50%' }}
                                            exit={{ opacity: 0, y: 10, x: '-50%' }}
                                            className="absolute -top-16 left-1/2 whitespace-nowrap z-[70]"
                                        >
                                            <div className="flex flex-col items-center gap-1.5 drop-shadow-[0_10px_10px_rgba(0,0,0,0.5)]">
                                                <div className="bg-white text-black text-[10px] md:text-xs font-black px-4 py-2 rounded-lg shadow-2xl uppercase tracking-tighter border border-coffee-medium">
                                                    {studio.name}
                                                </div>
                                                {/* Arrow */}
                                                <div className="w-2 h-2 bg-black/80 rotate-45 -mt-1 border-r border-b border-white/10"></div>
                                            </div>
                                        </motion.div>
                                    )}
                                </AnimatePresence>
                            </div>
                        </div>
                    ))}
                </div>

                {/* Global Stats Bar */}
                <div className="grid grid-cols-1 md:grid-cols-3 gap-8 md:gap-12 max-w-4xl mx-auto">
                    {[
                        { icon: <Mic2 className="w-6 h-6" />, label: t.stat1, desc: "Calidad certificada" },
                        { icon: <Globe2 className="w-6 h-6" />, label: t.stat2, desc: "Presencia real" },
                        { icon: <Headphones className="w-6 h-6" />, label: t.stat3, desc: "Asistencia directa" }
                    ].map((stat, i) => (
                        <motion.div 
                            key={i}
                            initial={{ opacity: 0, y: 20 }}
                            whileInView={{ opacity: 1, y: 0 }}
                            viewport={{ once: true }}
                            transition={{ delay: i * 0.2 }}
                            className="flex flex-col items-center text-center group"
                        >
                            <div className="w-16 h-16 rounded-2xl bg-white/[0.03] border border-white/5 flex items-center justify-center text-coffee-medium mb-6 group-hover:bg-coffee-medium group-hover:text-white transition-all duration-500 shadow-xl">
                                {stat.icon}
                            </div>
                            <div className="text-2xl font-black text-white mb-1 tracking-tight uppercase italic">{stat.label}</div>
                            <div className="text-[10px] font-black text-gray-500 uppercase tracking-widest">{stat.desc}</div>
                        </motion.div>
                    ))}
                </div>
            </div>
        </section>
    );
}
