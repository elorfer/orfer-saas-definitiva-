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
        customGenre: '',
        vocalist: 'Sin preferencia',
        mood: 'Feliz',
        referenceTrack: '',
        notes: '',
    });

    const [faqOpen, setFaqOpen] = useState<number | null>(null);

    const toggleFaq = (index: number) => {
        setFaqOpen(faqOpen === index ? null : index);
    };

    const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => {
        const { name, value } = e.target;
        setFormData(prev => ({ ...prev, [name]: value }));
    };

    const [isLoading, setIsLoading] = useState(false);

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        
        setIsLoading(true);

        try {
            const response = await fetch('/api/checkout', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(formData),
            });

            const data = await response.json();

            if (data.url) {
                // Redirigir al Checkout Seguro de Stripe
                window.location.href = data.url;
            } else {
                alert('No se pudo iniciar el checkout: ' + (data.error || 'Error desconocido'));
            }
        } catch (error) {
            console.error('Error:', error);
            alert('Error de conexión. Revisa tu internet e intenta de nuevo.');
        } finally {
            setIsLoading(false);
        }
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
                {/* Background Image & Gradient overlay */}
                <div className="absolute inset-0 z-0">
                    <Image
                        src="/hero-bg.png"
                        alt="High-end Music Studio"
                        fill
                        className="object-cover opacity-60"
                        priority
                        quality={100}
                    />
                    <div className="absolute inset-0 bg-gradient-to-b from-dark-bg/90 via-dark-bg/50 to-dark-bg"></div>
                    {/* Animated Glow over image */}
                    <div className="absolute top-1/4 left-1/4 w-96 h-96 bg-coffee-medium/20 rounded-full blur-3xl animate-pulse-slow mix-blend-screen"></div>
                </div>

                {/* Content */}
                <div className="relative z-10 max-w-6xl mx-auto px-6 text-center pt-20">
                    {/* Logo/Brand */}
                    <div className="mb-12 animate-float">
                        <Image
                            src="/logo.svg"
                            alt="Struky Music AI"
                            width={220}
                            height={55}
                            priority
                            className="mx-auto drop-shadow-[0_0_15px_rgba(255,255,255,0.1)] w-[180px] md:w-[220px]"
                        />
                    </div>

                    {/* Nombre de marca */}
                    <h1 className="font-display text-5xl md:text-7xl font-black text-gradient glow-text mb-6">
                        Struky Music AI
                    </h1>

                    {/* Main Headline */}
                    <h2 className="text-4xl md:text-6xl font-bold mb-6 leading-tight">
                        Da vida a tus composiciones.<br />
                        <span className="text-gradient">Tus letras hechas canciones de estudio</span>
                    </h2>

                    {/* Subtitle */}
                    <p className="text-xl md:text-2xl text-gray-300 mb-8 max-w-3xl mx-auto">
                        No dejes tus mejores letras guardadas en un cajón. Logra ese sonido profesional que buscan los artistas, trabajando con <strong className="text-coffee-light">IA avanzada + productores humanos</strong>.
                    </p>
                    <p className="text-lg md:text-xl text-gray-400 mb-12 max-w-2xl mx-auto">
                        Tú pones la inspiración, nosotros entregamos la canción lista para distribución.
                    </p>

                    {/* CTA Buttons */}
                    <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
                        <button
                            onClick={scrollToForm}
                            className="btn-primary text-xl group relative overflow-hidden"
                        >
                            <span className="relative z-10">Crear mi canción ahora</span>
                            <div className="absolute inset-0 bg-gradient-to-r from-coffee-medium to-coffee-dark opacity-0 group-hover:opacity-100 transition-opacity duration-300"></div>
                        </button>
                        <a 
                            href="#examples" 
                            className="btn-secondary text-xl border border-coffee-medium hover:bg-coffee-medium/20 text-white rounded-lg px-8 py-3 transition-colors text-center"
                        >
                            Escuchar Ejemplos
                        </a>
                    </div>

                    {/* Scroll Indicator */}
                    <div className="mt-16 animate-bounce">
                        <svg className="w-6 h-6 mx-auto text-coffee-medium" fill="none" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" viewBox="0 0 24 24" stroke="currentColor">
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
                            <div className="aspect-square bg-gradient-to-br from-coffee-medium/20 to-coffee-light/20 rounded-lg mb-4 overflow-hidden relative">
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
                            <div className="aspect-square bg-gradient-to-br from-coffee-light/20 to-coffee-medium/20 rounded-lg mb-4 overflow-hidden relative">
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
                            <div className="aspect-square bg-gradient-to-br from-coffee-medium/20 via-coffee-light/20 to-coffee-dark/20 rounded-lg mb-4 overflow-hidden relative">
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

            {/* ERROR VS SOLUCIÓN: ANTES Y DESPUÉS */}
            <section className="section-padding bg-coffee-dark/10 border-y border-coffee-medium/20">
                <div className="max-w-4xl mx-auto text-center px-4">
                    <div className="inline-block px-4 py-1.5 rounded-full bg-coffee-medium/20 text-coffee-light text-sm font-bold mb-6">
                        El secreto de nuestro sonido
                    </div>
                    <h2 className="text-3xl md:text-5xl font-display font-bold mb-6">
                        No suena a <span className="text-gradient">robot</span>, suena a un <strong className="text-white">hit</strong>
                    </h2>
                    <p className="text-gray-400 mb-12 max-w-2xl mx-auto text-lg">
                        Escucha la diferencia real entre la inteligencia artificial cruda (con voces metálicas y ruido) y la pista final después de pasar por el <strong className="text-white">estudio de un productor humano</strong>.
                    </p>

                    <div className="grid md:grid-cols-2 gap-8 mb-10 text-left">
                        {/* ANTES */}
                        <div className="card-dark border-gray-800 bg-black/40">
                            <div className="flex items-center gap-3 mb-4">
                                <div className="w-10 h-10 rounded-full bg-red-500/20 text-red-400 flex items-center justify-center font-bold text-xl">❌</div>
                                <div>
                                    <h3 className="font-bold text-lg">Antes (IA Cruda)</h3>
                                    <p className="text-xs text-gray-500">Suno / Udio estándar</p>
                                </div>
                            </div>
                            <ul className="text-sm text-gray-400 mb-6 space-y-2">
                                <li>• Voces robóticas/metálicas</li>
                                <li>• Ruido digital de fondo</li>
                                <li>• Bajos borrosos sin definición</li>
                                <li>• Volumen inestable</li>
                            </ul>
                        </div>

                        {/* DESPUÉS */}
                        <div className="card-dark border-coffee-medium/50 relative overflow-hidden">
                            <div className="absolute top-0 right-0 w-32 h-32 bg-coffee-medium/20 blur-3xl rounded-full"></div>
                            <div className="flex items-center gap-3 mb-4 relative z-10">
                                <div className="w-10 h-10 rounded-full bg-green-500/20 text-green-400 flex items-center justify-center font-bold text-xl">✅</div>
                                <div>
                                    <h3 className="font-bold text-lg text-white">Después (Struky AI)</h3>
                                    <p className="text-xs text-coffee-light">Máster humano + Limpieza</p>
                                </div>
                            </div>
                            <ul className="text-sm text-gray-300 mb-6 space-y-2 relative z-10">
                                <li>• Voces que cortan la mezcla</li>
                                <li>• Audio cristalino y natural</li>
                                <li>• Mastering para Spotify (LUFS)</li>
                                <li>• Pegada comercial real</li>
                            </ul>
                        </div>
                    </div>
                    
                    <button onClick={scrollToForm} className="btn-primary flex items-center gap-2 mx-auto shadow-lg shadow-coffee-medium/20 hover:shadow-coffee-medium/40">
                        Quiero esta calidad para mi letra
                    </button>
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
                            <div className="w-16 h-16 mx-auto mb-6 rounded-full bg-neon-glow flex items-center justify-center text-2xl font-bold shadow-coffee-medium">
                                1
                            </div>
                            <h3 className="text-xl font-bold mb-4">Envías tu letra</h3>
                            <p className="text-gray-400">
                                Escribe o pega tu letra y elige el género musical que prefieras
                            </p>
                        </div>

                        {/* Step 2 */}
                        <div className="card-dark text-center group hover:scale-105 transition-transform duration-300">
                            <div className="w-16 h-16 mx-auto mb-6 rounded-full bg-neon-glow flex items-center justify-center text-2xl font-bold shadow-coffee-dark">
                                2
                            </div>
                            <h3 className="text-xl font-bold mb-4">Pago seguro</h3>
                            <p className="text-gray-400">
                                Realiza el pago seguro vía Stripe/Lemon Squeezy
                            </p>
                        </div>

                        {/* Step 3 */}
                        <div className="card-dark text-center group hover:scale-105 transition-transform duration-300">
                            <div className="w-16 h-16 mx-auto mb-6 rounded-full bg-neon-glow flex items-center justify-center text-2xl font-bold shadow-coffee-medium">
                                3
                            </div>
                            <h3 className="text-xl font-bold mb-4">IA + Humanos</h3>
                            <p className="text-gray-400">
                                IA avanzada genera la base, productores musicales <strong className="text-white">humanos profesionales</strong> supervisan y refinan cada detalle
                            </p>
                        </div>

                        {/* Step 4 */}
                        <div className="card-dark text-center group hover:scale-105 transition-transform duration-300">
                            <div className="w-16 h-16 mx-auto mb-6 rounded-full bg-neon-glow flex items-center justify-center text-2xl font-bold shadow-coffee-dark">
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

            {/* HUMAN TOUCH BANNER */}
            <section className="relative py-24 overflow-hidden border-y border-coffee-medium/20">
                <div className="absolute inset-0 z-0">
                    <Image
                        src="/studio-banner.webp"
                        alt="Productores humanos y compositores trabajando en el estudio"
                        fill
                        className="object-cover"
                        sizes="100vw"
                        quality={90}
                    />
                    {/* Overlay: completely dark on the left blending to somewhat transparent on the right */}
                    <div className="absolute inset-0 bg-gradient-to-r from-dark-bg via-dark-bg/80 to-transparent"></div>
                    {/* Additional general dark overlay for readability on small screens where image stacks */}
                    <div className="absolute inset-0 bg-black/40 sm:hidden"></div>
                </div>

                <div className="relative z-10 max-w-6xl mx-auto px-6">
                    <div className="max-w-xl">
                        <h2 className="text-3xl md:text-5xl font-display font-bold mb-6 leading-tight">
                            El <span className="text-gradient">factor humano</span> marca la diferencia
                        </h2>
                        <p className="text-lg text-gray-300 mb-6">
                            La Inteligencia Artificial genera ideas increíbles, pero <strong className="text-white">solo un productor real le da el nivel comercial</strong>. 
                        </p>
                        <p className="text-gray-400 mb-8">
                            Nos sentamos en el estudio con equipos profesionales para refinar lo que la máquina creó. Limpiamos ruidos, arreglamos fallos y aplicamos un máster analógico para que tu canción suene enorme en Spotify o Apple Music.
                        </p>
                        
                        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                            <div className="flex items-center gap-3">
                                <div className="w-8 h-8 rounded-full bg-coffee-medium/20 text-coffee-medium flex items-center justify-center font-bold">✓</div>
                                <span className="text-sm font-semibold text-gray-200">Mix & Máster Pro</span>
                            </div>
                            <div className="flex items-center gap-3">
                                <div className="w-8 h-8 rounded-full bg-coffee-medium/20 text-coffee-medium flex items-center justify-center font-bold">✓</div>
                                <span className="text-sm font-semibold text-gray-200">Limpieza de Audio</span>
                            </div>
                            <div className="flex items-center gap-3">
                                <div className="w-8 h-8 rounded-full bg-coffee-medium/20 text-coffee-medium flex items-center justify-center font-bold">✓</div>
                                <span className="text-sm font-semibold text-gray-200">Toque Artístico</span>
                            </div>
                            <div className="flex items-center gap-3">
                                <div className="w-8 h-8 rounded-full bg-coffee-medium/20 text-coffee-medium flex items-center justify-center font-bold">✓</div>
                                <span className="text-sm font-semibold text-gray-200">Volumen LUFS exacto</span>
                            </div>
                        </div>
                    </div>
                </div>
            </section>

            {/* TARGET AUDIENCE SECTION */}
            <section className="py-20 bg-dark-bg">
                <div className="max-w-6xl mx-auto px-6">
                    <h2 className="text-3xl md:text-5xl font-display font-bold text-center mb-16">
                        ¿Para quién es <span className="text-gradient">esto?</span>
                    </h2>
                    <div className="grid md:grid-cols-3 gap-8">
                        <div className="text-center">
                            <div className="w-16 h-16 mx-auto bg-coffee-medium/10 border border-coffee-medium/20 rounded-full flex items-center justify-center text-3xl mb-4 shadow-lg shadow-coffee-medium/5">✍️</div>
                            <h3 className="text-xl font-bold mb-3">Letristas y Poetas</h3>
                            <p className="text-gray-400 text-sm">Tienes cuadernos llenos de versos increíbles pero no cantas o no tocas instrumentos. Dales vida comercial hoy y retén el 100% de las regalías.</p>
                        </div>
                        <div className="text-center">
                            <div className="w-16 h-16 mx-auto bg-coffee-medium/10 border border-coffee-medium/20 rounded-full flex items-center justify-center text-3xl mb-4 shadow-lg shadow-coffee-medium/5">🎸</div>
                            <h3 className="text-xl font-bold mb-3">Músicos Solistas</h3>
                            <p className="text-gray-400 text-sm">¿Tienes la melodía pero te falta la producción, la percusión y los arreglos pesados? Nosotros construimos la pista alrededor de tu idea.</p>
                        </div>
                        <div className="text-center">
                            <div className="w-16 h-16 mx-auto bg-coffee-medium/10 border border-coffee-medium/20 rounded-full flex items-center justify-center text-3xl mb-4 shadow-lg shadow-coffee-medium/5">🎁</div>
                            <h3 className="text-xl font-bold mb-3">Regalos Inolvidables</h3>
                            <p className="text-gray-400 text-sm">Convierte tu historia de amor, votos matrimoniales o un simple poema para un ser querido en una canción de radio impecable y mágica.</p>
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
                           focus:outline-none focus:border-coffee-medium transition-colors
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
                           focus:outline-none focus:border-coffee-medium transition-colors
                           text-white placeholder-gray-500"
                                    placeholder="tu@email.com"
                                />
                            </div>

                            {/* Genre */}
                            <div>
                                <label htmlFor="genre" className="block text-sm font-semibold mb-2 text-gray-300">
                                    Género musical principal
                                </label>
                                <select
                                    id="genre"
                                    name="genre"
                                    value={formData.genre}
                                    onChange={handleInputChange}
                                    required
                                    className="w-full px-4 py-3 bg-dark-bg border border-gray-700 rounded-lg 
                           focus:outline-none focus:border-coffee-medium transition-colors
                           text-white"
                                >
                                    <option value="Pop">Pop</option>
                                    <option value="Reggaetón">Reggaetón / Urbano</option>
                                    <option value="Salsa">Salsa</option>
                                    <option value="Bachata">Bachata</option>
                                    <option value="Merengue">Merengue</option>
                                    <option value="Cumbia">Cumbia / Vallenato</option>
                                    <option value="Regional Mexicano">Regional Mexicano (Banda, Corridos)</option>
                                    <option value="Rock">Rock / Indie</option>
                                    <option value="Trap">Trap</option>
                                    <option value="Balada">Balada Romántica</option>
                                    <option value="Otro">Otro (Lo describo abajo)</option>
                                </select>
                            </div>

                            {/* Custom Genre (Conditional) */}
                            {formData.genre === 'Otro' && (
                                <div className="animate-in fade-in slide-in-from-top-2 duration-300">
                                    <label htmlFor="customGenre" className="block text-sm font-semibold mb-2 text-coffee-light">
                                        ¿Qué género o mezcla buscas?
                                    </label>
                                    <input
                                        type="text"
                                        id="customGenre"
                                        name="customGenre"
                                        value={formData.customGenre}
                                        onChange={handleInputChange}
                                        required={formData.genre === 'Otro'}
                                        className="w-full px-4 py-3 bg-dark-bg border border-coffee-medium/60 rounded-lg 
                               focus:outline-none focus:border-coffee-medium focus:ring-1 focus:ring-coffee-medium transition-colors
                               text-white placeholder-gray-500"
                                        placeholder="Ej: Mezcla de Pop Punk con Electrónica oscura..."
                                    />
                                </div>
                            )}

                            {/* Vocalist */}
                            <div>
                                <label htmlFor="vocalist" className="block text-sm font-semibold mb-2 text-gray-300">
                                    Voz Principal
                                </label>
                                <select
                                    id="vocalist"
                                    name="vocalist"
                                    value={formData.vocalist}
                                    onChange={handleInputChange}
                                    required
                                    className="w-full px-4 py-3 bg-dark-bg border border-gray-700 rounded-lg 
                           focus:outline-none focus:border-coffee-medium transition-colors
                           text-white"
                                >
                                    <option value="Sin preferencia">Sin preferencia</option>
                                    <option value="Voz Femenina">Voz Femenina</option>
                                    <option value="Voz Masculina">Voz Masculina</option>
                                    <option value="Dueto">Dueto (M y F)</option>
                                </select>
                            </div>

                            {/* Mood */}
                            <div>
                                <label htmlFor="mood" className="block text-sm font-semibold mb-2 text-gray-300">
                                    Estado de Ánimo (Mood)
                                </label>
                                <select
                                    id="mood"
                                    name="mood"
                                    value={formData.mood}
                                    onChange={handleInputChange}
                                    required
                                    className="w-full px-4 py-3 bg-dark-bg border border-gray-700 rounded-lg 
                           focus:outline-none focus:border-coffee-medium transition-colors
                           text-white"
                                >
                                    <option value="Feliz">Feliz / Upbeat</option>
                                    <option value="Triste">Triste / Melancólico</option>
                                    <option value="Épico">Épico / Cinemático</option>
                                    <option value="Urbano">Urbano / Calle</option>
                                    <option value="Íntimo">Íntimo / Acústico</option>
                                </select>
                            </div>

                            {/* Reference Track */}
                            <div>
                                <label htmlFor="referenceTrack" className="block text-sm font-semibold mb-2 text-gray-300">
                                    Track de Referencia (Opcional)
                                </label>
                                <input
                                    type="url"
                                    id="referenceTrack"
                                    name="referenceTrack"
                                    value={formData.referenceTrack}
                                    onChange={handleInputChange}
                                    className="w-full px-4 py-3 bg-dark-bg border border-gray-700 rounded-lg 
                           focus:outline-none focus:border-coffee-medium transition-colors
                           text-white placeholder-gray-500"
                                    placeholder="Link de YouTube/Spotify..."
                                />
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
                           focus:outline-none focus:border-coffee-medium transition-colors
                           text-white placeholder-gray-500 resize-none"
                                    placeholder="Pega aquí la letra de tu canción...&#10;&#10;Verso 1:&#10;...&#10;&#10;Coro:&#10;..."
                                />
                            </div>

                            {/* Additional Notes */}
                            <div>
                                <label htmlFor="notes" className="block text-sm font-semibold mb-2 text-gray-300">
                                    Notas para el Productor Humano (Opcional)
                                </label>
                                <textarea
                                    id="notes"
                                    name="notes"
                                    value={formData.notes}
                                    onChange={handleInputChange}
                                    rows={3}
                                    className="w-full px-4 py-3 bg-dark-bg border border-gray-700 rounded-lg 
                           focus:outline-none focus:border-coffee-medium transition-colors
                           text-white placeholder-gray-500 resize-none"
                                    placeholder="Ej: Quiero que el coro explote en el minuto 1:20..."
                                />
                            </div>

                            {/* Price Anchoring & Scarcity */}
                            <div className="mt-8 space-y-6">
                                <div className="flex flex-col md:flex-row gap-6 p-6 md:p-8 bg-black/40 border border-gray-800 rounded-xl relative overflow-hidden">
                                    <div className="absolute top-0 right-0 w-32 h-32 bg-red-500/5 rounded-full blur-2xl"></div>
                                    <div className="flex-1 opacity-70">
                                        <h4 className="text-red-400 text-sm font-bold uppercase tracking-wider mb-2">Estudio Tradicional ❌</h4>
                                        <p className="text-3xl font-bold text-gray-500 line-through decoration-red-500/50 mb-2">~$500 USD</p>
                                        <p className="text-xs text-gray-500">Músicos, tiempo de estudio, ingeniero y vocalistas.</p>
                                    </div>

                                    <div className="hidden md:block w-px bg-gray-800"></div>

                                    <div className="flex-1 relative z-10">
                                        <h4 className="text-coffee-medium text-sm font-bold uppercase tracking-wider mb-2">Tu Producción Struky ✅</h4>
                                        <div className="flex items-end gap-2 mb-2">
                                            <p className="text-4xl font-black text-white">$50 <span className="text-xl text-gray-400 font-medium">USD</span></p>
                                        </div>
                                        <ul className="text-sm text-gray-300 space-y-1 mt-3">
                                            <li className="flex gap-2"><span className="text-coffee-medium font-bold">✓</span> Canción lista en 24-48 hrs</li>
                                            <li className="flex gap-2"><span className="text-coffee-medium font-bold">✓</span> <strong>Masterizada por humanos</strong></li>
                                            <li className="flex gap-2"><span className="text-coffee-medium font-bold">✓</span> Calidad Spotify Premium</li>
                                            <li className="flex gap-2"><span className="text-coffee-medium font-bold">✓</span> 100% Derechos para ti</li>
                                        </ul>
                                    </div>
                                </div>
                                
                                {/* Scarcity Banner */}
                                <div className="bg-amber-500/10 border border-amber-500/30 rounded-lg p-4 flex items-start gap-4">
                                    <span className="text-amber-500 text-2xl mt-0.5 animate-pulse">🔥</span>
                                    <div>
                                        <p className="text-base text-amber-200/90 font-bold mb-1">Cupos limitados disponibles</p>
                                        <p className="text-sm text-amber-200/70">Al depender del trabajo minucioso de productores humanos reales, cerramos pedidos una vez llegamos al límite. <span className="text-amber-400 font-bold">Solo quedan 3 cupos para esta oferta.</span></p>
                                    </div>
                                </div>
                                
                                <div className="pt-2">
                                    <button
                                        type="submit"
                                        disabled={isLoading}
                                        className={`w-full btn-primary text-xl font-bold py-4 flex items-center justify-center gap-3 relative group overflow-hidden ${isLoading ? 'opacity-70 cursor-wait' : ''}`}
                                    >
                                        <svg className="w-6 h-6 text-black z-10 relative" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"></path></svg>
                                        <span className="z-10 relative">{isLoading ? 'Iniciando Pago Seguro...' : 'Pagar $50 USD y Empezar'}</span>
                                        {!isLoading && <div className="absolute inset-0 bg-gradient-to-r from-coffee-medium to-coffee-dark opacity-0 group-hover:opacity-100 transition-opacity duration-300"></div>}
                                    </button>
                                </div>

                                {/* Guarantee Badge */}
                                <div className="flex flex-col sm:flex-row items-center justify-center gap-4 text-center sm:text-left mt-4 pb-2">
                                    <div className="w-12 h-12 bg-gray-800 rounded-full flex items-center justify-center shrink-0 border border-gray-700 shadow-inner">
                                        <svg className="w-6 h-6 text-coffee-medium" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"></path></svg>
                                    </div>
                                    <div>
                                        <p className="text-sm font-bold text-gray-200">Garantía de Satisfacción Total</p>
                                        <p className="text-xs text-gray-500">Pagos 100% seguros y opciones de revisión musical.</p>
                                    </div>
                                </div>
                            </div>
                        </form>
                    </div>

                    {/* TRUST BADGE: PLATFORMS */}
                    <div className="mt-12 text-center overflow-hidden">
                        <p className="text-gray-400 text-sm mb-6 max-w-xl mx-auto uppercase tracking-widest font-semibold flex items-center justify-center gap-4">
                            <span className="h-px bg-gray-700 flex-1"></span>
                            Distribución Premium Asegurada
                            <span className="h-px bg-gray-700 flex-1"></span>
                        </p>
                        <p className="text-gray-300 text-sm mb-8 mx-auto max-w-2xl">
                            Tu archivo .WAV se entrega bajo las especificaciones LUFS exactas requeridas para subir a todas estas plataformas sin rechazos.
                        </p>
                        <div className="flex flex-wrap items-center justify-center gap-8 md:gap-16 opacity-50 grayscale hover:grayscale-0 transition-all duration-500 cursor-default">
                            {/* Apple SVG */}
                            <div className="h-10 w-16 flex items-center justify-center">
                                <svg className="h-[28px] w-auto text-white hover:text-white transition-colors" viewBox="0 0 24 24" fill="currentColor">
                                    <path d="M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.78.896-1.454 2.338-1.273 3.714 1.338.104 2.715-.688 3.56-1.702z"/>
                                </svg>
                            </div>
                            {/* Spotify SVG */}
                            <div className="h-10 w-16 flex items-center justify-center">
                                <svg className="h-[32px] w-auto text-white hover:text-[#1DB954] transition-colors" viewBox="0 0 24 24" fill="currentColor">
                                    <path d="M12 0C5.4 0 0 5.4 0 12s5.4 12 12 12 12-5.4 12-12S18.66 0 12 0zm5.521 17.34c-.24.359-.66.48-1.021.24-2.82-1.74-6.36-2.101-10.561-1.141-.418.122-.779-.179-.899-.539-.12-.421.18-.78.54-.9 4.56-1.021 8.52-.6 11.64 1.32.42.18.54.659.3 1.02zm1.44-3.3c-.301.42-.841.6-1.262.3-3.239-1.98-8.159-2.58-11.939-1.38-.479.12-1.02-.12-1.14-.6-.12-.48.12-1.021.6-1.141C9.6 9.9 15 10.561 18.72 12.84c.361.181.54.84.24 1.2zm.12-3.36C15.24 8.4 8.82 8.16 5.16 9.301c-.6.179-1.2-.181-1.38-.781s.18-1.2.78-1.381c4.26-1.26 11.28-1.02 15.721 1.621.539.3.719 1.02.419 1.56-.299.421-1.02.599-1.559.3z"/>
                                </svg>
                            </div>
                            {/* YouTube SVG */}
                            <div className="h-10 w-16 flex items-center justify-center">
                                <svg className="h-[24px] w-auto text-white hover:text-[#FF0000] transition-colors" viewBox="0 0 576 512" fill="currentColor">
                                    <path d="M549.655 124.083c-6.281-23.65-24.787-42.276-48.284-48.597C458.781 64 288 64 288 64S117.22 64 74.629 75.486c-23.497 6.322-42.003 24.947-48.284 48.597-11.412 42.867-11.412 132.305-11.412 132.305s0 89.438 11.412 132.305c6.281 23.65 24.787 41.5 48.284 47.821C117.22 448 288 448 288 448s170.78 0 213.371-11.486c23.497-6.321 42.003-24.171 48.284-47.821 11.412-42.867 11.412-132.305 11.412-132.305s0-89.438-11.412-132.305zm-317.51 213.508V175.185l142.739 81.205-142.739 81.201z"/>
                                </svg>
                            </div>
                            {/* TikTok SVG */}
                            <div className="h-10 w-16 flex items-center justify-center">
                                <svg className="h-[30px] w-auto text-white hover:text-[#EE1D52] transition-colors" viewBox="0 0 448 512" fill="currentColor">
                                    <path d="M448,209.91a210.06,210.06,0,0,1-122.77-39.25V349.38A162.55,162.55,0,1,1,185,188.31V278.2a74.62,74.62,0,1,0,52.23,71.18V0l88,0a121.18,121.18,0,0,0,1.86,22.17h0A122.18,122.18,0,0,0,381,102.39a121.43,121.43,0,0,0,67,20.14Z"/>
                                </svg>
                            </div>
                        </div>
                    </div>
                </div>
            </section>

            {/* TESTIMONIALS SECTION (SOCIAL PROOF) */}
            <section className="section-padding bg-gradient-to-t from-dark-bg to-dark-card border-t border-gray-800 relative overflow-hidden">
                <div className="absolute left-1/4 top-1/3 w-96 h-96 bg-coffee-medium/5 rounded-full blur-3xl z-0"></div>
                <div className="max-w-6xl mx-auto px-4 relative z-10">
                    <h2 className="text-3xl md:text-5xl font-display font-bold text-center mb-16">
                        Historias que <span className="text-gradient">suenan increíble</span>
                    </h2>
                    <div className="grid md:grid-cols-3 gap-6">
                        {/* Review 1 */}
                        <div className="card-dark border border-gray-800 bg-black/60 text-left relative flex flex-col hover:border-coffee-medium/50 transition-colors">
                            <div className="text-coffee-medium/30 text-6xl leading-none font-serif absolute -top-2 left-4">"</div>
                            <div className="flex gap-1 mb-6 text-coffee-medium justify-center mt-2">
                                ★★★★★
                            </div>
                            <p className="text-gray-300 text-sm mb-8 relative z-10 text-center px-2 flex-grow">
                                Intenté producir mis letras en un par de programas de IA pero las voces sonaban metálicas. Struky logró limpiar todo eso y el master <span className="text-white font-bold">suena como si la hubiera grabado en un estudio en Miami</span>.
                            </p>
                            <div className="flex flex-col items-center gap-2 border-t border-gray-800/80 pt-6 mt-auto">
                                <img src="https://randomuser.me/api/portraits/men/44.jpg" alt="Carlos M." className="w-12 h-12 rounded-full border-2 border-coffee-medium/30 object-cover" />
                                <div className="text-center">
                                    <p className="font-bold text-sm text-white">Carlos M.</p>
                                    <p className="text-xs text-coffee-light/80">Cantautor Urbano</p>
                                </div>
                            </div>
                        </div>
                        {/* Review 2 */}
                        <div className="card-dark border border-gray-800 bg-black/60 text-left relative flex flex-col hover:border-coffee-medium/50 transition-colors md:-translate-y-4 shadow-xl shadow-coffee-medium/5">
                            <div className="text-coffee-medium/30 text-6xl leading-none font-serif absolute -top-2 left-4">"</div>
                            <div className="flex gap-1 mb-6 text-coffee-medium justify-center mt-2">
                                ★★★★★
                            </div>
                            <p className="text-gray-300 text-sm mb-8 relative z-10 text-center px-2 flex-grow">
                                Le regalé una canción a mi esposa por nuestro aniversario usando nuestra historia. El resultado me hizo llorar. La calidad es perfecta, <span className="text-white font-bold">es imposible notar que se usó inteligencia artificial</span>.
                            </p>
                            <div className="flex flex-col items-center gap-2 border-t border-gray-800/80 pt-6 mt-auto">
                                <img src="https://randomuser.me/api/portraits/men/68.jpg" alt="Andrés P." className="w-12 h-12 rounded-full border-2 border-coffee-medium/30 object-cover" />
                                <div className="text-center">
                                    <p className="font-bold text-sm text-white">Andrés P.</p>
                                    <p className="text-xs text-coffee-light/80">Regalo de Aniversario</p>
                                </div>
                            </div>
                        </div>
                        {/* Review 3 */}
                        <div className="card-dark border border-gray-800 bg-black/60 text-left relative flex flex-col hover:border-coffee-medium/50 transition-colors">
                            <div className="text-coffee-medium/30 text-6xl leading-none font-serif absolute -top-2 left-4">"</div>
                            <div className="flex gap-1 mb-6 text-coffee-medium justify-center mt-2">
                                ★★★★★
                            </div>
                            <p className="text-gray-300 text-sm mb-8 relative z-10 text-center px-2 flex-grow">
                                Lo estupendo no es solo el sonido musical, es <span className="text-white font-bold">la tranquilidad de que la entregan con los LUFS exactos para Spotify</span> y sin problemas de Copyright. Se paga sola si de verdad quieres profesionalismo.
                            </p>
                            <div className="flex flex-col items-center gap-2 border-t border-gray-800/80 pt-6 mt-auto">
                                <img src="https://randomuser.me/api/portraits/women/44.jpg" alt="Laura V." className="w-12 h-12 rounded-full border-2 border-coffee-medium/30 object-cover" />
                                <div className="text-center">
                                    <p className="font-bold text-sm text-white">Laura V.</p>
                                    <p className="text-xs text-coffee-light/80">Letrista Independiente</p>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </section>

            {/* FAQ SECTION */}
            <section id="faq" className="section-padding bg-dark-bg">
                <div className="max-w-4xl mx-auto">
                    <h2 className="text-3xl md:text-4xl font-display font-bold text-center mb-12">
                        Preguntas <span className="text-gradient">Frecuentes</span>
                    </h2>
                    <div className="space-y-4">
                        {/* FAQ 1 */}
                        <div className="card-dark cursor-pointer transition-colors hover:border-coffee-medium/50" onClick={() => toggleFaq(0)}>
                            <div className="flex justify-between items-center">
                                <h3 className="text-lg font-bold">¿Quién es el dueño de la canción una vez terminada?</h3>
                                <span className="text-coffee-medium text-2xl leading-none">{faqOpen === 0 ? '−' : '+'}</span>
                            </div>
                            {faqOpen === 0 && (
                                <p className="mt-4 text-gray-400">
                                    Tú mantienes el 100% de la propiedad legal e intelectual de la obra. Nosotros no reclamamos ningún porcentaje de regalías (royalties), masters o derechos editoriales. Eres totalmente libre de monetizarla.
                                </p>
                            )}
                        </div>

                        {/* FAQ 2 */}
                        <div className="card-dark cursor-pointer transition-colors hover:border-coffee-medium/50" onClick={() => toggleFaq(1)}>
                            <div className="flex justify-between items-center">
                                <h3 className="text-lg font-bold">¿Puedo registrar la canción a mi nombre y subirla a Spotify/YouTube?</h3>
                                <span className="text-coffee-medium text-2xl leading-none">{faqOpen === 1 ? '−' : '+'}</span>
                            </div>
                            {faqOpen === 1 && (
                                <p className="mt-4 text-gray-400">
                                    Absolutamente. Te entregamos un archivo .WAV y .MP3 comercial listo para que lo subas a cualquier distribuidora (DistroKid, TuneCore, etc.) y lo registres en sociedades de gestión (BMI, ASCAP, SGAE, SAYCO).
                                </p>
                            )}
                        </div>

                        {/* FAQ 3 */}
                        <div className="card-dark cursor-pointer transition-colors hover:border-coffee-medium/50" onClick={() => toggleFaq(2)}>
                            <div className="flex justify-between items-center">
                                <h3 className="text-lg font-bold">¿Qué hace exactamente el productor humano?</h3>
                                <span className="text-coffee-medium text-2xl leading-none">{faqOpen === 2 ? '−' : '+'}</span>
                            </div>
                            {faqOpen === 2 && (
                                <p className="mt-4 text-gray-400">
                                    La Inteligencia Artificial puede equivocarse: generar ruido de fondo, &quot;glitches&quot; vocales, o desbalancear graves y agudos. Un productor humano real cura las tomas, limpia el audio, ecualiza y masteriza la pista para que alcance los volúmenes estándar de la industria (LUFS) exigidos por las plataformas de streaming.
                                </p>
                            )}
                        </div>

                        {/* FAQ 4 */}
                        <div className="card-dark cursor-pointer transition-colors hover:border-coffee-medium/50" onClick={() => toggleFaq(3)}>
                            <div className="flex justify-between items-center">
                                <h3 className="text-lg font-bold">¿Tengo derecho a revisiones si no me gusta el resultado?</h3>
                                <span className="text-coffee-medium text-2xl leading-none">{faqOpen === 3 ? '−' : '+'}</span>
                            </div>
                            {faqOpen === 3 && (
                                <p className="mt-4 text-gray-400">
                                    El paquete incluye 1 revisión en caso de que necesitemos ajustar el mix, corregir la ecualización, o si crees que no encajó en el mood y género solicitados. Nos aseguramos de dar lo mejor en tu primera versión basándonos en tus notas.
                                </p>
                            )}
                        </div>
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
                                    <Link href="/privacy" className="text-gray-400 hover:text-coffee-medium transition-colors">
                                        Política de Privacidad
                                    </Link>
                                </li>
                                <li>
                                    <Link href="/terms" className="text-gray-400 hover:text-coffee-medium transition-colors">
                                        Términos de Servicio
                                    </Link>
                                </li>
                                <li>
                                    <Link href="/refund" className="text-gray-400 hover:text-coffee-medium transition-colors">
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
                                    <a href="mailto:strukyapp@gmail.com" className="text-gray-400 hover:text-coffee-medium transition-colors">
                                        strukyapp@gmail.com
                                    </a>
                                </li>
                                <li>
                                    <a
                                        href="https://wa.me/573009012217"
                                        target="_blank"
                                        rel="noopener noreferrer"
                                        className="text-gray-400 hover:text-coffee-medium transition-colors flex items-center gap-2"
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

            {/* FLOATING WHATSAPP BUTTON */}
            <a
                href="https://wa.me/573009012217?text=Hola,%20tengo%20dudas%20sobre%20los%20derechos%20de%20autor%20y%20el%20servicio%20de%20producci%C3%B3n%20musical."
                target="_blank"
                rel="noopener noreferrer"
                className="fixed bottom-6 right-6 z-50 group flex items-center gap-3 animate-in slide-in-from-bottom-5 fade-in duration-500"
            >
                {/* Tooltip message */}
                <div className="bg-dark-card border border-coffee-medium/40 px-4 py-2 rounded-lg shadow-xl opacity-0 group-hover:opacity-100 transition-opacity duration-300 pointer-events-none transform translate-y-1 group-hover:translate-y-0 text-gray-300 text-sm hidden md:block">
                    ¿Dudas sobre tus derechos de autor? <br/> <strong className="text-white">Habla con el Productor</strong>
                </div>

                {/* WhatsApp Icon */}
                <div className="bg-[#25D366] text-white p-4 rounded-full shadow-lg hover:scale-110 transition-transform duration-300 hover:shadow-[#25D366]/40 hover:shadow-2xl">
                    <svg className="w-8 h-8" fill="currentColor" viewBox="0 0 24 24">
                        <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413Z" />
                    </svg>
                </div>
            </a>
        </div>
    );
}
