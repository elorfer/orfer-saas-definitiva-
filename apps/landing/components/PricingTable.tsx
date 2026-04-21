'use client';

import { useState, useRef } from 'react';
import { Check, Star, Zap, Crown, Video } from 'lucide-react';
import { motion } from 'framer-motion';

interface PricingTableProps {
    onSelectPlan: (plan: string, price: number) => void;
    t: any;
}

export default function PricingTable({ onSelectPlan, t }: PricingTableProps) {
    const [activeIndex, setActiveIndex] = useState(0);
    const scrollRef = useRef<HTMLDivElement>(null);

    const handleScroll = () => {
        if (scrollRef.current) {
            const scrollPosition = scrollRef.current.scrollLeft;
            const containerWidth = scrollRef.current.offsetWidth;
            // 80% is the card width on mobile, plus the gap
            const cardWidth = containerWidth * 0.8 + 24; 
            const index = Math.round(scrollPosition / cardWidth);
            if (index !== activeIndex) {
                setActiveIndex(index);
            }
        }
    };

    const plans = [
        {
            id: 'starter',
            name: t.plans.starter.name,
            price: 50,
            description: t.plans.starter.desc,
            features: t.plans.starter.features,
            icon: Zap,
            highlight: false,
            cta: t.plans.starter.cta
        },
        {
            id: 'pro',
            name: t.plans.pro.name,
            price: 97,
            description: t.plans.pro.desc,
            features: t.plans.pro.features,
            icon: Star,
            highlight: true,
            cta: t.plans.pro.cta
        },
        {
            id: 'elite',
            name: t.plans.elite.name,
            price: 147,
            description: t.plans.elite.desc,
            features: t.plans.elite.features,
            icon: Crown,
            highlight: false,
            cta: t.plans.elite.cta
        }
    ];

    return (
        <section className="section-padding bg-dark-bg/50 relative overflow-hidden">
            <div className="max-w-6xl mx-auto px-6">
                <div className="text-center mb-16">
                    <h2 className="text-4xl md:text-6xl font-black mb-4 tracking-tighter">
                        Planes de <span className="text-gradient hover:glow-text transition-all duration-300">Producción</span>
                    </h2>
                    <p className="text-gray-400 text-lg md:text-xl max-w-2xl mx-auto">
                        Selecciona el nivel de acabado que tu música merece. Calidad internacional para el mercado global.
                    </p>
                </div>

                <div 
                    ref={scrollRef}
                    onScroll={handleScroll}
                    className="flex md:grid md:grid-cols-3 gap-6 overflow-x-auto md:overflow-visible pb-12 md:pb-0 pt-8 px-4 md:px-0 snap-x snap-mandatory custom-scrollbar-hide"
                >
                    {plans.map((plan) => (
                        <motion.div
                            key={plan.id}
                            whileHover={{ y: -10 }}
                            initial={{ opacity: 1 }} // Remove initial 0 to prevent flickers on mount/scroll
                            className={`relative glass-morphism rounded-3xl p-6 border ${
                                plan.highlight 
                                ? 'border-coffee-medium shadow-[0_0_40px_rgba(202,160,82,0.15)] ring-1 ring-coffee-medium/50' 
                                : 'border-white/5'
                            } flex flex-col flex-shrink-0 w-[80%] md:w-auto snap-center`}
                        >
                            {plan.highlight && (
                                <div className="absolute -top-4 left-1/2 -translate-x-1/2 bg-gradient-to-r from-coffee-medium to-coffee-light text-black text-[10px] font-black uppercase tracking-widest px-4 py-1.5 rounded-full shadow-lg z-10">
                                    Más Popular
                                </div>
                            )}

                            <div className="mb-8">
                                <div className={`w-12 h-12 rounded-2xl flex items-center justify-center mb-6 ${
                                    plan.highlight ? 'bg-coffee-medium text-black' : 'bg-white/5 text-coffee-light'
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
                                    <li key={i} className={`flex items-start gap-3 text-sm ${feature.includes('OBSEQUIO') ? 'text-coffee-light font-bold' : 'text-gray-400'}`}>
                                        {feature.includes('Video Letra') ? (
                                            <Video className="w-5 h-5 shrink-0 text-coffee-medium animate-pulse" />
                                        ) : (
                                            <Check className={`w-5 h-5 shrink-0 ${plan.highlight ? 'text-coffee-light' : 'text-coffee-medium'}`} />
                                        )}
                                        {feature}
                                    </li>
                                ))}
                            </ul>

                            <button
                                onClick={() => {
                                    onSelectPlan(plan.name, plan.price);
                                    document.getElementById('order-form')?.scrollIntoView({ behavior: 'smooth' });
                                }}
                                className={`w-full py-4 rounded-xl font-black uppercase tracking-widest text-xs transition-all ${
                                    plan.highlight
                                    ? 'bg-[#A67C37] text-white hover:bg-[#B88C45] shadow-[0_0_20px_rgba(166,124,55,0.3)]'
                                    : 'bg-white/5 text-white border border-white/10 hover:bg-white/10'
                                }`}
                            >
                                {plan.cta}
                            </button>
                        </motion.div>
                    ))}
                </div>

                {/* Mobile Indicators */}
                <div className="flex justify-center gap-2 mt-8 md:hidden">
                    {plans.map((_, i) => (
                        <div 
                            key={i}
                            className={`h-1.5 rounded-full transition-all duration-300 ${
                                activeIndex === i ? 'w-6 bg-coffee-medium' : 'w-1.5 bg-white/20'
                            }`}
                        ></div>
                    ))}
                </div>
            </div>
        </section>
    );
}
