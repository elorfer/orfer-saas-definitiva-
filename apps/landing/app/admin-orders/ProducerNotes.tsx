'use client';

import { useState } from 'react';
import { updateOrderNotes } from './actions';
import { Save, Loader2 } from 'lucide-react';

interface ProducerNotesProps {
    sessionId: string;
    initialNotes: string;
}

export default function ProducerNotes({ sessionId, initialNotes }: ProducerNotesProps) {
    const [notes, setNotes] = useState(initialNotes || '');
    const [isSaving, setIsSaving] = useState(false);
    const [hasChanged, setHasChanged] = useState(false);

    const handleSave = async () => {
        setIsSaving(true);
        try {
            const result = await updateOrderNotes(sessionId, notes);
            if (result.success) {
                setHasChanged(false);
            } else {
                alert(result.error);
            }
        } catch (err) {
            console.error(err);
        } finally {
            setIsSaving(false);
        }
    };

    return (
        <div className="mt-4 pt-4 border-t border-white/5">
            <div className="flex justify-between items-center mb-2">
                <span className="text-[10px] text-gray-500 font-bold uppercase tracking-widest">Notas del Productor (Privadas)</span>
                {hasChanged && !isSaving && (
                    <button 
                        onClick={handleSave}
                        className="text-[10px] text-coffee-light hover:text-white flex items-center gap-1 font-bold uppercase transition-colors"
                    >
                        <Save className="w-3 h-3" /> Guardar
                    </button>
                )}
                {isSaving && (
                    <span className="text-[10px] text-gray-600 flex items-center gap-1 font-bold uppercase">
                        <Loader2 className="w-3 h-3 animate-spin" /> Guardando...
                    </span>
                )}
            </div>
            <textarea 
                value={notes}
                onChange={(e) => {
                    setNotes(e.target.value);
                    setHasChanged(true);
                }}
                placeholder="Añade notas privadas sobre la producción..."
                className="w-full bg-black/20 border border-white/5 rounded-xl px-4 py-3 text-xs text-gray-300 focus:border-coffee-light/50 outline-none transition-all resize-none min-h-[80px]"
            />
        </div>
    );
}
