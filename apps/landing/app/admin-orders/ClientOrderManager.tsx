'use client';

import { useState, useMemo } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import StatusSelector from './StatusSelector';
import CopyLyricsButton from './CopyLyricsButton';
import ProducerNotes from './ProducerNotes';
import AdminAnalytics from './AdminAnalytics';
import RechargeParticles from '@/components/RechargeParticles';
import { Search, X, MessageCircle, Mail, Hash, BarChart3, ChevronUp, ChevronDown } from 'lucide-react';

interface ClientOrderManagerProps {
    initialSessions: any[];
}

const filters = [
    { id: 'all', label: 'Todos', color: 'bg-white/5' },
    { id: 'Pendiente', label: 'Pendientes', color: 'bg-coffee-medium/20 text-coffee-light' },
    { id: 'Producción', label: 'En Producción', color: 'bg-blue-500/20 text-blue-400' },
    { id: 'Entregado', label: 'Entregados', color: 'bg-green-500/20 text-green-400' }
];

export default function ClientOrderManager({ initialSessions }: ClientOrderManagerProps) {
    const router = useRouter();
    const searchParams = useSearchParams();
    const [searchQuery, setSearchQuery] = useState('');
    const [showStats, setShowStats] = useState(false);
    const currentFilter = searchParams.get('status') || 'all';

    // El filtrado ahora es instantáneo usando useMemo (Filtros + Búsqueda)
    const filteredSessions = useMemo(() => {
        let result = initialSessions;
        
        // Filtrado por estado
        if (currentFilter !== 'all') {
            result = result.filter(s => (s.metadata?.status || 'Pendiente') === currentFilter);
        }
        
        // Búsqueda por nombre o email
        if (searchQuery) {
            const query = searchQuery.toLowerCase();
            result = result.filter(s => 
                (s.metadata?.name || '').toLowerCase().includes(query) || 
                (s.metadata?.email || '').toLowerCase().includes(query)
            );
        }
        
        return result;
    }, [initialSessions, currentFilter, searchQuery]);

    const setFilter = (id: string) => {
        const params = new URLSearchParams(searchParams);
        if (id === 'all') {
            params.delete('status');
        } else {
            params.set('status', id);
        }
        // Actualizamos la URL suavemente para persistencia
        window.history.replaceState(null, '', `?${params.toString()}`);
        // Forzamos el re-render local sin pedir datos al servidor de nuevo
        router.refresh(); 
    };

    return (
        <>
            {/* ANALYTICS BUTTON */}
            <div className="flex justify-end mb-4">
                <button 
                    onClick={() => setShowStats(!showStats)}
                    className="flex items-center gap-2 px-4 py-2 bg-white/5 border border-white/10 rounded-xl text-[10px] font-black uppercase tracking-widest hover:bg-white/10 transition-all text-gray-400 hover:text-white"
                >
                    <BarChart3 className="w-3.5 h-3.5" />
                    {showStats ? 'Ocultar Estadísticas' : 'Ver Estadísticas de Negocio'}
                    {showStats ? <ChevronUp className="w-3 h-3" /> : <ChevronDown className="w-3 h-3" />}
                </button>
            </div>

            {/* ANALYTICS SECTION */}
            {showStats && (
                <div className="animate-in fade-in slide-in-from-top-4 duration-500">
                    <AdminAnalytics sessions={initialSessions} />
                </div>
            )}

            {/* BUSCADOR Y TABS INSTANTÁNEAS */}
            <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-8">
                <div className="flex flex-wrap gap-2">
                    {filters.map((filter) => (
                        <button
                            key={filter.id}
                            onClick={() => setFilter(filter.id)}
                            className={`px-4 py-2 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all border ${
                                currentFilter === filter.id 
                                    ? `${filter.color} border-white/20 scale-105 shadow-lg` 
                                    : 'bg-transparent border-white/5 text-gray-500 hover:border-white/10 hover:text-gray-300'
                            }`}
                        >
                            {filter.label}
                        </button>
                    ))}
                </div>

                <div className="relative group min-w-[280px]">
                    <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500 group-focus-within:text-coffee-light transition-colors" />
                    <input 
                        type="text"
                        placeholder="Buscar por nombre o email..."
                        value={searchQuery}
                        onChange={(e) => setSearchQuery(e.target.value)}
                        className="w-full bg-white/5 border border-white/10 rounded-2xl pl-11 pr-11 py-3 text-sm focus:border-coffee-light/50 outline-none transition-all"
                    />
                    {searchQuery && (
                        <button 
                            onClick={() => setSearchQuery('')}
                            className="absolute right-4 top-1/2 -translate-y-1/2 text-gray-500 hover:text-white"
                        >
                            <X className="w-4 h-4" />
                        </button>
                    )}
                </div>
            </div>

            {/* LISTADO FILTRADO */}
            <div className="grid gap-6">
                {filteredSessions.length === 0 && (
                    <div className="text-center py-24 bg-white/[0.02] rounded-3xl border border-dashed border-white/10">
                        <p className="text-gray-500 font-medium">No se encontraron pedidos en este estado.</p>
                    </div>
                )}
                
                {filteredSessions.map((session: any) => {
                    const meta = session.metadata || {};
                    const date = new Date(session.created * 1000).toLocaleDateString('es-ES', {
                        day: '2-digit',
                        month: 'short',
                        hour: '2-digit',
                        minute: '2-digit'
                    });

                    // Reconstruir letra
                    const lyricsParts = Object.keys(meta)
                        .filter(key => key.startsWith('lyrics___parte_'))
                        .sort((a, b) => parseInt(a.split('_').pop() || '0') - parseInt(b.split('_').pop() || '0'))
                        .map(key => meta[key]);
                    const lyrics = lyricsParts.join('');

                    return (
                        <div key={session.id} className="glass-morphism p-6 md:p-8 rounded-3xl border border-white/5 hover:border-coffee-medium/30 transition-all group relative">
                            <div className="absolute top-0 left-0 w-1.5 h-full bg-coffee-medium opacity-50"></div>
                            
                            <div className="grid md:grid-cols-12 gap-8">
                                <div className="md:col-span-3 space-y-4">
                                    <div>
                                        <span className="text-[10px] text-gray-500 font-bold uppercase tracking-widest block mb-1">Cliente</span>
                                        <h2 className="text-lg font-bold text-white leading-tight mb-2">{meta.name || 'Sin nombre'}</h2>
                                        
                                        <div className="flex flex-col gap-2">
                                            <a 
                                                href={`mailto:${meta.email}?subject=Tu canción de Struky - Estado: ${meta.status || 'En camino'}`}
                                                className="flex items-center gap-2 text-[10px] text-coffee-light hover:text-white transition-colors group"
                                            >
                                                <Mail className="w-3.5 h-3.5" />
                                                <span className="truncate max-w-[150px]">{meta.email}</span>
                                            </a>
                                            
                                            {meta.phone && (
                                                <a 
                                                    href={`https://wa.me/${meta.phone.replace(/[^0-9]/g, '')}?text=Hola %20${meta.name},%20soy%20el%20productor%20de%20Struky.%20Estamos%20trabajando%20en%20tu%20canción%20${meta.genre}.`}
                                                    target="_blank"
                                                    rel="noopener noreferrer"
                                                    className="flex items-center gap-2 text-[10px] text-green-400 hover:text-white transition-colors group"
                                                >
                                                    <MessageCircle className="w-3.5 h-3.5" />
                                                    <span>WhatsApp Directo</span>
                                                </a>
                                            )}
                                        </div>
                                    </div>
                                    <div>
                                        <span className="text-[10px] text-gray-500 font-bold uppercase tracking-widest block mb-1">Fecha de pago</span>
                                        <p className="text-sm font-medium">{date}</p>
                                    </div>
                                    <div className="pt-2 flex flex-wrap gap-2">
                                        <div className="flex flex-col gap-1 relative overflow-hidden group/amount">
                                            <RechargeParticles />
                                            <span className="bg-coffee-medium/10 text-white text-[9px] font-black uppercase px-2 py-1 rounded border border-coffee-medium/20 whitespace-nowrap relative z-10">
                                                ${(session.amount_total / 100).toFixed(2)} USD
                                            </span>
                                            <span className="text-[8px] text-gray-600 font-bold uppercase tracking-widest text-center relative z-10">{meta.plan || 'Starter'}</span>
                                        </div>
                                        <StatusSelector 
                                            sessionId={session.id} 
                                            currentStatus={meta.status || 'Pendiente'} 
                                        />
                                    </div>
                                </div>

                                <div className="md:col-span-3">
                                    <div className="grid grid-cols-2 gap-4">
                                        <div>
                                            <span className="text-[10px] text-gray-500 font-bold uppercase tracking-widest block mb-1">Género</span>
                                            <p className="text-sm font-semibold">{meta.genre}</p>
                                        </div>
                                        <div>
                                            <span className="text-[10px] text-gray-500 font-bold uppercase tracking-widest block mb-1">Voz</span>
                                            <p className="text-sm font-semibold">{meta.vocalist}</p>
                                        </div>
                                        <div>
                                            <span className="text-[10px] text-gray-500 font-bold uppercase tracking-widest block mb-1">Ánimo</span>
                                            <p className="text-sm font-semibold">{meta.mood}</p>
                                        </div>
                                    </div>
                                        <div className="mt-4">
                                            <span className="text-[10px] text-gray-500 font-bold uppercase tracking-widest block mb-1">Notas del cliente</span>
                                            <p className="text-xs text-gray-400 line-clamp-2 italic leading-relaxed">
                                                "{meta.notes || 'Sin notas adicionales'}"
                                            </p>
                                        </div>
                                        <ProducerNotes 
                                            sessionId={session.id} 
                                            initialNotes={meta.producer_notes || ''} 
                                        />
                                    </div>

                                <div className="md:col-span-6 bg-black/40 rounded-2xl p-6 border border-white/5 relative overflow-hidden">
                                    <div className="absolute top-0 right-0 p-3 flex items-center gap-2">
                                        <span className="text-[9px] text-gray-700 font-mono tracking-tighter bg-white/5 px-2 py-1 rounded">
                                            #{session.id.slice(-8)}
                                        </span>
                                        <CopyLyricsButton lyrics={lyrics} />
                                    </div>
                                    <div className="flex justify-between items-center mb-4">
                                        <span className="text-[10px] text-coffee-light font-bold uppercase tracking-widest">Letra del cliente</span>
                                    </div>
                                    <div className="max-h-32 overflow-y-auto text-xs text-gray-300 leading-relaxed font-mono custom-scrollbar">
                                        {lyrics ? lyrics : <span className="text-gray-600 italic">No proporcionó letra</span>}
                                    </div>
                                </div>
                            </div>
                        </div>
                    );
                })}
            </div>
        </>
    );
}
