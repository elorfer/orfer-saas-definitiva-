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

            if (sectionRef.current) {
                sectionRef.current.scrollIntoView({ behavior: 'smooth' });
            }
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
                        className="flex md:grid md:grid-cols-3 gap-6 overflow-x-auto md:overflow-visible pb-12 md:pb-0 px-4 md:px-0 snap-x snap-mandatory custom-scrollbar-hide"
                    >
                        {plans.map((plan) => (
                            <div
                                key={plan.id}
                                className={`relative glass-morphism rounded-3xl p-6 border transition-all duration-300 hover:-translate-y-2 ${
                                    plan.id === 'elite'
                                    ? 'border-accent-purple shadow-[0_0_40px_rgba(76,29,149,0.25)] ring-1 ring-accent-purple/50'
                                    : plan.highlight 
                                    ? 'border-coffee-medium shadow-[0_0_40px_rgba(202,160,82,0.15)] ring-1 ring-coffee-medium/50' 
                                    : 'border-white/5'
                                } flex flex-col flex-shrink-0 w-[80%] md:w-auto snap-center`}
                            >
                                {plan.id === 'elite' && (
                                    <div className="absolute -top-4 left-1/2 -translate-x-1/2 bg-gradient-to-r from-accent-purple to-indigo-600 text-white text-[10px] font-black uppercase tracking-widest px-4 py-1.5 rounded-full shadow-lg z-10 border border-white/10">
                                        Experiencia Definitiva
                                    </div>
                                )}

                                {plan.highlight && plan.id !== 'elite' && (
                                    <div className="absolute -top-4 left-1/2 -translate-x-1/2 bg-gradient-to-r from-coffee-medium to-coffee-light text-black text-[10px] font-black uppercase tracking-widest px-4 py-1.5 rounded-full shadow-lg z-10">
                                        Más Popular
                                    </div>
                                )}

                                <div className="mb-8">
                                    <div className={`w-12 h-12 rounded-2xl flex items-center justify-center mb-6 ${
                                        plan.id === 'elite' ? 'bg-accent-purple text-white shadow-[0_0_15px_rgba(76,29,149,0.4)]' : plan.highlight ? 'bg-coffee-medium text-black' : 'bg-white/5 text-coffee-light'
                                    }`}>
                                        <plan.icon className="w-6 h-6" />
                                    </div>
                                    <h3 className="text-2xl font-black mb-2">{plan.name}</h3>
                                    <p className="text-gray-500 text-sm">{plan.description}</p>
                                </div>

                                <div className="mb-8">
                                    <div className="flex items-baseline gap-1">
                                        <span className="text-5xl font-black text-white">${plan.price}</span>
                                        <span className="text-gray-500 font-bold uppercase text-xs tracking-widest">USD</span>
                                    </div>
                                </div>

                                <ul className="space-y-4 mb-10 flex-1">
                                    {plan.features.map((feature: string, i: number) => (
                                        <li key={i} className={`flex items-start gap-3 text-sm ${feature.includes('OBSEQUIO') || feature.includes('GIFT') ? 'text-coffee-light font-bold' : 'text-gray-400'}`}>
                                            {feature.includes('Video') || feature.includes('TikTok') ? (
                                                <Video className="w-5 h-5 shrink-0 text-coffee-medium" />
                                            ) : (
                                                <Check className="w-5 h-5 shrink-0 text-coffee-medium" />
                                            )}
                                            {feature}
                                        </li>
                                    ))}
                                </ul>

                                <button 
                                    onClick={() => onSelectPlan(plan.id, plan.price)}
                                    className={`w-full py-4 rounded-xl font-black uppercase tracking-widest text-sm transition-all duration-300 ${
                                        plan.id === 'elite'
                                        ? 'bg-accent-purple text-white hover:bg-accent-purple/90 shadow-lg shadow-accent-purple/20'
                                        : plan.highlight 
                                        ? 'bg-coffee-medium text-black hover:bg-coffee-light shadow-lg shadow-coffee-medium/20' 
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
