'use client';

import Image from 'next/image';
import { useState, useRef, useEffect } from 'react';

interface AudioPlayerProps {
    src: string;
    title: string;
    description: string;
    cover: string;
}

export default function ProfessionalAudioPlayer({ src, title, description, cover }: AudioPlayerProps) {
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
        <div className="card-dark group p-3 md:p-7 border border-white/5 hover:border-coffee-medium/30 transition-all duration-500 overflow-hidden relative flex flex-col sm:flex-row h-full">
            {/* Shimmer Effect */}
            <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/5 to-transparent -translate-x-full group-hover:animate-shimmer pointer-events-none z-20"></div>

            {/* COVER IMAGE */}
            <div className="relative w-full sm:w-32 md:w-36 aspect-square shrink-0 overflow-hidden rounded-xl border border-white/10 shadow-2xl bg-black/20 group-hover:scale-[1.02] transition-transform duration-500">
                <Image 
                    src={cover} 
                    alt={title}
                    fill
                    className="object-cover"
                    sizes="(max-width: 768px) 50vw, 150px"
                    priority
                />
            </div>

            {/* INFO & CONTROLS */}
            <div className="flex-1 min-w-0 flex flex-col mt-3 sm:mt-0 sm:ml-7 justify-center">
                <div className="mb-4">
                    <h3 className="text-[11px] md:text-xl font-bold leading-tight truncate group-hover:text-coffee-light transition-colors">{title}</h3>
                    <p className="text-[9px] md:text-sm text-gray-500 mt-1 truncate">{description}</p>
                </div>
                
                <div className="flex items-center gap-2 md:gap-4">
                    {/* Play Button - Always below/next to bar, smaller on mobile */}
                    <button 
                        onClick={togglePlay}
                        className="w-7 h-7 md:w-12 md:h-12 rounded-full bg-coffee-medium flex items-center justify-center text-white shrink-0 hover:scale-105 active:scale-95 transition-all shadow-lg"
                    >
                        {isPlaying ? (
                            <svg className="w-4 h-4 md:w-6 md:h-6" fill="currentColor" viewBox="0 0 24 24"><path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/></svg>
                        ) : (
                            <svg className="w-4 h-4 md:w-6 md:h-6 ml-0.5" fill="currentColor" viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>
                        )}
                    </button>

                    <div className="flex-1 space-y-1 md:space-y-2 min-w-0">
                        <div className="flex justify-between text-[8px] md:text-xs font-bold tracking-tight text-coffee-medium uppercase">
                            <span className="opacity-80">{currentTime}</span>
                            <span className="opacity-40">{duration}</span>
                        </div>
                        <div 
                            className="relative w-full h-1 md:h-1.5 bg-white/5 rounded-full cursor-pointer group/bar"
                            onClick={(e) => {
                                if (audioRef.current && audioRef.current.duration) {
                                    const rect = e.currentTarget.getBoundingClientRect();
                                    const pos = (e.clientX - rect.left) / rect.width;
                                    audioRef.current.currentTime = pos * audioRef.current.duration;
                                }
                            }}
                        >
                            <div 
                                className="absolute top-0 left-0 h-full bg-gradient-to-r from-coffee-medium to-coffee-light rounded-full transition-all duration-100 ease-linear shadow-[0_0_10px_rgba(202,160,82,0.3)]"
                                style={{ width: `${progress}%` }}
                            />
                        </div>
                    </div>
                </div>
            </div>
            
            <audio 
                ref={audioRef}
                src={src}
                preload="metadata"
                onTimeUpdate={handleTimeUpdate}
                onLoadedMetadata={handleLoadedMetadata}
                onDurationChange={handleLoadedMetadata}
                onPause={() => setIsPlaying(false)}
                onPlay={() => setIsPlaying(true)}
            />

            <style jsx global>{`
                @keyframes shimmer {
                    100% {
                        transform: translateX(100%);
                    }
                }
                .animate-shimmer {
                    animation: shimmer 1.5s infinite;
                }
            `}</style>
        </div>
    );
}
