'use client';

import { useState, useEffect } from 'react';
import Image from 'next/image';
import { Languages, Menu, X } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { playTick, playWhoosh } from '../lib/soundEngine';

interface HeaderProps {
    lang: 'es' | 'en';
    setLang: (lang: 'es' | 'en') => void;
}

export default function Header({ lang, setLang }: HeaderProps) {
    const [isScrolled, setIsScrolled] = useState(false);
    const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

    useEffect(() => {
        let isTicking = false;
        const handleScroll = () => {
            if (!isTicking) {
                window.requestAnimationFrame(() => {
                    setIsScrolled(window.scrollY > 20);
                    isTicking = false;
                });
                isTicking = true;
            }
        };
        window.addEventListener('scroll', handleScroll);
        return () => window.removeEventListener('scroll', handleScroll);
    }, []);

    const navLinks = [
        { name: lang === 'es' ? 'Ejemplos' : 'Examples', href: '#examples' },
        { name: lang === 'es' ? 'Cómo Funciona' : 'How it Works', href: '#how-it-works' },
        { name: lang === 'es' ? 'Precios' : 'Pricing', href: '#pricing' },
        { name: lang === 'es' ? 'FAQ' : 'FAQ', href: '#faq' },
    ];

    const handleNavClick = (e: React.MouseEvent<HTMLAnchorElement>, href: string) => {
        e.preventDefault();
        setMobileMenuOpen(false);
        const element = document.querySelector(href);
        if (element) {
            let headerOffset = 80;
            
            // Add extra offset for sections with overlapping elements (like the Mascot in Examples)
            if (href === '#examples') {
                headerOffset = 180;
            }

            const elementPosition = element.getBoundingClientRect().top;
            const offsetPosition = elementPosition + window.pageYOffset - headerOffset;

            window.scrollTo({
                top: offsetPosition,
                behavior: 'smooth'
            });
        }
    };

    return (
        <>
            <header 
                className={`fixed top-0 left-0 right-0 z-50 transition-all duration-500 ${
                    isScrolled || mobileMenuOpen ? 'py-4 glass-morphism' : 'py-6 bg-transparent'
                }`}
            >
                <div className="max-w-7xl mx-auto px-6 flex items-center justify-between">
                    {/* Logo */}
                    <div className="flex items-center gap-3 cursor-pointer group z-[60]" onClick={() => window.scrollTo({ top: 0, behavior: 'smooth' })}>
                        <div className="relative w-10 h-10 md:w-12 md:h-12 transition-transform duration-300 group-hover:scale-110">
                            <Image
                                src="https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/logoblanco%20web%20p25).webp"
                                alt="Struky Logo Icon"
                                fill
                                priority
                                className="object-contain brightness-125"
                                unoptimized
                            />
                        </div>
                        <span className="text-2xl md:text-3xl font-black tracking-tighter text-gradient leading-none font-heading mt-1">
                            STRUKY
                        </span>
                    </div>

                    {/* Desktop Navigation */}
                    <nav className="hidden lg:flex items-center gap-8">
                        {navLinks.map((link) => (
                            <a
                                key={link.href}
                                href={link.href}
                                onClick={(e) => handleNavClick(e, link.href)}
                                className="text-sm font-bold text-gray-400 hover:text-white transition-colors tracking-wide uppercase"
                            >
                                {link.name}
                            </a>
                        ))}
                    </nav>

                    {/* Actions */}
                    <div className="flex items-center gap-4 md:gap-6 z-[60]">
                        <button 
                            onClick={() => {
                                playTick();
                                setLang(lang === 'es' ? 'en' : 'es');
                            }}
                            className="hidden sm:flex items-center gap-2 px-3 py-1.5 rounded-full border border-white/10 hover:bg-white/5 transition-colors text-xs font-bold text-gray-300 uppercase tracking-widest"
                        >
                            <Languages className="w-3.5 h-3.5 opacity-70" />
                            <span>{lang === 'es' ? 'EN' : 'ES'}</span>
                        </button>
                        
                        <a 
                            href="#order-form" 
                            onClick={(e) => handleNavClick(e, '#order-form')}
                            className="hidden sm:block btn-primary py-2.5 px-6 text-[10px] uppercase tracking-[0.2em]"
                        >
                            {lang === 'es' ? 'Empezar' : 'Get Started'}
                        </a>

                        {/* Mobile Menu Toggle */}
                        <button 
                            className="lg:hidden w-10 h-10 flex items-center justify-center text-white bg-white/5 rounded-full border border-white/10"
                            onClick={() => {
                                playTick();
                                setMobileMenuOpen(!mobileMenuOpen);
                            }}
                        >
                            {mobileMenuOpen ? <X className="w-5 h-5" /> : <Menu className="w-5 h-5" />}
                        </button>
                    </div>
                </div>
            </header>

            {/* Mobile Menu Overlay */}
            <AnimatePresence>
                {mobileMenuOpen && (
                    <motion.div
                        initial={{ opacity: 0, y: -20 }}
                        animate={{ opacity: 1, y: 0 }}
                        exit={{ opacity: 0, y: -20 }}
                        transition={{ duration: 0.3, ease: 'easeOut' }}
                        className="fixed inset-0 z-40 lg:hidden bg-black/95 backdrop-blur-xl flex flex-col items-center justify-center pt-20"
                    >
                        <motion.nav 
                            className="flex flex-col items-center gap-8 mb-12"
                            initial="closed"
                            animate="open"
                            exit="closed"
                            variants={{
                                open: { transition: { staggerChildren: 0.1, delayChildren: 0.1 } },
                                closed: { transition: { staggerChildren: 0.05, staggerDirection: -1 } }
                            }}
                        >
                            {navLinks.map((link) => (
                                <motion.a
                                    key={link.href}
                                    href={link.href}
                                    onClick={(e) => handleNavClick(e, link.href)}
                                    className="text-2xl font-black text-white hover:text-coffee-medium transition-colors tracking-tighter"
                                    variants={{
                                        open: { y: 0, opacity: 1, transition: { type: "spring", stiffness: 300, damping: 24 } },
                                        closed: { y: 20, opacity: 0 }
                                    }}
                                >
                                    {link.name}
                                </motion.a>
                            ))}
                        </motion.nav>
                        
                        <motion.div 
                            className="flex flex-col items-center gap-6"
                            initial={{ opacity: 0, scale: 0.9 }}
                            animate={{ opacity: 1, scale: 1 }}
                            transition={{ delay: 0.4, duration: 0.3 }}
                        >
                            <button 
                                onClick={() => {
                                    setLang(lang === 'es' ? 'en' : 'es');
                                    setMobileMenuOpen(false);
                                }}
                                className="flex items-center gap-3 px-6 py-3 rounded-full border border-white/10 text-lg font-bold"
                            >
                                <Languages className="w-5 h-5 text-coffee-medium" />
                                <span>{lang === 'es' ? 'Switch to English' : 'Cambiar a Español'}</span>
                            </button>

                            <a 
                                href="#order-form" 
                                onClick={(e) => handleNavClick(e, '#order-form')}
                                className="btn-primary py-4 px-12 text-lg"
                            >
                                {lang === 'es' ? 'Empezar ahora' : 'Start now'}
                            </a>
                        </motion.div>
                    </motion.div>
                )}
            </AnimatePresence>
        </>
    );
}
