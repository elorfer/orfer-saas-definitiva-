'use client';

import { useState, useEffect } from 'react';
import Image from 'next/image';
import Link from 'next/link';

export default function HomePage() {
    const [formData, setFormData] = useState({
        name: '',
        email: '',
        lyrics: '',
        genre: 'Pop',
    });

    const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => {
        const { name, value } = e.target;
        setFormData(prev => ({ ...prev, [name]: value }));
    };

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();

        // Aquí se integraría con Lemon Squeezy
        // Por ahora, redirigimos a un checkout placeholder
        console.log('Datos del formulario:', formData);

        // Ejemplo de integración con Lemon Squeezy
        // window.LemonSqueezy.Url.Open('https://tu-tienda.lemonsqueezy.com/checkout/buy/PRODUCT_ID');

        // Temporal: Redirigir a WhatsApp hasta que Lemon Squeezy esté aprobado
        const message = encodeURIComponent('¡Hola! Me interesa el servicio de producción musical con IA por $99. ¿Podemos hablar?');
        window.open(`https://wa.me/573009012217?text=${message}`, '_blank');
    };

    const scrollToForm = () => {
        document.getElementById('order-form')?.scrollIntoView({ behavior: 'smooth' });
    };

    // Pausar otros reproductores cuando uno empieza a reproducir
    useEffect(() => {
        const audioElements = document.querySelectorAll('audio');

        const handlePlay = (e: Event) => {
            audioElements.forEach(audio => {
                if (audio !== e.target) {
                    audio.pause();
                }
            });
        };

        audioElements.forEach(audio => {
            audio.addEventListener('play', handlePlay);
        });

        return () => {
            audioElements.forEach(audio => {
                audio.removeEventListener('play', handlePlay);
            });
        };
    }, []);

    return (
        <div className="min-h-screen">
            {/* HERO SECTION */}
            <section className="relative min-h-screen flex items-center justify-center overflow-hidden">
                {/* Animated Background */}
                <div className="absolute inset-0 z-0">
                    <div className="absolute top-20 left-10 w-72 h-72 bg-neon-purple/20 rounded-full blur-3xl animate-pulse-slow"></div>
                    <div className="absolute bottom-20 right-10 w-96 h-96 bg-neon-blue/20 rounded-full blur-3xl animate-pulse-slow animation-delay-1000"></div>
                </div>

                {/* Content */}
                <div className="relative z-10 max-w-6xl mx-auto px-6 text-center">
                    {/* Logo/Brand */}
                    <div className="mb-8 animate-float">
                        <Image
                            src="/logo.svg"
                            alt="Struky Music AI"
                            width={500}
                            height={125}
                            priority
                            className="mx-auto drop-shadow-2xl"
                        />
                    </div>

                    {/* Nombre de marca */}
                    <h1 className="font-display text-5xl md:text-7xl font-black text-gradient glow-text mb-6">
                        Struky Music AI
                    </h1>

                    {/* Main Headline */}
                    <h2 className="text-4xl md:text-6xl font-bold mb-6 leading-tight">
                        Tus letras, convertidas en <br />
                        <span className="text-gradient">música profesional con IA avanzada</span>
                    </h2>

                    {/* Subtitle */}
                    <p className="text-xl md:text-2xl text-gray-300 mb-8 max-w-3xl mx-auto">
                        <strong className="text-white">Inteligencia artificial de última generación</strong> supervisada y refinada por <strong className="text-neon-purple">productores musicales profesionales humanos</strong>.
                    </p>
                    <p className="text-lg md:text-xl text-gray-400 mb-12 max-w-2xl mx-auto">
                        Tú pones la letra, nosotros entregamos la canción lista para sonar en plataformas digitales.
                    </p>

                    {/* CTA Button */}
                    <button
                        onClick={scrollToForm}
                        className="btn-primary text-xl group relative overflow-hidden"
                    >
                        <span className="relative z-10">Crear mi canción ahora</span>
                        <div className="absolute inset-0 bg-gradient-to-r from-neon-purple to-neon-blue opacity-0 group-hover:opacity-100 transition-opacity duration-300"></div>
                    </button>

                    {/* Scroll Indicator */}
                    <div className="mt-16 animate-bounce">
                        <svg className="w-6 h-6 mx-auto text-neon-purple" fill="none" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" viewBox="0 0 24 24" stroke="currentColor">
                            <path d="M19 14l-7 7m0 0l-7-7m7 7V3"></path>
                        </svg>
                    </div>
                </div>
            </section>

            {/* EXAMPLES SECTION */}
            <section id="examples" className="section-padding bg-dark-bg">
                <div className="max-w-6xl mx-auto">
                    <h2 className="text-4xl md:text-5xl font-display font-bold text-center mb-4">
                        Escucha <span className="text-gradient">nuestros ejemplos</span>
                    </h2>
                    <p className="text-center text-gray-400 mb-16 max-w-2xl mx-auto">
                        Canciones reales creadas con nuestra tecnología de IA avanzada. Cada una <strong className="text-white">supervisada y refinada por productores musicales profesionales</strong>.
                    </p>

                    <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-8">
                        {/* Example 1 */}
                        <div className="card-dark group">
                            <div className="aspect-square bg-gradient-to-br from-neon-purple/20 to-neon-blue/20 rounded-lg mb-4 overflow-hidden relative">
                                <Image
                                    src="/examples/cover1.png"
                                    alt="Amor Eterno Cover"
                                    fill
                                    className="object-cover"
                                    sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 33vw"
                                />
                            </div>
                            <h3 className="text-xl font-bold mb-2">Amor Eterno</h3>
                            <p className="text-sm text-gray-400 mb-4">Pop Romántico • 3:45</p>
                            <audio controls className="w-full mb-3 audio-player">
                                <source src="/examples/ejemplo1.mp3" type="audio/mpeg" />
                                Tu navegador no soporta audio HTML5.
                            </audio>
                            <p className="text-xs text-gray-500">
                                "Una balada emotiva con producción moderna y arreglos profesionales"
                            </p>
                        </div>

                        {/* Example 2 */}
                        <div className="card-dark group">
                            <div className="aspect-square bg-gradient-to-br from-neon-blue/20 to-neon-purple/20 rounded-lg mb-4 overflow-hidden relative">
                                <Image
                                    src="/examples/cover2.png"
                                    alt="Fuego en la Noche Cover"
                                    fill
                                    className="object-cover"
                                    sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 33vw"
                                />
                            </div>
                            <h3 className="text-xl font-bold mb-2">Fuego en la Noche</h3>
                            <p className="text-sm text-gray-400 mb-4">Reggaetón • 3:12</p>
                            <audio controls className="w-full mb-3 audio-player">
                                <source src="/examples/ejemplo2.mp3" type="audio/mpeg" />
                                Tu navegador no soporta audio HTML5.
                            </audio>
                            <p className="text-xs text-gray-500">
                                "Ritmo urbano con beat profesional y producción de nivel comercial"
                            </p>
                        </div>

                        {/* Example 3 */}
                        <div className="card-dark group">
                            <div className="aspect-square bg-gradient-to-br from-neon-purple/20 via-purple-500/20 to-neon-blue/20 rounded-lg mb-4 overflow-hidden relative">
                                <Image
                                    src="/examples/cover3.png"
                                    alt="Sueños de Libertad Cover"
                                    fill
                                    className="object-cover"
                                    sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 33vw"
                                />
                            </div>
                            <h3 className="text-xl font-bold mb-2">Sueños de Libertad</h3>
                            <p className="text-sm text-gray-400 mb-4">Trap • 2:58</p>
                            <audio controls className="w-full mb-3 audio-player">
                                <source src="/examples/ejemplo3.mp3" type="audio/mpeg" />
                                Tu navegador no soporta audio HTML5.
                            </audio>
                            <p className="text-xs text-gray-500">
                                "Trap atmosférico con 808s potentes y mezcla cristalina"
                            </p>
                        </div>
                    </div>

                    <div className="text-center mt-12">
                        <p className="text-gray-400 mb-4">
                            ✨ Cada canción incluye masterización profesional y está lista para distribución
                        </p>
                        <button
                            onClick={scrollToForm}
                            className="btn-secondary"
                        >
                            Quiero crear mi canción
                        </button>
                    </div>
                </div>
            </section>

            {/* HOW IT WORKS SECTION */}
            <section id="how-it-works" className="section-padding bg-gradient-to-b from-dark-bg to-dark-card">
                <div className="max-w-6xl mx-auto">
                    <h2 className="text-4xl md:text-5xl font-display font-bold text-center mb-16">
                        ¿Cómo <span className="text-gradient">funciona</span>?
                    </h2>

                    <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-8">
                        {/* Step 1 */}
                        <div className="card-dark text-center group hover:scale-105 transition-transform duration-300">
                            <div className="w-16 h-16 mx-auto mb-6 rounded-full bg-neon-glow flex items-center justify-center text-2xl font-bold shadow-neon-purple">
                                1
                            </div>
                            <h3 className="text-xl font-bold mb-4">Envías tu letra</h3>
                            <p className="text-gray-400">
                                Escribe o pega tu letra y elige el género musical que prefieras
                            </p>
                        </div>

                        {/* Step 2 */}
                        <div className="card-dark text-center group hover:scale-105 transition-transform duration-300">
                            <div className="w-16 h-16 mx-auto mb-6 rounded-full bg-neon-glow flex items-center justify-center text-2xl font-bold shadow-neon-blue">
                                2
                            </div>
                            <h3 className="text-xl font-bold mb-4">Pago seguro</h3>
                            <p className="text-gray-400">
                                Realiza el pago seguro vía Stripe/Lemon Squeezy
                            </p>
                        </div>

                        {/* Step 3 */}
                        <div className="card-dark text-center group hover:scale-105 transition-transform duration-300">
                            <div className="w-16 h-16 mx-auto mb-6 rounded-full bg-neon-glow flex items-center justify-center text-2xl font-bold shadow-neon-purple">
                                3
                            </div>
                            <h3 className="text-xl font-bold mb-4">IA + Humanos</h3>
                            <p className="text-gray-400">
                                IA avanzada genera la base, productores musicales <strong className="text-white">humanos profesionales</strong> supervisan y refinan cada detalle
                            </p>
                        </div>

                        {/* Step 4 */}
                        <div className="card-dark text-center group hover:scale-105 transition-transform duration-300">
                            <div className="w-16 h-16 mx-auto mb-6 rounded-full bg-neon-glow flex items-center justify-center text-2xl font-bold shadow-neon-blue">
                                4
                            </div>
                            <h3 className="text-xl font-bold mb-4">Recibe tu canción</h3>
                            <p className="text-gray-400">
                                Recibes tu archivo final por WhatsApp/Email en 24-48 horas
                            </p>
                        </div>
                    </div>
                </div>
            </section>

            {/* ORDER FORM SECTION */}
            <section id="order-form" className="section-padding">
                <div className="max-w-3xl mx-auto">
                    <div className="card-dark">
                        <h2 className="text-3xl md:text-4xl font-display font-bold text-center mb-8">
                            Crea tu <span className="text-gradient">canción ahora</span>
                        </h2>

                        <form onSubmit={handleSubmit} className="space-y-6">
                            {/* Name */}
                            <div>
                                <label htmlFor="name" className="block text-sm font-semibold mb-2 text-gray-300">
                                    Tu nombre
                                </label>
                                <input
                                    type="text"
                                    id="name"
                                    name="name"
                                    value={formData.name}
                                    onChange={handleInputChange}
                                    required
                                    className="w-full px-4 py-3 bg-dark-bg border border-gray-700 rounded-lg 
                           focus:outline-none focus:border-neon-purple transition-colors
                           text-white placeholder-gray-500"
                                    placeholder="Ej: Juan Pérez"
                                />
                            </div>

                            {/* Email */}
                            <div>
                                <label htmlFor="email" className="block text-sm font-semibold mb-2 text-gray-300">
                                    Tu email
                                </label>
                                <input
                                    type="email"
                                    id="email"
                                    name="email"
                                    value={formData.email}
                                    onChange={handleInputChange}
                                    required
                                    className="w-full px-4 py-3 bg-dark-bg border border-gray-700 rounded-lg 
                           focus:outline-none focus:border-neon-purple transition-colors
                           text-white placeholder-gray-500"
                                    placeholder="tu@email.com"
                                />
                            </div>

                            {/* Genre */}
                            <div>
                                <label htmlFor="genre" className="block text-sm font-semibold mb-2 text-gray-300">
                                    Género musical
                                </label>
                                <select
                                    id="genre"
                                    name="genre"
                                    value={formData.genre}
                                    onChange={handleInputChange}
                                    required
                                    className="w-full px-4 py-3 bg-dark-bg border border-gray-700 rounded-lg 
                           focus:outline-none focus:border-neon-purple transition-colors
                           text-white"
                                >
                                    <option value="Pop">Pop</option>
                                    <option value="Rock">Rock</option>
                                    <option value="Reggaetón">Reggaetón</option>
                                    <option value="Trap">Trap</option>
                                    <option value="Balada">Balada</option>
                                </select>
                            </div>

                            {/* Lyrics */}
                            <div>
                                <label htmlFor="lyrics" className="block text-sm font-semibold mb-2 text-gray-300">
                                    Tu letra
                                </label>
                                <textarea
                                    id="lyrics"
                                    name="lyrics"
                                    value={formData.lyrics}
                                    onChange={handleInputChange}
                                    required
                                    rows={10}
                                    className="w-full px-4 py-3 bg-dark-bg border border-gray-700 rounded-lg 
                           focus:outline-none focus:border-neon-purple transition-colors
                           text-white placeholder-gray-500 resize-none"
                                    placeholder="Pega aquí la letra de tu canción...&#10;&#10;Verso 1:&#10;...&#10;&#10;Coro:&#10;..."
                                />
                            </div>

                            {/*Price Info */}
                            <div className="bg-dark-bg border border-neon-purple/30 rounded-lg p-6">
                                <div className="flex justify-between items-center mb-2">
                                    <span className="text-lg">Producción completa:</span>
                                    <span className="text-2xl font-bold text-gradient">$99 USD</span>
                                </div>
                                <p className="text-sm text-gray-400">
                                    ✓ IA musical de última generación<br />
                                    ✓ <strong>Supervisión de productores musicales profesionales humanos</strong><br />
                                    ✓ Entrega express en 24-48 horas<br />
                                    ✓ Archivo profesional WAV/MP3 de alta calidad<br />
                                    ✓ Listo para Spotify, Apple Music, YouTube
                                </p>
                            </div>

                            {/* Submit Button */}
                            <button
                                type="submit"
                                className="w-full btn-primary text-lg"
                            >
                                Proceder al pago
                            </button>

                            <p className="text-center text-sm text-gray-400">
                                Pago 100% seguro con Stripe/Lemon Squeezy
                            </p>
                        </form>
                    </div>
                </div>
            </section>

            {/* FOOTER */}
            <footer className="bg-dark-card border-t border-gray-800 py-12">
                <div className="max-w-6xl mx-auto px-6">
                    <div className="grid md:grid-cols-4 gap-8 mb-8">
                        {/* Brand */}
                        <div className="md:col-span-2">
                            <h3 className="font-display text-2xl font-bold text-gradient mb-4">
                                Struky Music AI
                            </h3>
                            <p className="text-gray-400 mb-4">
                                Producción musical con <strong className="text-white">IA avanzada supervisada por productores profesionales humanos</strong>. Transformamos tus letras en canciones de calidad profesional listas para distribuir en plataformas digitales.
                            </p>
                        </div>

                        {/* Legal Links */}
                        <div>
                            <h4 className="font-semibold mb-4">Legal</h4>
                            <ul className="space-y-2">
                                <li>
                                    <Link href="/privacy" className="text-gray-400 hover:text-neon-purple transition-colors">
                                        Política de Privacidad
                                    </Link>
                                </li>
                                <li>
                                    <Link href="/terms" className="text-gray-400 hover:text-neon-purple transition-colors">
                                        Términos de Servicio
                                    </Link>
                                </li>
                                <li>
                                    <Link href="/refund" className="text-gray-400 hover:text-neon-purple transition-colors">
                                        Política de Reembolso
                                    </Link>
                                </li>
                            </ul>
                        </div>

                        {/* Contact */}
                        <div>
                            <h4 className="font-semibold mb-4">Contacto</h4>
                            <ul className="space-y-2">
                                <li>
                                    <a href="mailto:strukyapp@gmail.com" className="text-gray-400 hover:text-neon-purple transition-colors">
                                        strukyapp@gmail.com
                                    </a>
                                </li>
                                <li>
                                    <a
                                        href="https://wa.me/573009012217"
                                        target="_blank"
                                        rel="noopener noreferrer"
                                        className="text-gray-400 hover:text-neon-purple transition-colors flex items-center gap-2"
                                    >
                                        <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                                            <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413Z" />
                                        </svg>
                                        WhatsApp
                                    </a>
                                </li>
                            </ul>
                        </div>
                    </div>

                    {/* Copyright */}
                    <div className="border-t border-gray-800 pt-8 text-center text-gray-400 text-sm">
                        <p>© {new Date().getFullYear()} Struky Music AI. Todos los derechos reservados.</p>
                        <p className="mt-2">
                            Inteligencia artificial de última generación supervisada y refinada por productores musicales profesionales humanos.
                        </p>
                    </div>
                </div>
            </footer>
        </div>
    );
}
