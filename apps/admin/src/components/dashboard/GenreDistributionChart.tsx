'use client';

import { useMemo } from 'react';
import {
  PieChart,
  Pie,
  Cell,
  ResponsiveContainer,
  Tooltip,
  Legend,
} from 'recharts';
import { useQuery } from 'react-query';
import { apiClient } from '@/lib/api';

interface GenreData {
  genre: string;
  count: number;
  percentage: number;
}

/**
 * Colores profesionales para géneros
 */
const GENRE_COLORS = [
  '#7C2D12', // Marrón oscuro
  '#EA580C', // Naranja
  '#F97316', // Naranja claro
  '#FB923C', // Naranja más claro
  '#FED7AA', // Beige
  '#9A3412', // Marrón rojizo
  '#C2410C', // Rojo naranja
];

/**
 * Componente profesional de gráfico de distribución por géneros
 * Muestra los géneros más populares en formato de dona
 */
export default function GenreDistributionChart() {
  const { data: genreData, isLoading } = useQuery(
    ['genreDistribution', 5],
    () => apiClient.getGenreDistribution(5),
    {
      staleTime: 300000, // Cache por 5 minutos (los géneros no cambian tan frecuentemente)
      refetchInterval: 600000, // Refrescar cada 10 minutos
    }
  );

  const chartData = useMemo(() => {
    if (!genreData?.data || !Array.isArray(genreData.data)) {
      return [];
    }

    // Filtrar "Sin género" del gráfico para que se vea más limpio
    return genreData.data
      .filter((item: GenreData) => item.genre !== 'Sin género')
      .map((item: GenreData, index: number) => ({
        name: item.genre,
        value: item.count,
        percentage: item.percentage,
        color: GENRE_COLORS[index % GENRE_COLORS.length],
      }));
  }, [genreData]);

  if (isLoading) {
    return (
      <div className="h-48 bg-gray-50 rounded-md border border-gray-200 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-8 w-8 border-2 border-green-600 border-t-transparent mx-auto mb-2"></div>
          <p className="text-xs text-gray-400">Cargando gráfico...</p>
        </div>
      </div>
    );
  }

  if (chartData.length === 0) {
    return (
      <div className="h-48 bg-gray-50 rounded-md border border-gray-200 flex items-center justify-center">
        <p className="text-xs text-gray-400">No hay datos de géneros disponibles</p>
      </div>
    );
  }

  const total = chartData.reduce((sum, item) => sum + item.value, 0);

  return (
    <ResponsiveContainer width="100%" height={192}>
      <PieChart>
        <Pie
          data={chartData}
          cx="50%"
          cy="50%"
          labelLine={false}
          label={({ name, percentage }) => {
            // Capitalizar primera letra de cada palabra y formatear
            const formattedName = name
              .split(' ')
              .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
              .join(' ');
            // Mostrar solo si el porcentaje es significativo (> 2%)
            if (percentage < 2) return '';
            return `${formattedName}: ${percentage.toFixed(1)}%`;
          }}
          outerRadius={70}
          innerRadius={40}
          fill="#8884d8"
          dataKey="value"
        >
          {chartData.map((entry, index) => (
            <Cell key={`cell-${index}`} fill={entry.color} />
          ))}
        </Pie>
        <Tooltip
          contentStyle={{
            backgroundColor: 'white',
            border: '1px solid #E5E7EB',
            borderRadius: '8px',
            padding: '8px 12px',
            boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.1)',
          }}
          formatter={(value: number) => [
            `${value.toLocaleString('es-ES')} reproducciones`,
            'Total'
          ]}
        />
      </PieChart>
    </ResponsiveContainer>
  );
}

