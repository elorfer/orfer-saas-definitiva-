'use client';

/**
 * Struky SoundEngine — Zero-latency audio feedback system
 * 
 * Uses Web Audio API to preload all sounds into memory buffers.
 * Once loaded, sounds play INSTANTLY (0ms latency) on any device.
 * 
 * Usage:
 *   import { playTick, playWhoosh, playPop } from '@/lib/soundEngine';
 *   <button onClick={playTick}>Click me</button>
 */

// === Sound URLs ===
const SOUNDS = {
    tick: 'https://cdnjs.cloudflare.com/ajax/libs/ion-sound/3.0.7/sounds/button_tiny.mp3',
    pop: 'https://cdnjs.cloudflare.com/ajax/libs/ion-sound/3.0.7/sounds/button_tiny.mp3',
    whoosh: 'https://assets.mixkit.co/active_storage/sfx/2578/2578-preview.mp3',
    success: 'https://assets.mixkit.co/active_storage/sfx/2019/2019-preview.mp3',
    cashRegister: 'https://assets.mixkit.co/active_storage/sfx/2021/2021-preview.mp3',
    magic: 'https://assets.mixkit.co/active_storage/sfx/2020/2020-preview.mp3',
} as const;

type SoundName = keyof typeof SOUNDS;

// === Volume per sound (0.0 - 1.0) ===
const VOLUMES: Record<SoundName, number> = {
    tick: 0.4,
    pop: 0.6,
    whoosh: 0.4,
    success: 0.3,
    cashRegister: 0.45,
    magic: 0.3,
};

// === Internal state ===
let audioContext: AudioContext | null = null;
const bufferCache: Partial<Record<SoundName, AudioBuffer>> = {};
let isInitialized = false;
let isLoading = false;

/**
 * Initialize AudioContext (must be triggered by user interaction on mobile).
 * Safely handles repeated calls.
 */
function getContext(): AudioContext | null {
    if (typeof window === 'undefined') return null;
    
    if (!audioContext) {
        try {
            audioContext = new (window.AudioContext || (window as any).webkitAudioContext)();
        } catch {
            return null;
        }
    }
    
    // Resume suspended context (iOS Safari requirement)
    if (audioContext.state === 'suspended') {
        audioContext.resume().catch(() => {});
    }
    
    return audioContext;
}

/**
 * Fetch and decode a single sound into an AudioBuffer.
 */
async function loadSound(name: SoundName): Promise<void> {
    const ctx = getContext();
    if (!ctx) return;
    if (bufferCache[name]) return; // Already loaded
    
    try {
        const response = await fetch(SOUNDS[name]);
        const arrayBuffer = await response.arrayBuffer();
        const audioBuffer = await ctx.decodeAudioData(arrayBuffer);
        bufferCache[name] = audioBuffer;
    } catch {
        // Silently fail — sounds are non-critical UX enhancement
    }
}

/**
 * Preload ALL sounds into memory. Call this once on first user interaction.
 */
async function preloadAll(): Promise<void> {
    if (isInitialized || isLoading) return;
    isLoading = true;
    
    const ctx = getContext();
    if (!ctx) { isLoading = false; return; }
    
    // Load all sounds in parallel
    await Promise.allSettled(
        (Object.keys(SOUNDS) as SoundName[]).map(name => loadSound(name))
    );
    
    isInitialized = true;
    isLoading = false;
}

/**
 * Play a preloaded sound instantly. Falls back to HTML Audio if buffer isn't ready.
 */
function playSound(name: SoundName): void {
    if (typeof window === 'undefined') return;
    
    const ctx = getContext();
    
    // Trigger preload on first interaction if not done yet
    if (!isInitialized && !isLoading) {
        preloadAll();
    }
    
    const buffer = bufferCache[name];
    
    if (ctx && buffer) {
        // === FAST PATH: Web Audio API (instant, 0ms latency) ===
        const source = ctx.createBufferSource();
        const gainNode = ctx.createGain();
        
        source.buffer = buffer;
        gainNode.gain.value = VOLUMES[name];
        
        source.connect(gainNode);
        gainNode.connect(ctx.destination);
        source.start(0);
    } else {
        // === FALLBACK: HTML Audio (slower, but works before preload completes) ===
        try {
            const audio = new Audio(SOUNDS[name]);
            audio.volume = VOLUMES[name];
            audio.play().catch(() => {});
        } catch {
            // Silently fail
        }
    }
}

// === Public API (drop-in replacements) ===
export const playTick = () => playSound('tick');
export const playPop = () => playSound('pop');
export const playWhoosh = () => playSound('whoosh');
export const playSuccess = () => playSound('success');
export const playCashRegister = () => playSound('cashRegister');
export const playMagic = () => playSound('magic');

/**
 * Call this on first user interaction (e.g. first click/touch anywhere).
 * This ensures AudioContext is unlocked on iOS and sounds are preloaded.
 */
export const initSoundEngine = () => {
    getContext();
    preloadAll();
};
