'use client';

import { useState, useRef, useEffect } from 'react';
import { Check, Video, ChevronLeft, ChevronRight, ShieldCheck } from 'lucide-react';
import { PLANS } from '../lib/plans';
import { playTick } from '../lib/soundEngine';

interface PricingTableProps {
    onSelectPlan: (plan: string, price: number) => void;
    t: any;
}

export default function PricingTable({ onSelectPlan, t }: PricingTableProps) {
    const [activeIndex, setActiveIndex] = useState(1);
    const scrollRef = useRef<HTMLDivElement>(null);
    const sectionRef = useRef<HTMLElement>(null);

    const handleScroll = () => {
        if (scrollRef.current) {
            const container = scrollRef.current;
            const scrollLeft = container.scrollLeft;
            const containerWidth = container.offsetWidth;
            let closestIndex = 0;
            let closestDist = Infinity;
            for (let i = 0; i < container.children.length; i++) {
                const card = container.children[i] as HTMLElement;
                const cardCenter = card.offsetLeft + card.offsetWidth / 2;
                const viewCenter = scrollLeft + containerWidth / 2;
                const dist = Math.abs(cardCenter - viewCenter);
                if (dist < closestDist) {
                    closestDist = dist;
                    closestIndex = i;
                }
            }
            if (closestIndex !== activeIndex) {
                setActiveIndex(closestIndex);
            }
        }
    };



    const scrollToPlan = (index: number) => {
        playTick();
        if (scrollRef.current) {
            const container = scrollRef.current;
            const card = container.children[index] as HTMLElement;
            if (card) {
                const scrollAmount = card.offsetLeft - (container.clientWidth / 2) + (card.clientWidth / 2);
                container.scrollTo({ left: scrollAmount, behavior: 'smooth' });
                setActiveIndex(index);
            }
        }
    };

    const next = () => {
        const nextIdx = activeIndex < plans.length - 1 ? activeIndex + 1 : 0;
        scrollToPlan(nextIdx);
    };

    // Auto-scroll al Pro Master al cargar en móvil
    useEffect(() => {
        const timer = setTimeout(() => {
            if (window.innerWidth < 768) {
                scrollToPlan(1); // Index 1 es Pro Master
            }
        }, 500);
        return () => clearTimeout(timer);
    }, []);

    const prev = () => {
        const prevIdx = activeIndex > 0 ? activeIndex - 1 : plans.length - 1;
        scrollToPlan(prevIdx);
    };

    const plans = PLANS.filter(p => p.id !== 'youtube').map(plan => ({
        ...plan,
        name: t.plans[plan.id].name,
        description: t.plans[plan.id].desc,
        features: t.plans[plan.id].features,
        cta: t.plans[plan.id].cta
    }));

    return (
        <section ref={sectionRef} id="pricing" className="py-20 md:py-32 bg-[#050505] relative scroll-mt-20 border-t border-white/5">
            <div className="max-w-7xl mx-auto relative z-10">
                <div className="px-6 md:px-12 lg:px-24">
                <div className="text-center mb-16">
                    <h2 className="text-4xl md:text-5xl font-black mb-4 tracking-tighter text-white">
                        Planes de <span className="text-gradient">Producción</span>
                    </h2>
                    <p className="text-gray-400 text-base md:text-xl max-w-xl mx-auto font-medium leading-relaxed">
                        Selecciona el nivel de acabado que tu música merece. Calidad internacional para el mercado global.
                    </p>
                </div>
                {/* VIP Scarcity Banner */}
                <div className="max-w-3xl mx-auto mb-10 bg-gradient-to-r from-transparent via-coffee-medium/10 to-transparent border-y border-coffee-medium/20 py-5 px-4 text-center">
                    <div className="flex flex-col md:flex-row items-center justify-center gap-4">
                        <div className="flex items-center justify-center w-10 h-10 rounded-full bg-coffee-medium/20 text-coffee-medium shadow-[0_0_15px_rgba(202,160,82,0.3)] animate-pulse shrink-0">
                            <span className="text-lg">⏳</span>
                        </div>
                        <div className="text-center md:text-left">
                            <h4 className="text-coffee-medium font-black uppercase tracking-widest mb-1 text-xs md:text-sm">Alta Demanda • Cupos Limitados</h4>
                            <p className="text-gray-400 text-xs md:text-sm font-medium leading-relaxed">
                                Debido al alto nivel de detalle que exige cada hit, <strong className="text-white">solo podemos aceptar 50 proyectos nuevos por semana</strong>.
                            </p>
                        </div>
                    </div>
                </div>
                </div>

                <div className="relative">
                    <div 
                        ref={scrollRef}
                        onScroll={handleScroll}
                        className="flex md:grid md:grid-cols-4 gap-4 md:gap-6 overflow-x-auto md:overflow-visible pt-8 pb-12 md:pb-0 px-2 md:px-0 snap-x snap-mandatory scroll-px-6 custom-scrollbar-hide"
                    >
                        {plans.map((plan) => (
                            <div
                                key={plan.id}
                                className={`relative bg-[#0A0A0A] rounded-[2rem] p-5 md:p-6 border transition-all duration-500 hover:border-white/10 ${
                                    plan.id === 'elite'
                                    ? 'border-purple-600/30 bg-purple-600/5'
                                    : plan.id === 'premium'
                                    ? 'border-emerald-500/30 bg-emerald-500/5'
                                    : plan.highlight 
                                    ? 'border-coffee-medium/30 bg-coffee-medium/5' 
                                    : 'border-white/5 bg-[#111]'
                                } flex flex-col flex-shrink-0 w-[88%] md:w-auto snap-center`}
                            >
                                {plan.id === 'elite' && (
                                    <div className="absolute -top-3.5 left-1/2 -translate-x-1/2 bg-purple-600 text-white text-[9px] font-black italic uppercase tracking-tighter px-6 py-2 rounded-full shadow-2xl z-10 border border-white/20 whitespace-nowrap">
                                        Experiencia Definitiva
                                    </div>
                                )}

                                {plan.highlight && plan.id !== 'elite' && (
                                    <div className="absolute -top-3.5 left-1/2 -translate-x-1/2 bg-coffee-medium text-white text-[9px] font-black italic uppercase tracking-tighter px-6 py-2 rounded-full shadow-2xl z-10 border border-white/10 whitespace-nowrap">
                                        {t.popular}
                                    </div>
                                )}

                                <div className="mb-8">
                                    <h3 className="text-lg md:text-xl font-black italic uppercase tracking-tighter text-white mb-1">{plan.name}</h3>
                                    {plan.id === 'pro' && (
                                        <div className="mb-3 flex items-center gap-1">
                                            <span className="text-[10px] text-coffee-medium font-black uppercase tracking-widest animate-pulse">
                                                78% de artistas lo eligen
                                            </span>
                                        </div>
                                    )}
                                    <div className="flex items-baseline gap-1">
                                        <span className="text-3xl md:text-4xl font-black text-white">${plan.price}</span>
                                        <span className="text-[10px] font-black italic uppercase text-gray-500 tracking-widest ml-1">USD</span>
                                    </div>
                                    <p className="text-gray-200 text-sm mt-3 font-bold leading-relaxed">{plan.description}</p>
                                </div>

                                <ul className="space-y-4 mb-10 flex-grow">
                                    {plan.features.map((feature: string, i: number) => (
                                        <li key={i} className="flex items-start gap-2.5 text-[13px] text-gray-300 font-medium">
                                            <Check className={`w-4 h-4 shrink-0 mt-0.5 ${plan.id === 'elite' ? 'text-purple-500' : plan.id === 'premium' ? 'text-emerald-500' : 'text-coffee-medium'}`} />
                                            <span className="leading-tight">{feature}</span>
                                        </li>
                                    ))}
                                </ul>

                                <button
                                    onClick={() => onSelectPlan(plan.id, plan.price)}
                                    className={`w-full py-4 rounded-2xl text-[11px] font-black italic uppercase tracking-wider transition-all active:scale-[0.98] ${
                                        plan.id === 'elite'
                                        ? 'bg-purple-600 text-white shadow-lg shadow-purple-600/20 hover:bg-purple-500'
                                        : plan.id === 'premium'
                                        ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-600/20 hover:bg-emerald-500'
                                        : plan.highlight
                                        ? 'bg-[#8B6A5A] text-white shadow-lg shadow-[#8B6A5A]/10 hover:bg-[#9E7B6B]'
                                        : 'bg-white/5 text-white border border-white/10 hover:bg-white/10'
                                    }`}
                                >
                                    {plan.cta}
                                </button>
                            </div>
                        ))}
                    </div>


                    {/* Mobile Navigation Arrows */}
                    <div className="flex justify-center items-center gap-10 mt-8 md:hidden">
                        <button 
                            onClick={prev}
                            className="w-12 h-12 rounded-full border border-white/10 flex items-center justify-center bg-[#111] active:bg-purple-600 transition-all"
                        >
                            <ChevronLeft className="w-6 h-6 text-white" />
                        </button>
                        
                        <div className="flex gap-3">
                            {plans.map((_, i) => (
                                <button 
                                    key={i}
                                    onClick={() => scrollToPlan(i)}
                                    className={`h-2 rounded-full transition-all duration-300 ${
                                        i === activeIndex ? 'w-8 bg-purple-600' : 'w-2 bg-white/20 hover:bg-white/30'
                                    }`}
                                />
                            ))}
                        </div>

                        <button 
                            onClick={next}
                            className="w-12 h-12 rounded-full border border-white/10 flex items-center justify-center bg-[#111] active:bg-purple-600 transition-all"
                        >
                            <ChevronRight className="w-6 h-6 text-white" />
                        </button>
                    </div>


                </div>
            </div>
        </section>
    );
}
