'use client';

import { useState } from 'react';
import Image from 'next/image';
import { ChevronDown, MessageCircleQuestion } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { playTick } from '../lib/soundEngine';

export default function FAQ({ t }: { t: any }) {
    const questions = [
        { q: t.q1, a: t.a1 },
        { q: t.q2, a: t.a2 },
        { q: t.q3, a: t.a3 },
        { q: t.q4, a: t.a4, highlight: true }
    ];

    const [activeIndex, setActiveIndex] = useState<number | null>(null);

    return (
        <section id="faq" className="section-padding bg-dark-card/10 overflow-hidden md:overflow-visible">
            <div className="max-w-3xl mx-auto relative">
                <div className="text-center mb-16 relative z-10 flex flex-col items-center">

                    <div className="inline-flex p-3 rounded-2xl bg-coffee-medium/10 text-coffee-medium mb-4">
                        <MessageCircleQuestion />
                    </div>
                    <h2 className="text-3xl md:text-5xl font-bold mb-4 w-full">{t.title}</h2>
                </div>

                <div className="space-y-4 relative z-10">
                    {questions.map((item, i) => (
                        <div key={i} className="card-dark p-0 overflow-hidden">
                            <button 
                                onClick={() => {
                                    playTick();
                                    setActiveIndex(activeIndex === i ? null : i);
                                }}
                                className="w-full p-6 text-left flex justify-between items-center transition-all hover:bg-white/5"
                            >
                                <span className="font-bold md:text-lg">{item.q}</span>
                                <ChevronDown className={`w-5 h-5 transition-transform duration-300 ${activeIndex === i ? 'rotate-180' : ''}`} />
                            </button>
                            <AnimatePresence>
                                {activeIndex === i && (
                                    <motion.div
                                        initial={{ height: 0, opacity: 0 }}
                                        animate={{ height: 'auto', opacity: 1 }}
                                        exit={{ height: 0, opacity: 0 }}
                                        transition={{ duration: 0.3 }}
                                    >
                                        <div className="px-6 pb-6 text-gray-400 text-sm leading-relaxed border-t border-white/5 pt-4">
                                            {item.a}
                                        </div>
                                    </motion.div>
                                )}
                            </AnimatePresence>
                        </div>
                    ))}
                </div>
            </div>
        </section>
    );
}
