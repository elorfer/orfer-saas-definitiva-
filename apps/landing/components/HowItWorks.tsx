'use client';

import { Edit3, Headphones, Download } from 'lucide-react';

export default function HowItWorks({ t }: { t: any }) {
    const steps = [
        { icon: <Edit3 />, title: t.s1_t, desc: t.s1_d },
        { icon: <Headphones />, title: t.s2_t, desc: t.s2_d },
        { icon: <Download />, title: t.s3_t, desc: t.s3_d }
    ];

    return (
        <section className="section-padding bg-dark-card/20">
            <div className="max-w-6xl mx-auto">
                <div className="text-center mb-20">
                    <h2 className="text-3xl md:text-5xl font-bold mb-4">{t.title}</h2>
                </div>

                <div className="grid md:grid-cols-3 gap-12 relative">
                    {/* Connection Line (Desktop) */}
                    <div className="hidden md:block absolute top-1/4 left-0 right-0 h-0.5 bg-gradient-to-r from-transparent via-coffee-medium/20 to-transparent z-0"></div>

                    {steps.map((step, i) => (
                        <div 
                            key={i}
                            className="relative z-10 flex flex-col items-center text-center"
                        >
                            <div className="w-20 h-20 rounded-full glass-morphism flex items-center justify-center text-coffee-light mb-8 relative border-2 border-coffee-medium/40">
                                <span className="absolute -top-2 -right-2 w-8 h-8 rounded-full bg-coffee-medium text-white text-xs font-bold flex items-center justify-center shadow-lg">
                                    {i + 1}
                                </span>
                                {step.icon}
                            </div>
                            <h3 className="text-2xl font-bold mb-4">{step.title}</h3>
                            <p className="text-gray-400 max-w-xs mx-auto">{step.desc}</p>
                        </div>
                    ))}
                </div>
            </div>
        </section>
    );
}

