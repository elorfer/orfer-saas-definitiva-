'use client';

import { useState } from 'react';
import { updateOrderStatus } from './actions';

interface StatusSelectorProps {
    sessionId: string;
    currentStatus: string;
}

const statuses = [
    { id: 'Pendiente', label: 'Pendiente', color: 'bg-coffee-medium/20 text-coffee-light border-coffee-medium/30' },
    { id: 'Producción', label: 'En Producción', color: 'bg-blue-500/20 text-blue-400 border-blue-500/30' },
    { id: 'Entregado', label: 'Entregado', color: 'bg-green-500/20 text-green-400 border-green-500/30' }
];

export default function StatusSelector({ sessionId, currentStatus }: StatusSelectorProps) {
    const [status, setStatus] = useState(currentStatus || 'Pendiente');
    const [isLoading, setIsLoading] = useState(false);
    const [isOpen, setIsOpen] = useState(false);

    const activeStatus = statuses.find(s => s.id === status) || statuses[0];

    const handleUpdate = async (newStatus: string) => {
        if (newStatus === status) return;
        
        setIsLoading(true);
        setIsOpen(false);
        try {
            const result = await updateOrderStatus(sessionId, newStatus);
            if (result.success) {
                setStatus(newStatus);
            } else {
                alert('Error al actualizar: ' + result.error);
            }
        } catch (err) {
            console.error(err);
        } finally {
            setIsLoading(false);
        }
    };

    return (
        <div className="relative">
            <button 
                onClick={() => setIsOpen(!isOpen)}
                disabled={isLoading}
                className={`flex items-center gap-2 px-3 py-1.5 rounded-lg border text-[10px] font-black uppercase tracking-widest transition-all ${activeStatus.color} ${isLoading ? 'opacity-50' : 'hover:scale-105 active:scale-95'}`}
            >
                {isLoading ? (
                    <div className="w-3 h-3 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                ) : (
                    <div className={`w-2 h-2 rounded-full ${status === 'Entregado' ? 'bg-green-400' : status === 'Producción' ? 'bg-blue-400' : 'bg-coffee-light'} shadow-[0_0_5px_currentColor]`}></div>
                )}
                {activeStatus.label}
            </button>

            {isOpen && (
                <div className="absolute top-full left-0 mt-2 w-40 bg-[#1a1a1a] border border-white/10 rounded-xl shadow-2xl z-50 overflow-hidden py-1">
                    {statuses.map((s) => (
                        <button
                            key={s.id}
                            onClick={() => handleUpdate(s.id)}
                            className={`w-full text-left px-4 py-2.5 text-[10px] font-bold uppercase tracking-widest hover:bg-white/5 transition-colors ${status === s.id ? 'text-coffee-light' : 'text-gray-400'}`}
                        >
                            {s.label}
                        </button>
                    ))}
                </div>
            )}
            
            {/* Click outside to close */}
            {isOpen && (
                <div 
                    className="fixed inset-0 z-40" 
                    onClick={() => setIsOpen(false)}
                ></div>
            )}
        </div>
    );
}
