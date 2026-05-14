'use client';

import { useState, useEffect } from 'react';
import Image from 'next/image';
import { X, Maximize2 } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

interface ImageZoomProps {
    src: string;
    alt: string;
    className?: string;
}

export default function ImageZoom({ src, alt, className = "" }: ImageZoomProps) {
    const [isOpen, setIsOpen] = useState(false);

    // Disable scroll when modal is open
    useEffect(() => {
        if (isOpen) {
            document.body.style.overflow = 'hidden';
        } else {
            document.body.style.overflow = 'unset';
        }
        return () => {
            document.body.style.overflow = 'unset';
        };
    }, [isOpen]);

    return (
        <>
            <div 
                className={`relative h-full w-full cursor-zoom-in group ${className}`}
                onClick={() => setIsOpen(true)}
            >
                <Image 
                    src={src} 
                    alt={alt}
                    fill
                    className="object-cover"
                    priority
                />
                <div className="absolute inset-0 bg-black/20 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
                    <div className="bg-white/10 backdrop-blur-md p-3 rounded-full border border-white/20">
                        <Maximize2 className="w-6 h-6 text-white" />
                    </div>
                </div>
            </div>

            <AnimatePresence>
                {isOpen && (
                    <motion.div 
                        initial={{ opacity: 0 }}
                        animate={{ opacity: 1 }}
                        exit={{ opacity: 0 }}
                        className="fixed inset-0 z-[100] flex items-center justify-center bg-black/95 p-4 md:p-10 cursor-zoom-out"
                        onClick={() => setIsOpen(false)}
                    >
                        <motion.button 
                            initial={{ scale: 0 }}
                            animate={{ scale: 1 }}
                            className="absolute top-6 right-6 p-3 bg-white/10 hover:bg-white/20 rounded-full text-white transition-colors z-[110]"
                            onClick={(e) => {
                                e.stopPropagation();
                                setIsOpen(false);
                            }}
                        >
                            <X className="w-6 h-6" />
                        </motion.button>

                        <motion.div 
                            initial={{ scale: 0.9, opacity: 0 }}
                            animate={{ scale: 1, opacity: 1 }}
                            exit={{ scale: 0.9, opacity: 0 }}
                            className="relative w-full h-full max-w-7xl max-h-[85vh]"
                            onClick={(e) => e.stopPropagation()}
                        >
                            <Image 
                                src={src} 
                                alt={alt}
                                fill
                                className="object-contain"
                                quality={100}
                                priority
                            />
                        </motion.div>
                        
                        <div className="absolute bottom-6 left-1/2 -translate-x-1/2 text-gray-400 text-xs font-medium uppercase tracking-widest bg-white/5 px-4 py-2 rounded-full border border-white/10">
                            {alt}
                        </div>
                    </motion.div>
                )}
            </AnimatePresence>
        </>
    );
}
