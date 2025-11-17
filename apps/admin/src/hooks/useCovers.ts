import { useMutation, useQueryClient } from 'react-query';
import { toast } from 'react-hot-toast';
import { apiClient } from '@/lib/api';
import axios from 'axios';

const extractErrorMessage = (error: unknown): string => {
  if (axios.isAxiosError(error)) {
    return error.response?.data?.message || error.message || 'Error desconocido';
  }
  if (error instanceof Error) {
    return error.message;
  }
  return 'Error desconocido';
};

export const useUploadCover = () => {
  const queryClient = useQueryClient();

  return useMutation(
    async (coverFile: File) => {
      const response = await apiClient.uploadCover(coverFile);
      return response.data;
    },
    {
      onSuccess: () => {
        toast.success('Portada subida exitosamente');
      },
      onError: (error) => {
        toast.error(extractErrorMessage(error));
      },
    }
  );
};

