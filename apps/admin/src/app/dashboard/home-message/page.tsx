'use client';

import { FormEvent, useEffect, useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from 'react-query';
import { toast } from 'react-hot-toast';
import {
  MegaphoneIcon,
  CheckCircleIcon,
  ExclamationTriangleIcon,
  ArrowPathIcon,
} from '@heroicons/react/24/outline';
import { apiClient } from '@/lib/api';

export default function HomeMessagePage() {
  const [message, setMessage] = useState('');
  const [isActive, setIsActive] = useState(true);
  const queryClient = useQueryClient();

  const { data, isLoading, isFetching } = useQuery(
    ['home-message'],
    async () => {
      const response = await apiClient.getHomeMessage();
      return response.data;
    },
    {
      onSuccess: (payload) => {
        if (payload?.message) {
          setMessage(payload.message);
          setIsActive(payload.isActive);
        }
      },
    }
  );

  const publishMutation = useMutation(
    async (payload: { message: string; isActive: boolean }) =>
      apiClient.publishHomeMessage(payload).then((res) => res.data),
    {
      onSuccess: () => {
        toast.success('Mensaje publicado en el home');
        queryClient.invalidateQueries(['home-message']);
      },
      onError: (error: any) => {
        const msg = error?.response?.data?.message || 'No se pudo publicar el mensaje';
        toast.error(msg);
      },
    }
  );

  const toggleMutation = useMutation(
    async (payload: { id: string; isActive: boolean }) =>
      apiClient.updateHomeMessageStatus(payload.id, payload.isActive),
    {
      onSuccess: () => {
        toast.success('Estado del mensaje actualizado');
        queryClient.invalidateQueries(['home-message']);
      },
      onError: (error: any) => {
        const msg = error?.response?.data?.message || 'No se pudo actualizar el estado';
        toast.error(msg);
      },
    }
  );

  const disableAllMutation = useMutation(apiClient.disableHomeMessages, {
    onSuccess: () => {
      toast.success('Mensaje ocultado en la app');
      queryClient.invalidateQueries(['home-message']);
      setIsActive(false);
    },
    onError: () => toast.error('No se pudo ocultar el mensaje'),
  });

  useEffect(() => {
    if (!data?.message) return;
    setMessage(data.message);
    setIsActive(data.isActive);
  }, [data]);

  const updatedAtText = useMemo(() => {
    if (!data?.updatedAt && !data?.publishedAt) return 'Sin publicaciones previas';
    const raw = data.updatedAt || data.publishedAt;
    return `Última actualización: ${new Date(raw).toLocaleString()}`;
  }, [data]);

  const handleSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const trimmed = message.trim();
    if (!trimmed) {
      toast.error('Escribe una frase antes de publicar');
      return;
    }
    publishMutation.mutate({ message: trimmed, isActive });
  };

  const handleToggleVisibility = () => {
    if (!data?.id) {
      toast.error('Publica un mensaje antes de cambiar su estado');
      return;
    }
    toggleMutation.mutate({ id: data.id, isActive: !data.isActive });
  };

  return (
    <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-6">
      <div className="flex items-center gap-3">
        <div className="h-12 w-12 rounded-xl bg-brown-100 flex items-center justify-center">
          <MegaphoneIcon className="h-6 w-6 text-brown-700" />
        </div>
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Mensaje destacado en Home</h1>
          <p className="text-sm text-gray-500">
            Publica una frase corta que aparecerá en la parte inferior del home de la app, bajo el tab bar.
          </p>
        </div>
      </div>

      <div className="bg-white rounded-2xl border border-gray-200 shadow-sm p-6 space-y-6">
        <div className="flex items-center justify-between">
          <div className="space-y-1">
            <p className="text-sm font-semibold text-gray-900">Mensaje actual</p>
            <p className="text-sm text-gray-500">{updatedAtText}</p>
            {data?.message && (
              <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-brown-50 text-brown-700 text-xs font-medium">
                <CheckCircleIcon className="h-4 w-4" />
                {data.isActive ? 'Mostrando en la app' : 'Guardado (oculto)'}
              </div>
            )}
          </div>
          <button
            type="button"
            onClick={() => queryClient.invalidateQueries(['home-message'])}
            className="flex items-center gap-2 rounded-lg border border-gray-200 bg-white px-3 py-2 text-sm font-medium text-gray-600 transition hover:border-brown-600 hover:text-brown-700"
            disabled={isFetching || isLoading}
          >
            <ArrowPathIcon className={`h-4 w-4 ${isFetching ? 'animate-spin' : ''}`} />
            Actualizar
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-2">
            <label className="text-sm font-medium text-gray-800">Frase para mostrar</label>
            <textarea
              value={message}
              onChange={(e) => setMessage(e.target.value)}
              maxLength={240}
              rows={3}
              className="w-full rounded-xl border border-gray-200 focus:border-brown-600 focus:ring-2 focus:ring-brown-100 text-gray-900 text-sm px-4 py-3 transition"
              placeholder="Comparte una novedad, invitación o mensaje motivador..."
            />
            <div className="flex items-center justify-between text-xs text-gray-500">
              <span>Máximo 240 caracteres</span>
              <span>{message.length}/240</span>
            </div>
          </div>

          <div className="flex items-center justify-between rounded-xl border border-gray-200 bg-gray-50 px-4 py-3">
            <div className="flex items-start gap-3">
              <div className="h-9 w-9 rounded-full bg-brown-100 flex items-center justify-center">
                <MegaphoneIcon className="h-5 w-5 text-brown-700" />
              </div>
              <div>
                <p className="text-sm font-semibold text-gray-900">Mostrar en la app</p>
                <p className="text-xs text-gray-500">
                  Si desactivas esta opción, la frase se guarda pero no se mostrará en los usuarios.
                </p>
              </div>
            </div>
            <label className="inline-flex items-center cursor-pointer">
              <input
                type="checkbox"
                className="sr-only peer"
                checked={isActive}
                onChange={(e) => setIsActive(e.target.checked)}
              />
              <div className="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-2 peer-focus:ring-brown-200 rounded-full peer peer-checked:bg-brown-600 transition"></div>
            </label>
          </div>

          <div className="flex flex-col sm:flex-row sm:items-center gap-3">
            <button
              type="submit"
              className="inline-flex justify-center items-center gap-2 px-4 py-2 rounded-lg bg-brown-700 text-white text-sm font-semibold shadow-sm hover:bg-brown-800 transition disabled:opacity-60"
              disabled={publishMutation.isLoading}
            >
              {publishMutation.isLoading ? 'Publicando...' : 'Publicar mensaje'}
            </button>

            <button
              type="button"
              onClick={handleToggleVisibility}
              disabled={!data?.id || toggleMutation.isLoading}
              className="inline-flex justify-center items-center gap-2 px-4 py-2 rounded-lg border border-gray-200 text-sm font-semibold text-gray-700 hover:border-brown-600 hover:text-brown-700 transition disabled:opacity-50"
            >
              {toggleMutation.isLoading
                ? 'Actualizando...'
                : data?.isActive
                  ? 'Ocultar mensaje'
                  : 'Mostrar mensaje'}
            </button>

            <button
              type="button"
              onClick={() => disableAllMutation.mutate()}
              className="inline-flex justify-center items-center gap-2 px-4 py-2 rounded-lg border border-transparent text-sm font-semibold text-red-600 hover:bg-red-50 transition disabled:opacity-50"
              disabled={disableAllMutation.isLoading}
            >
              <ExclamationTriangleIcon className="h-4 w-4" />
              Ocultar en la app
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}





