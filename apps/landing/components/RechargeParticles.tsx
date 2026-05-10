'use client';

import React, { useEffect, useState } from 'react';

export default function RechargeParticles() {
    const [particles, setParticles] = useState<{ id: number; left: string; top: string; size: string; duration: string; delay: string; tx: string; ty: string }[]>([]);

    useEffect(() => {
        const generate = () => {
            return Array.from({ length: 40 }, (_, i) => {
                const side = Math.floor(Math.random() * 4);
                let left = '0%';
                let top = '0%';
                
                if (side === 0) { left = `${Math.random() * 100}%`; top = '-10%'; }
                else if (side === 1) { left = '110%'; top = `${Math.random() * 100}%`; }
                else if (side === 2) { left = `${Math.random() * 100}%`; top = '110%'; }
                else { left = '-10%'; top = `${Math.random() * 100}%`; }

                return {
                    id: Math.random(),
                    left,
                    top,
                    size: `${Math.random() * 5 + 2}px`,
                    duration: `${Math.random() * 1.2 + 0.8}s`,
                    delay: `${Math.random() * 3}s`,
                    tx: '50%',
                    ty: '50%',
                };
            });
        };
        setParticles(generate());
    }, []);

    return (
        <div className="absolute inset-0 overflow-hidden pointer-events-none z-0">
            {particles.map((p) => (
                <div
                    key={p.id}
                    className="absolute rounded-full bg-emerald-400 opacity-0 fly-in-v3"
                    style={{
                        left: p.left,
                        top: p.top,
                        width: p.size,
                        height: p.size,
                        '--tx': p.tx,
                        '--ty': p.ty,
                        animationDuration: p.duration,
                        animationDelay: p.delay,
                        boxShadow: '0 0 15px #10b981, 0 0 30px #059669, 0 0 45px #047857',
                    } as any}
                />
            ))}
            <style dangerouslySetInnerHTML={{ __html: `
                @keyframes fly-in-v3-keyframes {
                    0% {
                        opacity: 0;
                        transform: scale(0.3) translate(0, 0);
                    }
                    15% {
                        opacity: 1;
                        transform: scale(1.8);
                    }
                    85% {
                        opacity: 1;
                    }
                    100% {
                        left: var(--tx);
                        top: var(--ty);
                        opacity: 0;
                        transform: scale(0.1) translate(-50%, -50%);
                    }
                }
                .fly-in-v3 {
                    animation: fly-in-v3-keyframes infinite cubic-bezier(0.4, 0, 0.2, 1);
                }
            `}} />
        </div>
    );
}
