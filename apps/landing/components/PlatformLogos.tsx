'use client';

interface PlatformLogosProps {
    lang: 'es' | 'en';
}

const platforms = [
    {
        name: 'Spotify',
        svg: (
            <svg viewBox="0 0 24 24" fill="currentColor" className="w-6 h-6 md:w-7 md:h-7">
                <path d="M12 0C5.4 0 0 5.4 0 12s5.4 12 12 12 12-5.4 12-12S18.66 0 12 0zm5.521 17.34c-.24.359-.66.48-1.021.24-2.82-1.74-6.36-2.101-10.561-1.141-.418.122-.779-.179-.899-.539-.12-.421.18-.78.54-.9 4.56-1.021 8.52-.6 11.64 1.32.42.18.479.659.301 1.02zm1.44-3.3c-.301.42-.841.6-1.262.3-3.239-1.98-8.159-2.58-11.939-1.38-.479.12-1.02-.12-1.14-.6-.12-.48.12-1.021.6-1.141C9.6 9.9 15 10.561 18.72 12.84c.361.181.54.78.241 1.2zm.12-3.36C15.24 8.4 8.82 8.16 5.16 9.301c-.6.179-1.2-.181-1.38-.721-.18-.601.18-1.2.72-1.381 4.26-1.26 11.28-1.02 15.721 1.621.539.3.719 1.02.419 1.56-.299.421-1.02.599-1.559.3z"/>
            </svg>
        ),
    },
    {
        name: 'Apple Music',
        svg: (
            <svg viewBox="0 0 24 24" fill="currentColor" className="w-6 h-6 md:w-7 md:h-7">
                <path d="M23.994 6.124a9.23 9.23 0 00-.24-2.19c-.317-1.31-1.062-2.31-2.18-3.043A5.022 5.022 0 0019.7.286a10.793 10.793 0 00-1.828-.242C17.225.004 16.58 0 14.753 0H9.245c-1.83 0-2.474.004-3.12.044A10.793 10.793 0 004.3.286a5.03 5.03 0 00-1.875.594C1.31 1.567.562 2.575.246 3.882a9.211 9.211 0 00-.24 2.19C-.004 6.721 0 7.37 0 9.198v5.504c0 1.828-.004 2.476.044 3.122a9.23 9.23 0 00.24 2.19c.318 1.31 1.063 2.31 2.18 3.043a5.03 5.03 0 001.876.594c.653.064 1.306.088 1.959.092.646.01 1.296.012 3.122.012h5.51c1.825 0 2.474-.004 3.12-.044a10.8 10.8 0 001.828-.241 5.02 5.02 0 001.875-.595c1.118-.733 1.863-1.733 2.18-3.043a9.21 9.21 0 00.24-2.19c.01-.646.014-1.294.014-3.122V9.198c0-1.828.004-2.477-.044-3.074zm-6.93 7.978c0 .97-.012 1.913-.06 2.475-.04.503-.12.88-.255 1.175a1.587 1.587 0 01-.682.682c-.296.135-.672.216-1.175.256-.562.047-1.506.06-2.475.06H11.58c-.97 0-1.914-.012-2.476-.06-.503-.04-.88-.12-1.175-.256a1.587 1.587 0 01-.682-.682c-.136-.296-.216-.672-.256-1.175-.047-.562-.06-1.506-.06-2.475v-4.204c0-.97.012-1.914.06-2.476.04-.503.12-.879.256-1.175.15-.312.37-.532.682-.682.295-.135.672-.216 1.175-.256.562-.047 1.506-.06 2.476-.06h.836c.97 0 1.913.013 2.475.06.503.04.88.12 1.175.256.312.15.532.37.682.682.135.296.216.672.256 1.175.047.562.06 1.506.06 2.476v4.204zm-2.05-5.604a.467.467 0 00-.543-.403l-4.154.8a.467.467 0 00-.377.458v4.47a2.073 2.073 0 00-.67-.113c-.923 0-1.672.62-1.672 1.384 0 .764.75 1.384 1.672 1.384.923 0 1.673-.62 1.673-1.384V10.06l3.22-.62v3.616a2.073 2.073 0 00-.67-.113c-.923 0-1.672.62-1.672 1.384 0 .764.75 1.384 1.672 1.384.923 0 1.672-.62 1.672-1.384V8.9a.467.467 0 00-.15-.402z"/>
            </svg>
        ),
    },
    {
        name: 'YouTube Music',
        svg: (
            <svg viewBox="0 0 24 24" fill="currentColor" className="w-6 h-6 md:w-7 md:h-7">
                <path d="M12 0C5.376 0 0 5.376 0 12s5.376 12 12 12 12-5.376 12-12S18.624 0 12 0zm0 19.104c-3.924 0-7.104-3.18-7.104-7.104S8.076 4.896 12 4.896s7.104 3.18 7.104 7.104-3.18 7.104-7.104 7.104zm0-13.332c-3.432 0-6.228 2.796-6.228 6.228S8.568 18.228 12 18.228s6.228-2.796 6.228-6.228S15.432 5.772 12 5.772zM9.684 15.54V8.46L15.816 12l-6.132 3.54z"/>
            </svg>
        ),
    },
    {
        name: 'Deezer',
        svg: (
            <svg viewBox="0 0 24 24" fill="currentColor" className="w-6 h-6 md:w-7 md:h-7">
                <path d="M18.81 4.16v3.03H24V4.16h-5.19zM6.27 8.38v3.027h5.19V8.38H6.27zm12.54 0v3.027H24V8.38h-5.19zM6.27 12.594v3.027h5.19v-3.027H6.27zm6.27 0v3.027h5.19v-3.027h-5.19zm6.27 0v3.027H24v-3.027h-5.19zM0 16.81v3.029h5.19v-3.03H0zm6.27 0v3.029h5.19v-3.03H6.27zm6.27 0v3.029h5.19v-3.03h-5.19zm6.27 0v3.029H24v-3.03h-5.19z"/>
            </svg>
        ),
    },
    {
        name: 'Tidal',
        svg: (
            <svg viewBox="0 0 24 24" fill="currentColor" className="w-6 h-6 md:w-7 md:h-7">
                <path d="M12.012 3.992L8.008 7.996 4.004 3.992 0 7.996 4.004 12l4.004-4.004L12.012 12l4.004-4.004L12.012 3.992zM12.012 12l-4.004 4.004 4.004 4.004 4.004-4.004L12.012 12zM20.02 3.992l-4.004 4.004 4.004 4.004L24.024 7.996 20.02 3.992z"/>
            </svg>
        ),
    },
];

import { motion } from 'framer-motion';

export default function PlatformLogos({ lang }: PlatformLogosProps) {
    // Duplicate the platforms array to create a seamless loop
    const tickerItems = [...platforms, ...platforms, ...platforms, ...platforms];

    return (
        <section className="py-4 md:py-6 bg-dark-bg/50 border-y border-white/5 overflow-hidden">
            <div className="max-w-full mx-auto">
                <p className="text-center text-[10px] md:text-xs font-black text-gray-500 uppercase tracking-[0.3em] mb-4 px-6">
                    {lang === 'es' ? 'Distribución Premium Garantizada en' : 'Premium Distribution Guaranteed on'}
                </p>

                <div className="relative flex overflow-hidden group">
                    {/* Left and Right Fade Masks */}
                    <div className="absolute left-0 top-0 bottom-0 w-20 md:w-40 bg-gradient-to-r from-[#050505] to-transparent z-10 pointer-events-none"></div>
                    <div className="absolute right-0 top-0 bottom-0 w-20 md:w-40 bg-gradient-to-l from-[#050505] to-transparent z-10 pointer-events-none"></div>

                    {/* Scrolling Container */}
                    <motion.div
                        className="flex items-center gap-12 md:gap-20 whitespace-nowrap"
                        animate={{ x: ["0%", "-50%"] }}
                        transition={{ repeat: Infinity, ease: "linear", duration: 25 }}
                    >
                        {tickerItems.map((platform, i) => (
                            <div
                                key={`${platform.name}-${i}`}
                                className="flex items-center gap-3 text-gray-300 hover:text-white transition-colors duration-300 group/logo cursor-default"
                            >
                                <span className="opacity-80 group-hover/logo:opacity-100 transition-opacity drop-shadow-[0_0_15px_rgba(255,255,255,0)] group-hover/logo:drop-shadow-[0_0_15px_rgba(255,255,255,0.3)]">
                                    {platform.svg}
                                </span>
                                <span className="text-sm md:text-base font-black tracking-widest uppercase">
                                    {platform.name}
                                </span>
                            </div>
                        ))}
                    </motion.div>
                </div>
            </div>
        </section>
    );
}

