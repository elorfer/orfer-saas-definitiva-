'use client';

import React from 'react';
import { motion } from 'framer-motion';
import { Play, Check, Sparkles, Video, TrendingUp } from 'lucide-react';
import { playTick } from '../lib/soundEngine';

interface ExtraServicesProps {
    lang: 'es' | 'en';
    t: any;
    onSelectPlan: (plan: string, price: number) => void;
}

export default function ExtraServices({ lang, t, onSelectPlan }: ExtraServicesProps) {
    const service = t.extraServices.youtube;

    return (
        <section className="py-12 relative overflow-hidden">
            {/* Background Decorations */}
            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[800px] h-[800px] bg-coffee-medium/5 rounded-full blur-[120px] pointer-events-none"></div>

            <div className="max-w-7xl mx-auto px-6 relative z-10">
                <div className="text-center mb-16">
                    <motion.div
                        initial={{ opacity: 0, y: 20 }}
                        whileInView={{ opacity: 1, y: 0 }}
                        viewport={{ once: true }}
                        transition={{ duration: 0.6 }}
                    >
                        <h2 className="text-4xl md:text-6xl font-black mb-4 tracking-tight text-white uppercase">
                            {t.extraServices.title}
                        </h2>
                        <p className="text-gray-400 text-lg md:text-xl max-w-2xl mx-auto font-medium">
                            {t.extraServices.subtitle}
                        </p>
                    </motion.div>
                </div>

                <div className="max-w-4xl mx-auto">
                    <motion.div
                        initial={{ opacity: 0, scale: 0.95 }}
                        whileInView={{ opacity: 1, scale: 1 }}
                        viewport={{ once: true }}
                        transition={{ duration: 0.5 }}
                        className="relative group"
                    >
                        {/* Glow Effect */}
                        <div className="absolute -inset-1 bg-gradient-to-r from-red-600 to-coffee-medium rounded-[2.5rem] blur opacity-25 group-hover:opacity-40 transition duration-1000 group-hover:duration-200"></div>
                        
                        <div className="relative bg-black border border-white/10 rounded-[2.5rem] overflow-hidden">
                            <div className="grid md:grid-cols-2">
                                {/* Left Side: Content */}
                                <div className="p-8 md:p-12 flex flex-col justify-center border-b md:border-b-0 md:border-r border-white/5">
                                    <div className="flex items-center gap-4 mb-6">
                                        <div className="w-14 h-14 rounded-2xl bg-red-600/10 flex items-center justify-center text-red-500 shadow-[0_0_20px_rgba(220,38,38,0.2)]">
                                            <Play className="w-8 h-8" />
                                        </div>
                                        <div>
                                            <h3 className="text-2xl font-black text-white uppercase tracking-tight leading-none mb-1">
                                                {service.name}
                                            </h3>
                                            <div className="flex items-center gap-2">
                                                <Sparkles className="w-3 h-3 text-coffee-light animate-pulse" />
                                                <span className="text-[10px] font-black text-coffee-light uppercase tracking-widest">Servicio VIP Elite</span>
                                            </div>
                                        </div>
                                    </div>

                                    <p className="text-gray-400 text-base mb-8 leading-relaxed">
                                        {service.desc}
                                    </p>

                                    <div className="space-y-4 mb-8">
                                        {service.features.map((feature: string, idx: number) => (
                                            <div key={idx} className="flex items-start gap-3">
                                                <div className="w-5 h-5 rounded-full bg-coffee-medium/10 flex items-center justify-center shrink-0 mt-0.5">
                                                    <Check className="w-3 h-3 text-coffee-medium" />
                                                </div>
                                                <span className="text-sm text-gray-300 font-medium">{feature}</span>
                                            </div>
                                        ))}
                                    </div>

                                    <div className="flex items-center gap-4 p-4 rounded-2xl bg-white/5 border border-white/10">
                                        <div className="w-10 h-10 rounded-xl bg-coffee-medium text-black flex items-center justify-center font-bold shadow-lg">
                                            HD
                                        </div>
                                        <div>
                                            <p className="text-[10px] font-black text-coffee-light uppercase tracking-widest mb-1">Obsequio Exclusivo</p>
                                            <p className="text-xs text-white font-bold">{lang === 'es' ? '1 Video en Alta Definición incluido' : '1 High Definition Video included'}</p>
                                        </div>
                                    </div>
                                </div>

                                {/* Right Side: Action & Visuals */}
                                <div className="p-8 md:p-12 bg-white/[0.02] flex flex-col items-center justify-center text-center">
                                    <div className="mb-8 relative">
                                        {/* Floating Elements */}
                                        <div className="absolute -top-6 -right-6 w-12 h-12 bg-red-600/20 rounded-xl flex items-center justify-center text-red-500 animate-bounce">
                                            <TrendingUp className="w-6 h-6" />
                                        </div>

                                        <div className="text-6xl md:text-8xl font-black text-white tracking-tighter mb-2">
                                            ${service.price}
                                        </div>
                                        <div className="text-sm font-black text-gray-500 uppercase tracking-[0.3em]">USD / Único Pago</div>
                                    </div>

                                    <button
                                        onClick={() => {
                                            playTick();
                                            onSelectPlan('youtube', service.price);
                                        }}
                                        className="w-full btn-primary py-5 px-8 text-xs font-black tracking-[0.3em] uppercase group/btn relative overflow-hidden"
                                    >
                                        <span className="relative z-10 flex items-center justify-center gap-3">
                                            {service.cta}
                                            <Sparkles className="w-4 h-4" />
                                        </span>
                                        <div className="absolute inset-0 bg-gradient-to-r from-white/0 via-white/20 to-white/0 -translate-x-full group-hover:translate-x-full transition-transform duration-700"></div>
                                    </button>

                                    <div className="mt-8 grid grid-cols-2 gap-4 w-full">
                                        <div className="flex flex-col items-center gap-1">
                                            <div className="text-xl font-black text-white">48h</div>
                                            <div className="text-[9px] text-gray-600 font-bold uppercase tracking-widest">Setup inicial</div>
                                        </div>
                                        <div className="flex flex-col items-center gap-1">
                                            <div className="text-xl font-black text-white">100%</div>
                                            <div className="text-[9px] text-gray-600 font-bold uppercase tracking-widest">Optimizado</div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </motion.div>
                </div>
            </div>
        </section>
    );
}
