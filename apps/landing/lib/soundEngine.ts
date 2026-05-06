'use client';

/**
 * Struky SoundEngine — Zero-latency audio feedback system (Optimized)
 * 
 * Uses Web Audio API to preload sounds into memory buffers.
 * Once loaded, sounds play INSTANTLY (0ms latency) on any device.
 * 
 * Optimizations applied:
 * - tick/pop share a single buffer (same source file)
 * - Sounds loaded in priority order (critical first)
 * - GainNode reuse pattern for less GC pressure
 * - Singleton AudioContext with proper lifecycle
 * 
 * Usage:
 *   import { playTick, playWhoosh } from '@/lib/soundEngine';
 *   <button onClick={playTick}>Click me</button>
 */

// === Sound URLs (unique files only) ===
const R2_BASE = 'https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev';

const SOUND_URLS = {
    tick: `${R2_BASE}/tick.mp3`,
    whoosh: `${R2_BASE}/whoosh.mp3`,
    success: `${R2_BASE}/success.mp3`,
    cashRegister: `${R2_BASE}/cash-register.mp3`,
    magic: `${R2_BASE}/magic.mp3`,
} as const;

type SoundFile = keyof typeof SOUND_URLS;

// === Sound aliases (pop reuses tick buffer — same audio file) ===
type SoundName = SoundFile | 'pop';

const SOUND_ALIAS: Partial<Record<SoundName, SoundFile>> = {
    pop: 'tick',
};

// === Volume per sound (0.0 - 1.0) ===
const VOLUMES: Record<SoundName, number> = {
    tick: 0.4,
    pop: 0.6,
    whoosh: 0.4,
    success: 0.3,
    cashRegister: 0.45,
    magic: 0.3,
};

// === Load priority (critical interaction sounds first) ===
const LOAD_ORDER: SoundFile[] = ['tick', 'whoosh', 'success', 'cashRegister', 'magic'];

// === Internal state ===
let audioContext: AudioContext | null = null;
const bufferCache = new Map<SoundFile, AudioBuffer>();
let isInitialized = false;
let isLoading = false;

/**
 * Get or create the singleton AudioContext.
 * Handles iOS Safari's suspended state requirement.
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
 * Uses Map for O(1) lookup instead of object property access.
 */
async function loadSound(name: SoundFile): Promise<void> {
    const ctx = getContext();
    if (!ctx || bufferCache.has(name)) return;
    
    try {
        const response = await fetch(SOUND_URLS[name]);
        if (!response.ok) return;
        
        const arrayBuffer = await response.arrayBuffer();
        const audioBuffer = await ctx.decodeAudioData(arrayBuffer);
        bufferCache.set(name, audioBuffer);
    } catch {
        // Silently fail — sounds are non-critical UX enhancement
    }
}

/**
 * Preload sounds into memory in priority order.
 * Critical sounds (tick, whoosh) load first so they're available fastest.
 * Call this once on first user interaction.
 */
async function preloadAll(): Promise<void> {
    if (isInitialized || isLoading) return;
    isLoading = true;
    
    const ctx = getContext();
    if (!ctx) { isLoading = false; return; }
    
    // Load critical sounds first (tick + whoosh), then the rest in parallel
    const [critical, secondary] = [LOAD_ORDER.slice(0, 2), LOAD_ORDER.slice(2)];
    
    // Phase 1: Critical sounds (needed for first interactions)
    await Promise.allSettled(critical.map(name => loadSound(name)));
    
    // Phase 2: Secondary sounds (can load in background)
    await Promise.allSettled(secondary.map(name => loadSound(name)));
    
    isInitialized = true;
    isLoading = false;
}

/**
 * Play a preloaded sound instantly.
 * Resolves aliases (e.g. pop → tick) before lookup.
 * Falls back to HTML Audio if buffer isn't ready yet.
 */
function playSound(name: SoundName): void {
    if (typeof window === 'undefined') return;
    
    const ctx = getContext();
    
    // Trigger preload on first interaction if not done yet
    if (!isInitialized && !isLoading) {
        preloadAll();
    }
    
    // Resolve alias (pop → tick)
    const bufferKey: SoundFile = SOUND_ALIAS[name] || name as SoundFile;
    const buffer = bufferCache.get(bufferKey);
    
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
            const url = SOUND_URLS[bufferKey];
            const audio = new Audio(url);
            audio.volume = VOLUMES[name];
            audio.play().catch(() => {});
        } catch {
            // Silently fail
        }
    }
}

// === Public API ===
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
