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
                        <div className="flex gap-4">
                            <a href="#" className="w-10 h-10 rounded-full bg-white/5 flex items-center justify-center hover:bg-coffee-medium/20 hover:text-coffee-light transition-all border border-white/5">
                                <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zm0-2.163c-3.259 0-3.667.014-4.947.072-4.358.2-6.78 2.618-6.98 6.98-.059 1.281-.073 1.689-.073 4.948 0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98-1.281-.059-1.69-.073-4.949-.073zm0 5.838c-3.403 0-6.162 2.759-6.162 6.162s2.759 6.163 6.162 6.163 6.162-2.759 6.162-6.163c0-3.403-2.759-6.162-6.162-6.162zm0 10.162c-2.209 0-4-1.79-4-4 0-2.209 1.791-4 4-4s4 1.791 4 4c0 2.21-1.791 4-4 4zm6.406-11.845c-.796 0-1.441.645-1.441 1.44s.645 1.44 1.441 1.44c.795 0 1.439-.645 1.439-1.44s-.644-1.44-1.439-1.44z"/></svg>
                            </a>
                            <a href="#" className="w-10 h-10 rounded-full bg-white/5 flex items-center justify-center hover:bg-coffee-medium/20 hover:text-coffee-light transition-all border border-white/5">
                                <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M23.953 4.57a10 10 0 01-2.825.775 4.958 4.958 0 002.163-2.723c-.951.555-2.005.959-3.127 1.184a4.92 4.92 0 00-8.384 4.482C7.69 8.095 4.067 6.13 1.64 3.162a4.822 4.822 0 00-.666 2.475c0 1.71.87 3.213 2.188 4.096a4.904 4.904 0 01-2.228-.616v.06a4.923 4.923 0 003.946 4.84 4.996 4.996 0 01-2.212.085 4.936 4.936 0 004.604 3.417 9.867 9.867 0 01-6.102 2.105c-.39 0-.779-.023-1.17-.067a13.995 13.995 0 007.557 2.209c9.053 0 13.998-7.496 13.998-13.985 0-.21 0-.42-.015-.63A9.935 9.935 0 0024 4.59z"/></svg>
                            </a>
                            <a href="#" className="w-10 h-10 rounded-full bg-white/5 flex items-center justify-center hover:bg-coffee-medium/20 hover:text-coffee-light transition-all border border-white/5">
                                <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M19.615 3.184c-3.604-.246-11.631-.245-15.23 0-3.897.266-4.356 2.62-4.385 8.816.029 6.185.484 8.549 4.385 8.816 3.6.245 11.626.246 15.23 0 3.897-.266 4.356-2.62 4.385-8.816-.029-6.185-.484-8.549-4.385-8.816zm-10.615 12.816v-8l8 3.993-8 4.007z"/></svg>
                            </a>
                        </div>
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
