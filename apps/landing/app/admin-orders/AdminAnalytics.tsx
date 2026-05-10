'use client';

import { TrendingUp, DollarSign, Package, Calendar } from 'lucide-react';
import RechargeParticles from '@/components/RechargeParticles';

interface AdminAnalyticsProps {
    sessions: any[];
}

export default function AdminAnalytics({ sessions }: AdminAnalyticsProps) {
    // 1. Cálculos de KPIs
    const totalRevenue = sessions.reduce((acc, s) => acc + ((s.amount_total || 0) / 100), 0);
    
    const now = new Date();
    const thirtyDaysAgo = new Date(now.getTime() - (30 * 24 * 60 * 60 * 1000));
    
    const revenueLast30Days = sessions
        .filter(s => new Date(s.created * 1000) > thirtyDaysAgo)
        .reduce((acc, s) => acc + ((s.amount_total || 0) / 100), 0);

    const pendingOrders = sessions.filter(s => (s.metadata?.status || 'Pendiente') === 'Pendiente').length;

    // 2. Datos para el gráfico (últimos 14 días)
    const last14Days = Array.from({ length: 14 }, (_, i) => {
        const d = new Date();
        d.setDate(d.getDate() - (13 - i));
        return d.toISOString().split('T')[0];
    });

    const chartData = last14Days.map(dateStr => {
        const count = sessions.filter(s => {
            const sessionDate = new Date(s.created * 1000).toISOString().split('T')[0];
            return sessionDate === dateStr;
        }).length;
        return { date: dateStr, count };
    });

    const maxCount = Math.max(...chartData.map(d => d.count), 1);

    return (
        <div className="space-y-6 mb-10">
            {/* KPI GRID */}
            <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
                <div className="glass-morphism p-5 rounded-2xl border border-white/5 relative overflow-hidden group">
                    <RechargeParticles />
                    <div className="absolute top-0 right-0 p-3 opacity-10 group-hover:opacity-20 transition-opacity">
                        <DollarSign className="w-12 h-12 text-coffee-light" />
                    </div>
                    <span className="text-[10px] text-gray-500 font-bold uppercase tracking-widest block mb-1">Ingresos Totales</span>
                    <div className="flex items-baseline gap-1 relative z-10">
                        <span className="text-2xl font-black text-white">${totalRevenue.toLocaleString()}</span>
                        <span className="text-xs text-gray-400 font-bold uppercase">USD</span>
                    </div>
                </div>

                <div className="glass-morphism p-5 rounded-2xl border border-white/5 relative overflow-hidden group">
                    <RechargeParticles />
                    <div className="absolute top-0 right-0 p-3 opacity-10 group-hover:opacity-20 transition-opacity">
                        <TrendingUp className="w-12 h-12 text-green-400" />
                    </div>
                    <span className="text-[10px] text-gray-500 font-bold uppercase tracking-widest block mb-1">Últimos 30 días</span>
                    <div className="flex items-baseline gap-1 relative z-10">
                        <span className="text-2xl font-black text-green-400">${revenueLast30Days.toLocaleString()}</span>
                        <span className="text-[10px] text-green-400/50 font-bold uppercase ml-1">+{(revenueLast30Days/totalRevenue * 100 || 0).toFixed(0)}%</span>
                    </div>
                </div>

                <div className="glass-morphism p-5 rounded-2xl border border-white/5 relative overflow-hidden group">
                    <div className="absolute top-0 right-0 p-3 opacity-10 group-hover:opacity-20 transition-opacity">
                        <Package className="w-12 h-12 text-coffee-medium" />
                    </div>
                    <span className="text-[10px] text-gray-500 font-bold uppercase tracking-widest block mb-1">Total Pedidos</span>
                    <div className="flex items-baseline gap-1">
                        <span className="text-2xl font-black text-white">{sessions.length}</span>
                        <span className="text-xs text-gray-500 font-bold uppercase ml-1">Ventas</span>
                    </div>
                </div>

                <div className="glass-morphism p-5 rounded-2xl border border-white/5 relative overflow-hidden group">
                    <div className="absolute top-0 right-0 p-3 opacity-10 group-hover:opacity-20 transition-opacity">
                        <Calendar className="w-12 h-12 text-blue-400" />
                    </div>
                    <span className="text-[10px] text-gray-500 font-bold uppercase tracking-widest block mb-1">Cola de Trabajo</span>
                    <div className="flex items-baseline gap-1">
                        <span className="text-2xl font-black text-blue-400">{pendingOrders}</span>
                        <span className="text-xs text-blue-400/50 font-bold uppercase ml-1">Pendientes</span>
                    </div>
                </div>
            </div>

            {/* CHART SECTION */}
            <div className="glass-morphism p-6 rounded-3xl border border-white/5">
                <div className="flex justify-between items-center mb-8">
                    <div>
                        <h3 className="text-sm font-bold text-white uppercase tracking-widest">Actividad Reciente</h3>
                        <p className="text-[10px] text-gray-500 uppercase tracking-widest mt-1">Pedidos de los últimos 14 días</p>
                    </div>
                    <div className="flex items-center gap-4 text-[10px] font-bold uppercase tracking-widest">
                        <div className="flex items-center gap-1.5">
                            <div className="w-2 h-2 rounded-full bg-coffee-medium shadow-[0_0_8px_currentColor]"></div>
                            <span className="text-gray-400 italic">Ventas Diarias</span>
                        </div>
                    </div>
                </div>

                {/* CSS BAR CHART */}
                <div className="flex items-end justify-between h-32 gap-1 md:gap-3 group/chart">
                    {chartData.map((day, idx) => {
                        const heightPercent = (day.count / maxCount) * 100;
                        const dateObj = new Date(day.date);
                        const dayLabel = dateObj.toLocaleDateString('es-ES', { weekday: 'short' }).toUpperCase();
                        
                        return (
                            <div key={day.date} className="flex-1 flex flex-col items-center group/bar">
                                <div className="relative w-full flex flex-col items-center">
                                    {/* Tooltip */}
                                    <div className="absolute -top-8 left-1/2 -translate-x-1/2 bg-white text-black text-[9px] font-black px-1.5 py-0.5 rounded opacity-0 group-hover/bar:opacity-100 transition-opacity pointer-events-none z-10 whitespace-nowrap uppercase tracking-tighter">
                                        {day.count} {day.count === 1 ? 'Pedido' : 'Pedidos'}
                                    </div>
                                    
                                    {/* Bar shadow/glow */}
                                    <div 
                                        style={{ height: `${heightPercent}%` }}
                                        className={`w-full max-w-[12px] md:max-w-[20px] rounded-t-sm transition-all duration-700 bg-coffee-medium opacity-20 group-hover/chart:opacity-10 absolute bottom-0 shadow-[0_0_20px_rgba(202,160,82,0.1)]`}
                                    ></div>
                                    
                                    {/* Main Bar */}
                                    <div 
                                        style={{ height: `${heightPercent}%`, animationDelay: `${idx * 40}ms` }}
                                        className={`w-full max-w-[12px] md:max-w-[20px] rounded-t-sm animate-bar-rise ${day.count > 0 ? 'bg-coffee-light shadow-[0_0_10px_rgba(202,160,82,0.3)]' : 'bg-white/5'}`}
                                    ></div>
                                </div>
                                <span className={`text-[8px] md:text-[9px] font-black mt-3 transition-colors ${day.count > 0 ? 'text-gray-400' : 'text-gray-700'}`}>
                                    {dayLabel}
                                </span>
                            </div>
                        );
                    })}
                </div>
            </div>

            <style dangerouslySetInnerHTML={{ __html: `
                @keyframes bar-rise {
                    from { transform: scaleY(0); opacity: 0; }
                    to { transform: scaleY(1); opacity: 1; }
                }
                .animate-bar-rise {
                    transform-origin: bottom;
                    transform: scaleY(0);
                    animation: bar-rise 1s cubic-bezier(0.16, 1, 0.3, 1) forwards;
                }
            `}} />
        </div>
    );
}
