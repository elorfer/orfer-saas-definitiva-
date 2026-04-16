'use client';

import { useState } from 'react';
import { Check, Copy } from 'lucide-react';

interface CopyLyricsButtonProps {
    lyrics: string;
}

export default function CopyLyricsButton({ lyrics }: CopyLyricsButtonProps) {
    const [copied, setCopied] = useState(false);

    const handleCopy = async () => {
        if (!lyrics) return;
        try {
            await navigator.clipboard.writeText(lyrics);
            setCopied(true);
            setTimeout(() => setCopied(false), 2000);
        } catch (err) {
            console.error('Failed to copy!', err);
        }
    };

    return (
        <button 
            onClick={handleCopy}
            title="Copiar letra al portapapeles"
            className={`flex items-center gap-2 px-3 py-1.5 rounded-lg border text-[10px] font-bold uppercase tracking-widest transition-all ${
                copied 
                    ? 'bg-green-500/20 text-green-400 border-green-500/30' 
                    : 'bg-white/5 text-gray-400 border-white/10 hover:bg-white/10 hover:text-white'
            }`}
        >
            {copied ? (
                <>
                    <Check className="w-3 h-3" />
                    Copiado
                </>
            ) : (
                <>
                    <Copy className="w-3 h-3" />
                    Copiar Letra
                </>
            )}
        </button>
    );
}
