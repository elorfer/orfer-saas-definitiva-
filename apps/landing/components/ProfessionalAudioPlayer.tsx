'use client';

import Image from 'next/image';
import { useState, useRef, useEffect } from 'react';

interface AudioPlayerProps {
    src: string;
    title: string;
    description: string;
    cover: string;
    priority?: boolean;
}

export default function ProfessionalAudioPlayer({ src, title, description, cover, priority }: AudioPlayerProps) {
    const [isPlaying, setIsPlaying] = useState(false);
    const [progress, setProgress] = useState(0);
    const [currentTime, setCurrentTime] = useState('0:00');
    const [duration, setDuration] = useState('0:00');
    const audioRef = useRef<HTMLAudioElement | null>(null);

    // Efecto para capturar duración si ya estaba cargada (caché)
    useEffect(() => {
        const audio = audioRef.current;
        if (audio && audio.duration) {
            setDuration(formatTime(audio.duration));
        }
    }, [src]);

    const togglePlay = () => {
        if (audioRef.current) {
            if (isPlaying) {
                audioRef.current.pause();
            } else {
                document.querySelectorAll('audio').forEach(el => el.pause());
                audioRef.current.play();
            }
            setIsPlaying(!isPlaying);
        }
    };

    const formatTime = (time: number) => {
        const mins = Math.floor(time / 60);
        const secs = Math.floor(time % 60);
        return `${mins}:${secs.toString().padStart(2, '0')}`;
    };

    const handleTimeUpdate = () => {
        if (audioRef.current) {
            const current = audioRef.current.currentTime;
            const total = audioRef.current.duration;
            setProgress((current / total) * 100);
            setCurrentTime(formatTime(current));
        }
    };

    const handleLoadedMetadata = () => {
        if (audioRef.current) {
            setDuration(formatTime(audioRef.current.duration));
        }
    };

    const handleSeek = (e: React.ChangeEvent<HTMLInputElement>) => {
        if (audioRef.current) {
            const seekTime = (parseFloat(e.target.value) / 100) * audioRef.current.duration;
            audioRef.current.currentTime = seekTime;
            setProgress(parseFloat(e.target.value));
        }
    };

    return (
        <div className={`card-dark group p-3 md:p-7 border transition-all duration-300 overflow-hidden relative flex flex-row items-center h-full ${isPlaying ? 'border-coffee-medium/50 shadow-[0_0_30px_rgba(202,160,82,0.15)] bg-white/5' : 'border-white/5 hover:border-white/20'}`}>
            {/* Shimmer Effect */}
            <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/5 to-transparent -translate-x-full group-hover:animate-shimmer pointer-events-none z-20"></div>

            {/* COVER IMAGE */}
            <div className="relative w-20 sm:w-32 md:w-40 aspect-square shrink-0 overflow-hidden rounded-xl md:rounded-2xl border border-white/10 shadow-2xl bg-black/40 group-hover:scale-[1.03] transition-transform duration-300">
                <Image 
                    src={cover} 
                    alt={title}
                    fill
                    priority={priority}
                    className="object-cover transition-opacity duration-300 opacity-100"
                    sizes="(max-width: 768px) 40vw, 160px"
                />
                
                {/* Overlay removed for better aesthetic */}
            </div>

            {/* INFO & CONTROLS */}
            <div className="flex-1 min-w-0 flex flex-col ml-4 sm:ml-8 justify-center">
                <div className="mb-2 md:mb-5">
                    <div className="flex items-center gap-2 mb-1">
                        <h3 className={`text-sm sm:text-base md:text-2xl font-black leading-tight truncate transition-colors duration-300 ${isPlaying ? 'text-coffee-light' : 'text-white'}`}>
                            {title}
                        </h3>
                        {isPlaying && (
                            <div className="flex items-end gap-0.5 h-3 md:h-4 ml-2 mb-1">
                                {[1, 2, 3, 2].map((h, i) => (
                                    <div
                                        key={i}
                                        className="visualizer-bar w-0.5 md:w-1 bg-coffee-medium rounded-full"
                                        style={{ height: `${h * 25}%` }}
                                    />
                                ))}
                            </div>
                        )}
                    </div>
                    <p className="text-xs md:text-base text-gray-400 font-medium truncate tracking-wide">
                        {description}
                    </p>
                </div>
                
                <div className="flex items-center gap-3 md:gap-5">
                    {/* Play Button */}
                    <button 
                        onClick={togglePlay}
                        className={`w-10 h-10 md:w-14 md:h-14 rounded-full flex items-center justify-center shrink-0 transition-all duration-300 shadow-xl group/btn ${isPlaying ? 'bg-white text-black scale-110 shadow-coffee-medium/40 border-2 border-white' : 'bg-coffee-medium text-white hover:bg-coffee-light active:scale-95 border-2 border-transparent'}`}
                    >
                        {isPlaying ? (
                            <svg className="w-5 h-5 md:w-8 md:h-8" fill="currentColor" viewBox="0 0 24 24"><path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/></svg>
                        ) : (
                            <svg className="w-5 h-5 md:w-8 md:h-8 ml-0.5 group-hover/btn:scale-110 transition-transform" fill="currentColor" viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>
                        )}
                    </button>

                    <div className="flex-1 space-y-3 md:space-y-4 min-w-0">
                        <div className="flex justify-between text-[10px] md:text-[11px] font-bold tracking-[0.15em] text-coffee-medium uppercase">
                            <span className={isPlaying ? 'text-white' : 'opacity-60'}>{currentTime}</span>
                            <span className="opacity-20">{duration}</span>
                        </div>
                        <div 
                            className="relative w-full h-1 md:h-1.5 bg-white/10 rounded-full cursor-pointer group/bar overflow-hidden shadow-inner"
                            onClick={(e) => {
                                if (audioRef.current && audioRef.current.duration) {
                                    const rect = e.currentTarget.getBoundingClientRect();
                                    const pos = (e.clientX - rect.left) / rect.width;
                                    audioRef.current.currentTime = pos * audioRef.current.duration;
                                }
                            }}
                        >
                            {/* Progress bar — CSS shimmer instead of Framer Motion */}
                            <div 
                                className={`absolute top-0 left-0 h-full bg-gradient-to-r from-coffee-medium via-coffee-light to-coffee-medium rounded-full transition-[width] duration-100 ease-linear shadow-[0_0_15px_rgba(202,160,82,0.4)] ${isPlaying ? 'progress-shimmer' : ''}`}
                                style={{ width: `${progress}%` }}
                            />
                        </div>
                    </div>
                </div>
            </div>
            
            <audio 
                key={src}
                ref={audioRef}
                preload="none"
                onTimeUpdate={handleTimeUpdate}
                onLoadedMetadata={handleLoadedMetadata}
                onDurationChange={handleLoadedMetadata}
                onPause={() => setIsPlaying(false)}
                onPlay={() => setIsPlaying(true)}
                onError={(e) => {
                    console.error("Audio Load Error:", e);
                    // Resetear estado si hay error
                    setIsPlaying(false);
                }}
            >
                <source src={src} type="audio/mpeg" />
                Tu navegador no soporta el elemento de audio.
            </audio>
        </div>
    );
}

