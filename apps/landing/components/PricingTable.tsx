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
        <section ref={sectionRef} id="pricing" className="section-padding bg-dark-bg/50 relative overflow-hidden scroll-mt-20">
            <div className="max-w-6xl mx-auto px-6">
                <div className="text-center mb-16">
                    <h2 className="text-4xl md:text-6xl font-black mb-4 tracking-tighter">
                        Planes de <span className="text-gradient hover:glow-text transition-all duration-300">Producción</span>
                    </h2>
                    <p className="text-gray-400 text-lg md:text-xl max-w-2xl mx-auto">
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
                                className={`relative glass-morphism rounded-[2rem] p-6 md:p-10 border transition-all duration-300 hover:-translate-y-2 ${
                                    plan.id === 'elite'
                                    ? 'border-accent-purple shadow-[0_0_50px_rgba(76,29,149,0.3)] ring-1 ring-accent-purple/50 bg-accent-purple/[0.03]'
                                    : plan.highlight 
                                    ? 'border-coffee-medium shadow-[0_0_50px_rgba(202,160,82,0.2)] ring-1 ring-coffee-medium/50 bg-coffee-medium/[0.03]' 
                                    : 'border-white/5 bg-white/[0.01]'
                                } flex flex-col flex-shrink-0 w-[85%] md:w-auto snap-center`}
                            >
                                {plan.id === 'elite' && (
                                    <div className="absolute -top-4 left-1/2 -translate-x-1/2 bg-gradient-to-r from-accent-purple to-indigo-600 text-white text-[10px] font-black uppercase tracking-widest px-4 py-1.5 rounded-full shadow-2xl z-10 border border-white/20 whitespace-nowrap">
                                        Experiencia Definitiva
                                    </div>
                                )}

                                {plan.highlight && plan.id !== 'elite' && (
                                    <div className="absolute -top-4 left-1/2 -translate-x-1/2 bg-gradient-to-r from-coffee-medium to-coffee-light text-black text-[10px] font-black uppercase tracking-widest px-4 py-1.5 rounded-full shadow-2xl z-10 border border-white/10 whitespace-nowrap">
                                        Elección Recomendada
                                    </div>
                                )}

                                <div className="mb-6 md:mb-10">
                                    <div className={`w-12 h-12 md:w-14 md:h-14 rounded-2xl flex items-center justify-center mb-6 md:mb-8 ${
                                        plan.id === 'elite' ? 'bg-accent-purple text-white shadow-[0_0_20px_rgba(76,29,149,0.5)]' : plan.highlight ? 'bg-coffee-medium text-black shadow-[0_0_20px_rgba(202,160,82,0.4)]' : 'bg-white/5 text-coffee-light'
                                    }`}>
                                        <plan.icon className="w-6 h-6 md:w-7 md:h-7" />
                                    </div>
                                    <h3 className="text-2xl md:text-4xl font-black mb-2 md:mb-3 tracking-tighter">{plan.name}</h3>
                                    <p className="text-gray-400 text-xs md:text-base font-medium leading-relaxed">{plan.description}</p>
                                </div>

                                <div className="mb-6 md:mb-10">
                                    <div className="flex items-baseline gap-1 md:gap-2">
                                        <span className="text-5xl md:text-7xl font-black text-white tracking-tighter">${plan.price}</span>
                                        <span className="text-gray-500 font-bold uppercase text-[9px] md:text-xs tracking-[0.2em] md:tracking-[0.3em]">USD</span>
                                    </div>
                                </div>

                                <div className="w-full h-px bg-gradient-to-r from-transparent via-white/10 to-transparent mb-6 md:mb-10"></div>

                                <ul className="space-y-3 md:space-y-5 mb-8 md:mb-12 flex-1">
                                    {plan.features.map((feature: string, i: number) => (
                                        <li key={i} className={`flex items-start gap-3 md:gap-4 text-[13px] md:text-base ${feature.includes('OBSEQUIO') || feature.includes('GIFT') || feature.includes('VIP') ? 'text-coffee-light font-bold' : 'text-gray-400'}`}>
                                            <div className={`mt-0.5 md:mt-1 p-0.5 rounded-full ${plan.id === 'elite' ? 'bg-accent-purple/20 text-accent-purple' : 'bg-coffee-medium/20 text-coffee-medium'}`}>
                                                {feature.includes('Video') || feature.includes('TikTok') || feature.includes('Visual') ? (
                                                    <Video className="w-3.5 h-3.5 md:w-4 md:h-4 shrink-0" />
                                                ) : (
                                                    <Check className="w-3.5 h-3.5 md:w-4 md:h-4 shrink-0" />
                                                )}
                                            </div>
                                            <span className="leading-tight">{feature}</span>
                                        </li>
                                    ))}
                                </ul>

                                <button 
                                    onClick={() => onSelectPlan(plan.id, plan.price)}
                                    className={`w-full py-4 md:py-5 rounded-2xl font-black uppercase tracking-widest text-[10px] md:text-xs transition-all duration-500 hover:scale-[1.02] active:scale-95 ${
                                        plan.id === 'elite'
                                        ? 'bg-accent-purple text-white hover:bg-accent-purple/90 shadow-[0_15px_30px_rgba(76,29,149,0.3)]'
                                        : plan.highlight 
                                        ? 'bg-coffee-medium text-black hover:bg-coffee-light shadow-[0_15px_30px_rgba(202,160,82,0.3)]' 
                                        : 'bg-white/5 text-white hover:bg-white/10 border border-white/10'
                                    }`}
                                >
                                    {plan.cta}
                                </button>
                            </div>
                        ))}
                    </div>

                    {/* Mobile Navigation */}
                    <div className="flex md:hidden items-center justify-center gap-6 mt-4">
                        <button 
                            onClick={prev}
                            className="w-10 h-10 rounded-full border border-white/10 flex items-center justify-center bg-white/5 active:bg-coffee-medium transition-all"
                        >
                            <ChevronLeft className="w-5 h-5" />
                        </button>
                        
                        <div className="flex gap-2">
                            {plans.map((_, i) => (
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
