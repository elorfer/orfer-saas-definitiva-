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
                                src="https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/logoblanco%20web%20p25).webp"
                                alt="Struky Logo"
                                width={120}
                                height={30}
                                className="w-auto h-14 brightness-125"
                                unoptimized
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
                        <div className="space-y-3">
                            <a href="mailto:welcome@struky.com" className="flex items-center gap-2 text-coffee-light hover:text-white transition-colors text-sm font-bold">
                                <Mail className="w-4 h-4" />
                                welcome@struky.com
                            </a>
                            <a href="https://wa.me/573017509921" target="_blank" rel="noopener noreferrer" className="flex items-center gap-2 text-coffee-light hover:text-white transition-colors text-sm font-bold">
                                <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24"><path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z"/></svg>
                                +57 301 750 9921
                            </a>
                        </div>
                        <p className="text-gray-500 text-[10px] mt-4 uppercase tracking-widest font-bold">
                            {lang === 'es' ? '🌎 Servicio 100% digital · Colombia' : '🌎 100% digital service · Colombia'}
                        </p>
                    </div>
                </div>

                <div className="mt-20 pt-8 border-t border-white/5">
                    <p className="text-gray-500 text-[11px] italic mb-8 leading-relaxed max-w-4xl">
                        {lang === 'es' 
                            ? 'Aviso de Transparencia: Todo el contenido mostrado en Struky.com (incluyendo música de ejemplo, arte visual y testimonios representativos) ha sido creado por personas reales y artistas profesionales, potenciado y optimizado mediante nuestra tecnología de Inteligencia Artificial avanzada para garantizar los más altos estándares de calidad y eficiencia en la industria musical.' 
                            : 'Transparency Notice: All content displayed on Struky.com (including example music, visual art, and representative testimonials) has been created by real people and professional artists, powered and optimized through our advanced Artificial Intelligence technology to ensure the highest quality and efficiency standards in the music industry.'}
                    </p>
                    <div className="flex flex-col md:flex-row justify-between items-center gap-4">
                        <p className="text-[10px] uppercase tracking-[0.2em] text-gray-500 font-bold">
                            © {currentYear} Struky Music AI. ALL RIGHTS RESERVED.
                        </p>
                        <div className="flex items-center gap-6">
                            <div className="flex items-center gap-2">
                                <span className="w-1.5 h-1.5 rounded-full bg-green-500 animate-pulse"></span>
                                <span className="text-[10px] text-gray-500 font-bold uppercase tracking-widest">Server: Latin-1 North</span>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </footer>
    );
}
