'use client';

import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import {
    Cog6ToothIcon,
    MusicalNoteIcon,
    MegaphoneIcon,
    ChartBarIcon,
    ArrowPathIcon,
    CheckCircleIcon,
    ExclamationCircleIcon
} from '@heroicons/react/24/outline';
import { apiClient } from '@/lib/api';

interface Setting {
    key: string;
    value: number;
    description: string | null;
    updatedAt: string | null;
}

interface AlgorithmSettings {
    algorithm_history_size: number;
    algorithm_phase2_count: number;
    algorithm_phase31_count: number;
    algorithm_buffer_size: number;
    algorithm_preload_threshold: number;
    algorithm_critical_songs: number;
    catalog_size: number;
    catalog_small_threshold: number;
    ad_frequency: number;
}

const DEFAULT_SETTINGS: AlgorithmSettings = {
    algorithm_history_size: 100,
    algorithm_phase2_count: 6,
    algorithm_phase31_count: 20,
    algorithm_buffer_size: 5,
    algorithm_preload_threshold: 3,
    algorithm_critical_songs: 5,
    catalog_size: 0,
    catalog_small_threshold: 150,
    ad_frequency: 3,
};

const SETTING_DESCRIPTIONS: Record<string, { label: string; description: string; min: number; max: number; color: string }> = {
    algorithm_history_size: {
        label: 'Historial de Exclusión',
        description: 'Canciones recientes que el algoritmo evitará repetir. Reduce para catálogos pequeños.',
        min: 10,
        max: 500,
        color: 'amber',
    },
    algorithm_phase2_count: {
        label: 'Canciones FASE 2.0',
        description: 'Cantidad de canciones que solicita la FASE 2.0 en background.',
        min: 3,
        max: 20,
        color: 'blue',
    },
    algorithm_phase31_count: {
        label: 'Canciones FASE 3.1',
        description: 'Cantidad de canciones que solicita la FASE 3.1 (precarga proactiva).',
        min: 5,
        max: 50,
        color: 'indigo',
    },
    algorithm_buffer_size: {
        label: 'Buffer Inicial',
        description: 'Canciones en el buffer inicial (FASE 1) antes de reproducir.',
        min: 1,
        max: 10,
        color: 'violet',
    },
    algorithm_preload_threshold: {
        label: 'Umbral de Precarga',
        description: 'Cuando quedan esta cantidad de canciones, se dispara la precarga.',
        min: 1,
        max: 10,
        color: 'purple',
    },
    algorithm_critical_songs: {
        label: 'Canciones Críticas',
        description: 'Canciones que se agregan por cada ciclo de precarga.',
        min: 1,
        max: 15,
        color: 'fuchsia',
    },
    catalog_small_threshold: {
        label: 'Umbral Catálogo Pequeño',
        description: 'Si el catálogo tiene menos canciones que esto, se aplican reglas especiales.',
        min: 50,
        max: 500,
        color: 'orange',
    },
    ad_frequency: {
        label: 'Frecuencia de Anuncios',
        description: 'Canciones entre cada anuncio.',
        min: 1,
        max: 20,
        color: 'rose',
    },
};

// 🎯 PRESETS RECOMENDADOS según tamaño del catálogo
interface Preset {
    name: string;
    description: string;
    minSongs: number;
    maxSongs: number;
    icon: string;
    color: string;
    values: Partial<AlgorithmSettings>;
}

const RECOMMENDED_PRESETS: Preset[] = [
    {
        name: 'Catálogo Inicial',
        description: '30-80 canciones',
        minSongs: 0,
        maxSongs: 80,
        icon: '🌱',
        color: 'orange',
        values: {
            algorithm_history_size: 20,
            algorithm_phase2_count: 8,
            algorithm_phase31_count: 15,
            algorithm_buffer_size: 3,
            algorithm_preload_threshold: 2,
            algorithm_critical_songs: 4,
            catalog_small_threshold: 100,
        },
    },
    {
        name: 'Catálogo Pequeño',
        description: '80-200 canciones',
        minSongs: 80,
        maxSongs: 200,
        icon: '🎵',
        color: 'yellow',
        values: {
            algorithm_history_size: 50,
            algorithm_phase2_count: 8,
            algorithm_phase31_count: 20,
            algorithm_buffer_size: 4,
            algorithm_preload_threshold: 3,
            algorithm_critical_songs: 5,
            catalog_small_threshold: 150,
        },
    },
    {
        name: 'Catálogo Mediano',
        description: '200-500 canciones',
        minSongs: 200,
        maxSongs: 500,
        icon: '🎶',
        color: 'green',
        values: {
            algorithm_history_size: 100,
            algorithm_phase2_count: 6,
            algorithm_phase31_count: 20,
            algorithm_buffer_size: 5,
            algorithm_preload_threshold: 3,
            algorithm_critical_songs: 5,
            catalog_small_threshold: 150,
        },
    },
    {
        name: 'Catálogo Grande',
        description: '500-2000 canciones',
        minSongs: 500,
        maxSongs: 2000,
        icon: '🎸',
        color: 'blue',
        values: {
            algorithm_history_size: 150,
            algorithm_phase2_count: 6,
            algorithm_phase31_count: 25,
            algorithm_buffer_size: 5,
            algorithm_preload_threshold: 4,
            algorithm_critical_songs: 6,
            catalog_small_threshold: 200,
        },
    },
    {
        name: 'Catálogo Masivo',
        description: '2000+ canciones',
        minSongs: 2000,
        maxSongs: Infinity,
        icon: '🚀',
        color: 'purple',
        values: {
            algorithm_history_size: 300,
            algorithm_phase2_count: 8,
            algorithm_phase31_count: 30,
            algorithm_buffer_size: 5,
            algorithm_preload_threshold: 5,
            algorithm_critical_songs: 8,
            catalog_small_threshold: 300,
        },
    },
];

export default function SettingsPage() {
    const [settings, setSettings] = useState<AlgorithmSettings>(DEFAULT_SETTINGS);
    const [loading, setLoading] = useState(true);
    const [saving, setSaving] = useState<string | null>(null);
    const [savedKey, setSavedKey] = useState<string | null>(null);
    const [error, setError] = useState<string | null>(null);
    const [catalogSize, setCatalogSize] = useState<number>(0);

    useEffect(() => {
        fetchSettings();
        fetchCatalogSize();
    }, []);

    const fetchSettings = async () => {
        try {
            setLoading(true);
            const response = await apiClient.getSettings();
            const data: Setting[] = response.data;
            const settingsMap: Partial<AlgorithmSettings> = {};

            data.forEach((setting) => {
                if (setting.key in DEFAULT_SETTINGS) {
                    settingsMap[setting.key as keyof AlgorithmSettings] = setting.value;
                }
            });

            setSettings({ ...DEFAULT_SETTINGS, ...settingsMap });
        } catch (err) {
            console.error('Error fetching settings:', err);
            setError('Error al cargar configuraciones');
        } finally {
            setLoading(false);
        }
    };

    const fetchCatalogSize = async () => {
        try {
            const response = await apiClient.getSongs(1, 1);
            setCatalogSize(response.data?.total || 0);
        } catch (err) {
            console.error('Error fetching catalog size:', err);
        }
    };

    const updateSetting = async (key: string, value: number) => {
        try {
            setSaving(key);
            setError(null);

            const meta = SETTING_DESCRIPTIONS[key];
            if (meta) {
                value = Math.max(meta.min, Math.min(meta.max, value));
            }

            await apiClient.updateSetting(key, value, meta?.description || `Configuración: ${key}`);
            setSettings(prev => ({ ...prev, [key]: value }));
            setSavedKey(key);
            setTimeout(() => setSavedKey(null), 2000);
        } catch (err) {
            console.error('Error updating setting:', err);
            setError(`Error al guardar ${key}`);
        } finally {
            setSaving(null);
        }
    };

    // 🎯 Estado para aplicar preset
    const [applyingPreset, setApplyingPreset] = useState<string | null>(null);

    // 🎯 Obtener el preset recomendado según el tamaño actual del catálogo
    const getRecommendedPreset = () => {
        return RECOMMENDED_PRESETS.find(
            p => catalogSize >= p.minSongs && catalogSize < p.maxSongs
        ) || RECOMMENDED_PRESETS[0];
    };

    // 🎯 Aplicar un preset completo
    const applyPreset = async (preset: Preset) => {
        try {
            setApplyingPreset(preset.name);
            setError(null);

            // Aplicar todas las configuraciones del preset
            for (const [key, value] of Object.entries(preset.values)) {
                if (value !== undefined) {
                    const meta = SETTING_DESCRIPTIONS[key];
                    await apiClient.updateSetting(
                        key,
                        value as number,
                        meta?.description || `Configuración: ${key}`
                    );
                }
            }

            // Actualizar estado local
            setSettings(prev => ({ ...prev, ...preset.values }));
            setSavedKey('preset');
            setTimeout(() => setSavedKey(null), 2000);
        } catch (err) {
            console.error('Error applying preset:', err);
            setError(`Error al aplicar preset ${preset.name}`);
        } finally {
            setApplyingPreset(null);
        }
    };

    // 🎯 Detectar si un preset está actualmente activo (comparando valores)
    const isPresetActive = (preset: Preset): boolean => {
        for (const [key, value] of Object.entries(preset.values)) {
            if (settings[key as keyof AlgorithmSettings] !== value) {
                return false;
            }
        }
        return true;
    };

    // 🎯 Obtener el preset actualmente activo (si alguno coincide)
    const getActivePreset = (): Preset | null => {
        return RECOMMENDED_PRESETS.find(p => isPresetActive(p)) || null;
    };

    const renderSettingCard = (key: keyof AlgorithmSettings) => {
        const meta = SETTING_DESCRIPTIONS[key];
        if (!meta) return null;

        const value = settings[key];
        const isSaving = saving === key;
        const isSaved = savedKey === key;

        return (
            <motion.div
                key={key}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                className="bg-white rounded-xl p-6 border border-gray-200 shadow-sm hover:shadow-md transition-shadow"
            >
                <div className="flex items-start justify-between mb-4">
                    <div className="flex items-center gap-3">
                        <div className={`p-2 bg-${meta.color}-100 rounded-lg`}>
                            <MusicalNoteIcon className={`h-5 w-5 text-${meta.color}-600`} />
                        </div>
                        <div>
                            <h3 className="font-semibold text-gray-900">{meta.label}</h3>
                            <p className="text-sm text-gray-500 mt-1">{meta.description}</p>
                        </div>
                    </div>

                    {isSaving && (
                        <ArrowPathIcon className="h-5 w-5 text-amber-500 animate-spin" />
                    )}
                    {isSaved && (
                        <CheckCircleIcon className="h-5 w-5 text-green-500" />
                    )}
                </div>

                <div className="flex items-center gap-4">
                    <input
                        type="range"
                        min={meta.min}
                        max={meta.max}
                        value={value}
                        onChange={(e) => setSettings(prev => ({ ...prev, [key]: parseInt(e.target.value) }))}
                        onMouseUp={(e) => updateSetting(key, parseInt((e.target as HTMLInputElement).value))}
                        onTouchEnd={(e) => updateSetting(key, parseInt((e.target as HTMLInputElement).value))}
                        className="flex-1 h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer accent-amber-600"
                    />
                    <input
                        type="number"
                        min={meta.min}
                        max={meta.max}
                        value={value}
                        onChange={(e) => setSettings(prev => ({ ...prev, [key]: parseInt(e.target.value) || meta.min }))}
                        onBlur={(e) => updateSetting(key, parseInt(e.target.value) || meta.min)}
                        className="w-20 bg-gray-50 border border-gray-300 rounded-lg px-3 py-2 text-gray-900 text-center focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent"
                    />
                </div>

                <div className="flex justify-between mt-2 text-xs text-gray-400">
                    <span>Mín: {meta.min}</span>
                    <span>Máx: {meta.max}</span>
                </div>
            </motion.div>
        );
    };

    if (loading) {
        return (
            <div className="flex items-center justify-center h-96">
                <div className="text-center">
                    <ArrowPathIcon className="h-8 w-8 text-amber-500 animate-spin mx-auto" />
                    <p className="mt-2 text-gray-500">Cargando configuración...</p>
                </div>
            </div>
        );
    }

    return (
        <div className="p-6 space-y-8 max-w-7xl mx-auto">
            {/* Header */}
            <div className="flex items-center gap-4">
                <div className="p-3 bg-gradient-to-br from-amber-500 to-orange-600 rounded-xl shadow-lg">
                    <Cog6ToothIcon className="h-8 w-8 text-white" />
                </div>
                <div>
                    <h1 className="text-2xl font-bold text-gray-900">Configuración del Algoritmo</h1>
                    <p className="text-gray-500">Ajusta los parámetros de recomendación sin actualizar la app</p>
                </div>
            </div>

            {/* Catalog Status */}
            <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                className={`p-6 rounded-xl border-2 ${catalogSize < settings.catalog_small_threshold
                    ? 'bg-yellow-50 border-yellow-200'
                    : 'bg-green-50 border-green-200'
                    }`}
            >
                <div className="flex items-center gap-4">
                    <div className={`p-3 rounded-lg ${catalogSize < settings.catalog_small_threshold
                        ? 'bg-yellow-100 text-yellow-600'
                        : 'bg-green-100 text-green-600'
                        }`}>
                        <ChartBarIcon className="h-6 w-6" />
                    </div>
                    <div>
                        <h3 className="font-semibold text-gray-900">
                            Estado del Catálogo: <span className="text-xl">{catalogSize}</span> canciones
                        </h3>
                        <p className={`text-sm ${catalogSize < settings.catalog_small_threshold
                            ? 'text-yellow-700'
                            : 'text-green-700'
                            }`}>
                            {catalogSize < settings.catalog_small_threshold
                                ? `⚠️ Catálogo pequeño (menos de ${settings.catalog_small_threshold}). Se aplicarán reglas especiales.`
                                : '✅ Catálogo saludable. El algoritmo funcionará con máxima variedad.'}
                        </p>
                    </div>
                </div>
            </motion.div>

            {/* 🎯 Recommended Presets Section */}
            <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                className="bg-white rounded-xl p-6 border border-gray-200 shadow-sm"
            >
                <div className="flex items-center justify-between mb-4">
                    <div>
                        <h2 className="text-lg font-semibold text-gray-900 flex items-center gap-2">
                            ✨ Configuraciones Recomendadas
                        </h2>
                        <p className="text-sm text-gray-500 mt-1">
                            Selecciona un preset optimizado según el tamaño de tu catálogo
                        </p>
                    </div>
                    {savedKey === 'preset' && (
                        <div className="flex items-center gap-2 text-green-600 bg-green-50 px-3 py-1 rounded-full">
                            <CheckCircleIcon className="h-5 w-5" />
                            <span className="text-sm font-medium">¡Aplicado!</span>
                        </div>
                    )}
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-3">
                    {RECOMMENDED_PRESETS.map((preset) => {
                        const isRecommended = preset === getRecommendedPreset();
                        const isApplying = applyingPreset === preset.name;
                        const isActive = isPresetActive(preset);

                        return (
                            <motion.button
                                key={preset.name}
                                onClick={() => applyPreset(preset)}
                                disabled={!!applyingPreset}
                                whileHover={{ scale: 1.02 }}
                                whileTap={{ scale: 0.98 }}
                                className={`relative p-4 rounded-xl border-2 text-left transition-all ${isActive
                                    ? 'border-green-500 bg-green-50 ring-2 ring-green-200'
                                    : isRecommended
                                        ? 'border-amber-400 bg-amber-50 ring-2 ring-amber-200'
                                        : 'border-gray-200 bg-gray-50 hover:border-gray-300 hover:bg-white'
                                    } ${isApplying ? 'opacity-75' : ''}`}
                            >
                                {/* Badge: Activo (prioridad) o Recomendado */}
                                {isActive ? (
                                    <div className="absolute -top-2 -right-2 bg-green-500 text-white text-xs font-bold px-2 py-0.5 rounded-full shadow flex items-center gap-1">
                                        <CheckCircleIcon className="h-3 w-3" />
                                        Activo
                                    </div>
                                ) : isRecommended ? (
                                    <div className="absolute -top-2 -right-2 bg-amber-500 text-white text-xs font-bold px-2 py-0.5 rounded-full shadow">
                                        Recomendado
                                    </div>
                                ) : null}

                                <div className="text-2xl mb-2">{preset.icon}</div>
                                <h3 className={`font-semibold text-sm ${isActive ? 'text-green-800' : 'text-gray-900'}`}>
                                    {preset.name}
                                </h3>
                                <p className={`text-xs mt-1 ${isActive ? 'text-green-600' : 'text-gray-500'}`}>
                                    {preset.description}
                                </p>

                                {isApplying && (
                                    <div className="absolute inset-0 bg-white/50 rounded-xl flex items-center justify-center">
                                        <ArrowPathIcon className="h-6 w-6 text-amber-500 animate-spin" />
                                    </div>
                                )}
                            </motion.button>
                        );
                    })}
                </div>

                <div className="mt-4 p-3 bg-gray-50 rounded-lg flex flex-wrap items-center gap-2 text-xs">
                    <span className="text-gray-700 font-medium">📊 Tu catálogo:</span>
                    <span className="text-gray-600">{catalogSize} canciones</span>
                    <span className="text-gray-400">•</span>
                    <span className="text-gray-700 font-medium">Recomendado:</span>
                    <span className="text-amber-600 font-medium">{getRecommendedPreset().name}</span>
                    <span className="text-gray-400">•</span>
                    <span className="text-gray-700 font-medium">Activo:</span>
                    {getActivePreset() ? (
                        <span className="text-green-600 font-medium flex items-center gap-1">
                            <CheckCircleIcon className="h-3 w-3" />
                            {getActivePreset()?.name}
                        </span>
                    ) : (
                        <span className="text-gray-400 italic">Personalizado</span>
                    )}
                </div>
            </motion.div>

            {error && (
                <motion.div
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    className="p-4 bg-red-50 border border-red-200 rounded-xl flex items-center gap-3"
                >
                    <ExclamationCircleIcon className="h-5 w-5 text-red-500" />
                    <span className="text-red-700">{error}</span>
                </motion.div>
            )}

            {/* Algorithm Settings */}
            <div>
                <h2 className="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
                    <MusicalNoteIcon className="h-5 w-5 text-amber-500" />
                    Algoritmo de Recomendaciones
                </h2>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    {renderSettingCard('algorithm_history_size')}
                    {renderSettingCard('algorithm_phase2_count')}
                    {renderSettingCard('algorithm_phase31_count')}
                    {renderSettingCard('algorithm_buffer_size')}
                    {renderSettingCard('algorithm_preload_threshold')}
                    {renderSettingCard('algorithm_critical_songs')}
                </div>
            </div>

            {/* Catalog Settings */}
            <div>
                <h2 className="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
                    <ChartBarIcon className="h-5 w-5 text-amber-500" />
                    Configuración del Catálogo
                </h2>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    {renderSettingCard('catalog_small_threshold')}
                </div>
            </div>

            {/* Ad Settings */}
            <div>
                <h2 className="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
                    <MegaphoneIcon className="h-5 w-5 text-amber-500" />
                    Configuración de Anuncios
                </h2>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    {renderSettingCard('ad_frequency')}
                </div>
            </div>

            {/* Info */}
            <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                className="p-6 bg-gradient-to-r from-amber-50 to-orange-50 border border-amber-200 rounded-xl"
            >
                <h3 className="font-semibold text-amber-800 mb-2">🎯 ¿Cómo funcionan los presets?</h3>
                <p className="text-amber-700 text-sm mb-3">
                    Los presets están optimizados según el tamaño de tu catálogo. Cada uno ajusta automáticamente:
                </p>
                <ul className="text-amber-700 text-sm space-y-1 ml-4">
                    <li>• <strong>Historial:</strong> Evita repetir canciones recientes</li>
                    <li>• <strong>FASE 2.0:</strong> Recomendaciones en background mientras escuchas</li>
                    <li>• <strong>FASE 3.1:</strong> Precarga proactiva para evitar interrupciones</li>
                    <li>• <strong>Buffer:</strong> Canciones listas antes de reproducir</li>
                </ul>
                <p className="text-amber-600 text-xs mt-3 italic">
                    💡 La app carga estos valores al iniciar. Cambia un preset y reinicia la app para ver los efectos.
                </p>
            </motion.div>
        </div>
    );
}
