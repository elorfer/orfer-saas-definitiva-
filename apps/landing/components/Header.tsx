'use client';

import { useState, useEffect } from 'react';
import Image from 'next/image';
import { Languages } from 'lucide-react';

interface HeaderProps {
    lang: 'es' | 'en';
    setLang: (lang: 'es' | 'en') => void;
}

export default function Header({ lang, setLang }: HeaderProps) {
    const [isScrolled, setIsScrolled] = useState(false);

    useEffect(() => {
        const handleScroll = () => {
            setIsScrolled(window.scrollY > 20);
        };
        window.addEventListener('scroll', handleScroll);
        return () => window.removeEventListener('scroll', handleScroll);
    }, []);

    return (
        <header 
            className={`fixed top-0 left-0 right-0 z-50 transition-all duration-300 ${
                isScrolled ? 'py-4 glass-morphism backdrop-blur-xl' : 'py-6 bg-transparent'
            }`}
        >
            <div className="max-w-7xl mx-auto px-6 flex items-center justify-between">
                <div className="flex items-center gap-3 cursor-pointer group" onClick={() => window.scrollTo({ top: 0, behavior: 'smooth' })}>
                    <div className="relative w-10 h-10 md:w-12 md:h-12 transition-transform duration-300 group-hover:scale-110">
                        <Image
                            src="/logo.svg"
                            alt="Struky Logo Icon"
                            fill
                            className="object-contain brightness-125"
                        />
                    </div>
                    <span className="text-2xl md:text-3xl font-black tracking-[calc(-0.05em)] text-gradient leading-none font-heading mt-1">
                        STRUKY
                    </span>
                </div>

                <div className="flex items-center gap-6">
                    <button 
                        onClick={() => setLang(lang === 'es' ? 'en' : 'es')}
                        className="flex items-center gap-2 px-3 py-1.5 rounded-full border border-white/10 hover:bg-white/5 transition-colors text-sm font-medium text-gray-300"
                    >
                        <Languages className="w-4 h-4 opacity-70" />
                        <span>{lang === 'es' ? 'English' : 'Español'}</span>
                    </button>
                    
                    <a 
                        href="#order-form" 
                        className="hidden md:block btn-primary py-2 px-6 text-sm"
                    >
                        {lang === 'es' ? 'Empezar' : 'Get Started'}
                    </a>
                </div>
            </div>
        </header>
    );
}
