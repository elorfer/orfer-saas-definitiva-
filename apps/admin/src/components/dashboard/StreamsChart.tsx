'use client';

import { useMemo } from 'react';
import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from 'recharts';
import { format } from 'date-fns';
import { es } from 'date-fns/locale';
import { useQuery } from 'react-query';
import { apiClient } from '@/lib/api';

interface ChartDataPoint {
  date: string;
  reproducciones: number;
  fechaFormateada: string;
}

/**
 * Componente profesional de gráfico de reproducciones
 * Muestra las reproducciones diarias de los últimos 7 días usando datos reales
 */
export default function StreamsChart() {
  const { data: dailyStreams, isLoading } = useQuery(
    ['dailyStreams', 7],
    () => apiClient.getDailyStreams(7),
    {
      staleTime: 60000, // Cache por 1 minuto
      refetchInterval: 120000, // Refrescar cada 2 minutos
    }
  );

  // Procesar datos para el gráfico
  const chartData = useMemo<ChartDataPoint[]>(() => {
    if (!dailyStreams?.data || !Array.isArray(dailyStreams.data)) {
      return [];
    }

    return dailyStreams.data.map((item: any) => ({
      date: item.date,
      reproducciones: item.count || 0,
      fechaFormateada: format(new Date(item.date), 'dd/MM', { locale: es }),
    }));
  }, [dailyStreams]);

  if (isLoading) {
    return (
      <div className="h-48 bg-gray-50 rounded-md border border-gray-200 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-8 w-8 border-2 border-brown-700 border-t-transparent mx-auto mb-2"></div>
          <p className="text-xs text-gray-400">Cargando gráfico...</p>
        </div>
      </div>
    );
  }

  if (chartData.length === 0) {
    return (
      <div className="h-48 bg-gray-50 rounded-md border border-gray-200 flex items-center justify-center">
        <p className="text-xs text-gray-400">No hay datos disponibles</p>
      </div>
    );
  }

  return (
    <ResponsiveContainer width="100%" height={192}>
      <AreaChart
        data={chartData}
        margin={{ top: 10, right: 10, left: -20, bottom: 0 }}
      >
        <defs>
          <linearGradient id="colorReproducciones" x1="0" y1="0" x2="0" y2="1">
            <stop offset="5%" stopColor="#7C2D12" stopOpacity={0.4} />
            <stop offset="95%" stopColor="#7C2D12" stopOpacity={0.05} />
          </linearGradient>
        </defs>
        <CartesianGrid strokeDasharray="3 3" stroke="#E5E7EB" vertical={false} />
        <XAxis
          dataKey="fechaFormateada"
          stroke="#6B7280"
          fontSize={11}
          tickLine={false}
          tickMargin={8}
        />
        <YAxis
          stroke="#6B7280"
          fontSize={11}
          tickLine={false}
          width={45}
          tickFormatter={(value) => value.toLocaleString('es-ES')}
        />
        <Tooltip
          contentStyle={{
            backgroundColor: 'white',
            border: '1px solid #E5E7EB',
            borderRadius: '8px',
            padding: '8px 12px',
            boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.1)',
          }}
          labelStyle={{ color: '#374151', fontWeight: 600, marginBottom: '4px', fontSize: '12px' }}
          formatter={(value: number) => [`${value.toLocaleString('es-ES')} reproducciones`, '']}
          labelFormatter={(label) => `Fecha: ${label}`}
        />
        <Area
          type="monotone"
          dataKey="reproducciones"
          stroke="#7C2D12"
          strokeWidth={2.5}
          fillOpacity={1}
          fill="url(#colorReproducciones)"
          dot={{ fill: '#7C2D12', r: 4 }}
          activeDot={{ r: 6, stroke: '#7C2D12', strokeWidth: 2 }}
        />
      </AreaChart>
    </ResponsiveContainer>
  );
}
