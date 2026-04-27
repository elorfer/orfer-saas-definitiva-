'use client';

import { useState, useRef } from 'react';
import { Check, Video, ChevronLeft, ChevronRight } from 'lucide-react';
import { PLANS } from '../lib/plans';

interface PricingTableProps {
    onSelectPlan: (plan: string, price: number) => void;
    t: any;
}

export default function PricingTable({ onSelectPlan, t }: PricingTableProps) {
    const [activeIndex, setActiveIndex] = useState(0);
    const scrollRef = useRef<HTMLDivElement>(null);
    const sectionRef = useRef<HTMLElement>(null);

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

    const scrollToPlan = (index: number) => {
        if (scrollRef.current) {
            const container = scrollRef.current;
            const scrollAmount = container.offsetWidth * 0.8 + 24;
            container.scrollTo({
                left: index * scrollAmount,
                behavior: 'smooth'
            });
            setActiveIndex(index);
        }
    };

    const next = () => {
        if (activeIndex < plans.length - 1) {
            scrollToPlan(activeIndex + 1);
        } else {
            scrollToPlan(0);
        }
    };

    const prev = () => {
        if (activeIndex > 0) {
            scrollToPlan(activeIndex - 1);
        } else {
            scrollToPlan(plans.length - 1);
        }
    };

    const plans = PLANS.map(plan => ({
        ...plan,
        name: t.plans[plan.id].name,
        description: t.plans[plan.id].desc,
        features: t.plans[plan.id].features,
        cta: t.plans[plan.id].cta
    }));

    return (
        <section ref={sectionRef} id="pricing" className="section-padding bg-[#050505] relative overflow-hidden scroll-mt-20 border-t border-white/5">
            <div className="max-w-6xl mx-auto px-6 relative z-10">
                <div className="text-center mb-16">
                    <h2 className="text-4xl md:text-5xl font-black mb-4 tracking-tighter text-white">
                        Planes de <span className="text-gradient">Producción</span>
                    </h2>
                    <p className="text-gray-400 text-base md:text-xl max-w-xl mx-auto font-medium leading-relaxed">
                        Selecciona el nivel de acabado que tu música merece. Calidad internacional para el mercado global.
                    </p>
                </div>
                <div className="relative">
                    <div 
                        ref={scrollRef}
                        onScroll={handleScroll}
                        className="flex md:grid md:grid-cols-3 gap-6 overflow-x-auto md:overflow-visible pt-8 pb-12 md:pb-0 px-4 md:px-0 snap-x snap-mandatory custom-scrollbar-hide"
                    >
                        {plans.map((plan) => (
                            <div
                                key={plan.id}
                                className={`relative bg-[#0A0A0A] rounded-[2rem] p-6 md:p-10 border transition-all duration-500 hover:border-white/10 ${
                                    plan.id === 'elite'
                                    ? 'border-purple-600/30 bg-purple-600/5'
                                    : plan.highlight 
                                    ? 'border-coffee-medium/30 bg-coffee-medium/5' 
                                    : 'border-white/5 bg-[#111]'
                                } flex flex-col flex-shrink-0 w-[85%] md:w-auto snap-center`}
                            >
                                {plan.id === 'elite' && (
                                    <div className="absolute -top-3.5 left-1/2 -translate-x-1/2 bg-purple-600 text-white text-[9px] font-black italic uppercase tracking-tighter px-6 py-2 rounded-full shadow-2xl z-10 border border-white/20 whitespace-nowrap">
                                        Experiencia Definitiva
                                    </div>
                                )}

                                {plan.highlight && plan.id !== 'elite' && (
                                    <div className="absolute -top-3.5 left-1/2 -translate-x-1/2 bg-coffee-medium text-black text-[9px] font-black italic uppercase tracking-tighter px-6 py-2 rounded-full shadow-2xl z-10 border border-white/10 whitespace-nowrap">
                                        {t.popular}
                                    </div>
                                )}

                                <div className="mb-8">
                                    <h3 className="text-xl font-black italic uppercase tracking-tighter text-white mb-2">{plan.name}</h3>
                                    <div className="flex items-baseline gap-1">
                                        <span className="text-4xl md:text-5xl font-black text-white">${plan.price}</span>
                                        <span className="text-[10px] font-black italic uppercase text-gray-500 tracking-widest ml-1">USD</span>
                                    </div>
                                    <p className="text-gray-500 text-xs mt-4 font-bold leading-relaxed">{plan.description}</p>
                                </div>

                                <ul className="space-y-4 mb-10 flex-grow">
                                    {plan.features.map((feature: string, i: number) => (
                                        <li key={i} className="flex items-start gap-3 text-[11px] text-gray-400 font-medium">
                                            <Check className={`w-4 h-4 shrink-0 mt-0.5 ${plan.id === 'elite' ? 'text-purple-500' : 'text-coffee-medium'}`} />
                                            <span className="leading-tight">{feature}</span>
                                        </li>
                                    ))}
                                </ul>

                                <button
                                    onClick={() => onSelectPlan(plan.id, plan.price)}
                                    className={`w-full py-5 rounded-2xl text-[11px] font-black italic uppercase tracking-widest transition-all active:scale-[0.98] ${
                                        plan.id === 'elite'
                                        ? 'bg-purple-600 text-white shadow-lg shadow-purple-600/20 hover:bg-purple-500'
                                        : plan.highlight
                                        ? 'bg-[#8B6A5A] text-black shadow-lg shadow-[#8B6A5A]/10 hover:bg-[#9E7B6B]'
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
                                <div 
                                    key={i}
                                    className={`h-2 rounded-full transition-all duration-300 ${activeIndex === i ? 'w-8 bg-purple-600' : 'w-2 bg-white/10'}`}
                                ></div>
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
