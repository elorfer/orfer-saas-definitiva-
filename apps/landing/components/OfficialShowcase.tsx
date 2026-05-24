'use client';

import { motion } from 'framer-motion';
import ProfessionalAudioPlayer from './ProfessionalAudioPlayer';

interface OfficialShowcaseProps {
    lang: 'es' | 'en';
}

export default function OfficialShowcase({ lang }: OfficialShowcaseProps) {
    return (
        <section className="section-padding bg-dark-bg relative overflow-hidden">
            {/* Background Accent - Simplified for performance */}
            <div className="absolute inset-0 bg-coffee-medium/5 pointer-events-none" />

            <div className="max-w-5xl mx-auto relative z-10 px-4">
                <div className="text-center mb-16">
                    <h2 className="text-4xl md:text-5xl font-black mb-4 tracking-tighter">
                        {lang === 'es' ? 'Bienvenidos a ' : 'Welcome to '}<span className="text-gradient">Struky Studios</span>
                    </h2>
                    <p className="text-gray-400 text-lg md:text-xl max-w-2xl mx-auto">
                        {lang === 'es' 
                            ? 'Descubre cómo transformamos tus ideas en hits de nivel mundial. Mira el video y escucha nuestra canción oficial.' 
                            : 'Discover how we transform your ideas into world-class hits. Watch the video and listen to our official song.'}
                    </p>
                </div>

                {/* Video Container */}
                <motion.div 
                    initial={{ opacity: 0, y: 20 }}
                    whileInView={{ opacity: 1, y: 0 }}
                    viewport={{ once: true }}
                    className="relative w-full aspect-video rounded-2xl md:rounded-3xl overflow-hidden border border-white/10 shadow-2xl shadow-black/80 mb-12 bg-black"
                >
                    <iframe 
                        src="https://player.vimeo.com/video/1186457597?badge=0&amp;autopause=0&amp;player_id=0&amp;app_id=58479&amp;title=0&amp;byline=0&amp;portrait=0&amp;playsinline=1" 
                        frameBorder="0" 
                        allow="autoplay; fullscreen; picture-in-picture; clipboard-write; encrypted-media; web-share" 
                        className="absolute top-0 left-0 w-full h-full"
                        title="struky welcome"
                    ></iframe>
                </motion.div>

                {/* Mid-section Title */}
                <motion.div
                    initial={{ opacity: 0, y: 20 }}
                    whileInView={{ opacity: 1, y: 0 }}
                    viewport={{ once: true }}
                    transition={{ delay: 0.1 }}
                    className="text-center mb-10 mt-4"
                >
                    <h3 className="text-3xl md:text-4xl font-black text-white tracking-tighter uppercase">
                        {lang === 'es' ? 'No lo imagines, ' : 'Don\'t imagine it, '}<span className="text-coffee-medium">{lang === 'es' ? 'Escúchalo' : 'Listen to it'}</span>
                    </h3>
                </motion.div>

                {/* Official Song Player */}
                <motion.div
                    initial={{ opacity: 0, y: 20 }}
                    whileInView={{ opacity: 1, y: 0 }}
                    viewport={{ once: true }}
                    transition={{ delay: 0.2 }}
                    className="max-w-[300px] mx-auto"
                >
                    <ProfessionalAudioPlayer 
                        src="https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/Canciones%20en%20Silencio.mp3"
                        title="Canción Oficial de Struky"
                        description="Tu música merece ser escuchada 🔥"
                        cover="https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/cancion%20oficial.webp"
                        priority={true}
                    />
                </motion.div>
            </div>
        </section>
    );
}
