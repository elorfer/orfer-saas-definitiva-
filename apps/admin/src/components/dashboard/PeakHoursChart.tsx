'use client';

import { useMemo } from 'react';
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Cell,
} from 'recharts';
import { useQuery } from 'react-query';
import { apiClient } from '@/lib/api';

interface HourData {
  hour: number;
  count: number;
}

/**
 * Componente profesional de gráfico de horas pico
 * Muestra la actividad por hora del día
 */
export default function PeakHoursChart() {
  const { data: peakHours, isLoading } = useQuery(
    'peakHours',
    () => apiClient.getPeakHours(),
    {
      staleTime: 300000, // Cache por 5 minutos
      refetchInterval: 600000, // Refrescar cada 10 minutos
    }
  );

  const chartData = useMemo(() => {
    if (!peakHours?.data || !Array.isArray(peakHours.data)) {
      return [];
    }

    return peakHours.data.map((item: HourData) => ({
      hora: item.hour,
      reproducciones: item.count || 0,
      horaFormateada: `${item.hour.toString().padStart(2, '0')}:00`,
    }));
  }, [peakHours]);

  if (isLoading) {
    return (
      <div className="h-48 bg-gray-50 rounded-md border border-gray-200 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-8 w-8 border-2 border-orange-600 border-t-transparent mx-auto mb-2"></div>
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

  const maxValue = Math.max(...chartData.map(d => d.reproducciones), 1);

  // Determinar color según la hora (mañana, tarde, noche)
  const getBarColor = (hour: number, value: number) => {
    const percentage = (value / maxValue) * 100;
    
    if (hour >= 6 && hour < 12) {
      // Mañana - tonos azules
      return percentage >= 50 ? '#3B82F6' : '#93C5FD';
    } else if (hour >= 12 && hour < 18) {
      // Tarde - tonos naranjas
      return percentage >= 50 ? '#F97316' : '#FED7AA';
    } else if (hour >= 18 && hour < 22) {
      // Noche temprana - tonos marrones (pico)
      return percentage >= 50 ? '#7C2D12' : '#C2410C';
    } else {
      // Noche/madrugada - tonos oscuros
      return percentage >= 50 ? '#374151' : '#6B7280';
    }
  };

  return (
    <ResponsiveContainer width="100%" height={192}>
      <BarChart
        data={chartData}
        margin={{ top: 10, right: 10, left: -20, bottom: 0 }}
        barCategoryGap="10%"
      >
        <CartesianGrid strokeDasharray="3 3" stroke="#E5E7EB" vertical={false} />
        <XAxis
          dataKey="horaFormateada"
          stroke="#6B7280"
          fontSize={10}
          tickLine={false}
          tickMargin={8}
          angle={-45}
          textAnchor="end"
          height={60}
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
          labelFormatter={(label) => `Hora: ${label}`}
        />
        <Bar
          dataKey="reproducciones"
          radius={[4, 4, 0, 0]}
        >
          {chartData.map((entry, index) => (
            <Cell
              key={`cell-${index}`}
              fill={getBarColor(entry.hora, entry.reproducciones)}
            />
          ))}
        </Bar>
      </BarChart>
    </ResponsiveContainer>
  );
}













