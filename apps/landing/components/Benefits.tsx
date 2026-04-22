'use client';

import { ShieldCheck, Zap, Music2 } from 'lucide-react';

export default function Benefits({ t }: { t: any }) {
    const icons = [<Music2 key="1" />, <ShieldCheck key="2" />, <Zap key="3" />];
    const data = [
        { title: t.q1, desc: t.a1 },
        { title: t.q2, desc: t.a2 },
        { title: t.q3, desc: t.a3 }
    ];

    return (
        <section className="section-padding bg-dark-bg">
            <div className="max-w-6xl mx-auto">
                <div className="text-center mb-16">
                    <h2 className="text-3xl md:text-5xl font-bold mb-4">{t.title}</h2>
                </div>

                <div className="grid md:grid-cols-3 gap-8">
                    {data.map((item, i) => (
                        <div 
                            key={i}
                            className="card-dark p-8 flex flex-col items-center text-center group"
                        >
                            <div className="w-16 h-16 rounded-2xl bg-coffee-medium/10 flex items-center justify-center text-coffee-medium mb-6 group-hover:bg-coffee-medium group-hover:text-white transition-all duration-500">
                                {icons[i]}
                            </div>
                            <h3 className="text-xl font-bold mb-4">{item.title}</h3>
                            <p className="text-gray-400 text-sm leading-relaxed">{item.desc}</p>
                        </div>
                    ))}
                </div>
            </div>
        </section>
    );
}
