'use client';

import { useEffect, useState } from 'react';
import { useSession } from 'next-auth/react';
import { UserGroupIcon } from '@heroicons/react/24/outline';
import { io, Socket } from 'socket.io-client';
import { getApiUrl } from '@/lib/api';

interface ActiveUsersData {
  count: number;
  timestamp?: string;
}

/**
 * Componente para mostrar usuarios activos en tiempo real
 * Usa WebSockets para actualización instantánea
 */
export default function ActiveUsersRealTime() {
  const { data: session } = useSession();
  const [activeUsers, setActiveUsers] = useState<number>(0);
  const [socket, setSocket] = useState<Socket | null>(null);
  const [isConnected, setIsConnected] = useState(false);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    if (!session?.accessToken) {
      setIsLoading(false);
      return;
    }

    const apiUrl = getApiUrl();
    const wsUrl = apiUrl.replace(/^https?:\/\//, '').split('/')[0];
    const protocol = apiUrl.startsWith('https') ? 'wss' : 'ws';

    // Conectar al WebSocket
    const newSocket = io(`${protocol}://${wsUrl}/realtime`, {
      auth: {
        token: session.accessToken,
      },
      transports: ['websocket', 'polling'],
      reconnection: true,
      reconnectionDelay: 1000,
      reconnectionAttempts: 5,
    });

    newSocket.on('connect', () => {
      setIsConnected(true);
      setIsLoading(false);
      console.log('✅ Conectado al WebSocket de tiempo real');
      
      // Solicitar conteo inicial
      newSocket.emit('requestActiveUsers');
    });

    newSocket.on('disconnect', () => {
      setIsConnected(false);
      console.log('❌ Desconectado del WebSocket');
    });

    newSocket.on('connect_error', (error) => {
      console.error('❌ Error de conexión WebSocket:', error);
      setIsLoading(false);
    });

    // Escuchar actualizaciones de usuarios activos
    newSocket.on('activeUsersCount', (data: ActiveUsersData) => {
      setActiveUsers(data.count);
      setIsLoading(false);
    });

    setSocket(newSocket);

    // Cleanup al desmontar
    return () => {
      newSocket.close();
    };
  }, [session]);

  // Fallback: obtener datos vía HTTP si WebSocket falla
  useEffect(() => {
    if (!isConnected && !isLoading && session?.accessToken) {
      const fetchActiveUsers = async () => {
        try {
          const apiUrl = getApiUrl();
          const response = await fetch(`${apiUrl}/realtime/active-users-count`, {
            headers: {
              Authorization: `Bearer ${session.accessToken}`,
            },
          });
          
          if (response.ok) {
            const data = await response.json();
            setActiveUsers(data.count || 0);
          }
        } catch (error) {
          console.error('Error obteniendo usuarios activos:', error);
        }
      };

      // Polling cada 10 segundos como fallback
      fetchActiveUsers();
      const interval = setInterval(fetchActiveUsers, 10000);
      
      return () => clearInterval(interval);
    }
  }, [isConnected, isLoading, session]);

  return (
    <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-5 hover:shadow-md transition-shadow">
      <div className="flex items-center justify-between mb-4">
        <div>
          <h3 className="text-sm font-semibold text-gray-900">Usuarios Activos en Tiempo Real</h3>
          <p className="text-xs text-gray-500 mt-1">
            {isConnected ? (
              <span className="flex items-center">
                <span className="w-2 h-2 bg-green-500 rounded-full mr-2 animate-pulse"></span>
                Conectado en tiempo real
              </span>
            ) : (
              <span className="flex items-center">
                <span className="w-2 h-2 bg-gray-400 rounded-full mr-2"></span>
                Actualizando cada 10 segundos
              </span>
            )}
          </p>
        </div>
        <div className="p-2 bg-purple-100 rounded-lg">
          <UserGroupIcon className="h-5 w-5 text-purple-700" />
        </div>
      </div>
      
      <div className="flex items-end space-x-4">
        <div className="flex-1">
          {isLoading ? (
            <div className="flex items-center space-x-2">
              <div className="animate-spin rounded-full h-4 w-4 border-2 border-purple-600 border-t-transparent"></div>
              <span className="text-xs text-gray-500">Cargando...</span>
            </div>
          ) : (
            <>
              <p className="text-4xl font-bold text-gray-900 mb-1">
                {activeUsers.toLocaleString('es-ES')}
              </p>
              <p className="text-xs text-gray-500">
                {activeUsers === 1 ? 'usuario activo' : 'usuarios activos'}
              </p>
            </>
          )}
        </div>
        
        <div className="text-right">
          <div className="w-16 h-16 bg-gradient-to-br from-purple-500 to-purple-700 rounded-lg flex items-center justify-center">
            <UserGroupIcon className="h-8 w-8 text-white" />
          </div>
        </div>
      </div>
    </div>
  );
}

















