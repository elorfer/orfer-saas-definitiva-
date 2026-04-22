'use client';

import Link from 'next/link';
import Image from 'next/image';
import { Mail } from 'lucide-react';

interface FooterProps {
    lang: 'es' | 'en';
}

export default function Footer({ lang }: FooterProps) {
    const currentYear = new Date().getFullYear();

    return (
        <footer className="py-20 border-t border-white/5 bg-black/80">
            <div className="max-w-7xl mx-auto px-6">
                <div className="grid grid-cols-1 md:grid-cols-4 gap-12 lg:gap-24">
                    {/* Brand Section */}
                    <div className="md:col-span-2">
                        <div className="flex items-center gap-2 mb-6">
                            <Image
                                src="/logo.svg"
                                alt="Struky Logo"
                                width={120}
                                height={30}
                                className="w-auto h-14 brightness-125"
                            />
                        </div>
                        <p className="text-gray-400 text-sm leading-relaxed max-w-sm mb-8">
                            {lang === 'es' 
                                ? 'Revolucionamos la creación musical uniendo la Inteligencia Artificial más avanzada con el refinamiento de productores humanos de clase mundial.' 
                                : 'We revolutionize music creation by combining the most advanced Artificial Intelligence with the refinement of world-class human producers.'}
                        </p>

                    </div>

                    {/* Links Section */}
                    <div>
                        <h4 className="text-white font-bold mb-6 tracking-wide uppercase text-xs">
                            {lang === 'es' ? 'Legal' : 'Legal'}
                        </h4>
                        <ul className="space-y-4 text-sm font-medium text-gray-400">
                            <li>
                                <Link href="/terms" className="hover:text-coffee-light transition-colors">
                                    {lang === 'es' ? 'Términos de Servicio' : 'Terms of Service'}
                                </Link>
                            </li>
                            <li>
                                <Link href="/privacy" className="hover:text-coffee-light transition-colors">
                                    {lang === 'es' ? 'Política de Privacidad' : 'Privacy Policy'}
                                </Link>
                            </li>
                            <li>
                                <Link href="/refund" className="hover:text-coffee-light transition-colors">
                                    {lang === 'es' ? 'Política de Reembolso' : 'Refund Policy'}
                                </Link>
                            </li>
                        </ul>
                    </div>

                    {/* Contact Section */}
                    <div>
                        <h4 className="text-white font-bold mb-6 tracking-wide uppercase text-xs">
                            {lang === 'es' ? 'Contacto' : 'Contact'}
                        </h4>
                        <p className="text-gray-400 text-sm mb-4">
                            {lang === 'es' ? '¿Tienes dudas? Escríbenos.' : 'Any questions? Get in touch.'}
                        </p>
                        <a href="mailto:welcome@struky.com" className="flex items-center gap-2 text-coffee-light hover:text-white transition-colors text-sm font-bold">
                            <Mail className="w-4 h-4" />
                            welcome@struky.com
                        </a>
                    </div>
                </div>

                <div className="mt-20 pt-8 border-t border-white/5 flex flex-col md:flex-row justify-between items-center gap-4">
                    <p className="text-[10px] uppercase tracking-[0.2em] text-gray-500 font-bold">
                        © {currentYear} Struky Music AI. ALL RIGHTS RESERVED.
                    </p>
                    <div className="flex items-center gap-6">
                        <div className="flex items-center gap-2">
                            <span className="w-1.5 h-1.5 rounded-full bg-green-500"></span>
                            <span className="text-[10px] text-gray-500 font-bold uppercase tracking-widest">Server: Latin-1 North</span>
                        </div>
                    </div>
                </div>
            </div>
        </footer>
    );
}
