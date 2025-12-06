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
import { format } from 'date-fns';
import { es } from 'date-fns/locale';
import { useQuery } from 'react-query';
import { apiClient } from '@/lib/api';

interface ChartDataPoint {
  date: string;
  usuarios: number;
  fechaFormateada: string;
}

/**
 * Componente profesional de gráfico de usuarios activos
 * Muestra usuarios activos por día de los últimos 7 días usando datos reales
 */
export default function ActiveUsersChart() {
  const { data: dailyUsers, isLoading } = useQuery(
    ['dailyActiveUsers', 7],
    () => apiClient.getDailyActiveUsers(7),
    {
      staleTime: 60000, // Cache por 1 minuto
      refetchInterval: 120000, // Refrescar cada 2 minutos
    }
  );

  // Procesar datos para el gráfico
  const chartData = useMemo<ChartDataPoint[]>(() => {
    if (!dailyUsers?.data || !Array.isArray(dailyUsers.data)) {
      return [];
    }

    return dailyUsers.data.map((item: any) => ({
      date: item.date,
      usuarios: item.count || 0,
      fechaFormateada: format(new Date(item.date), 'dd/MM', { locale: es }),
    }));
  }, [dailyUsers]);

  if (isLoading) {
    return (
      <div className="h-48 bg-gray-50 rounded-md border border-gray-200 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-8 w-8 border-2 border-blue-600 border-t-transparent mx-auto mb-2"></div>
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

  const maxValue = Math.max(...chartData.map(d => d.usuarios), 1);

  // Colores con gradiente según el valor
  const getBarColor = (value: number) => {
    const percentage = (value / maxValue) * 100;
    if (percentage >= 70) return '#3B82F6'; // Azul oscuro
    if (percentage >= 40) return '#60A5FA'; // Azul medio
    return '#93C5FD'; // Azul claro
  };

  return (
    <ResponsiveContainer width="100%" height={192}>
      <BarChart
        data={chartData}
        margin={{ top: 10, right: 10, left: -20, bottom: 0 }}
      >
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
          domain={[0, maxValue + Math.ceil(maxValue * 0.1)]}
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
          formatter={(value: number) => [`${value} usuarios`, 'Activos']}
          labelFormatter={(label) => `Fecha: ${label}`}
        />
        <Bar
          dataKey="usuarios"
          radius={[8, 8, 0, 0]}
          fill="#3B82F6"
        >
          {chartData.map((entry, index) => (
            <Cell
              key={`cell-${index}`}
              fill={getBarColor(entry.usuarios)}
            />
          ))}
        </Bar>
      </BarChart>
    </ResponsiveContainer>
  );
}
