import { useState } from 'react';

interface PresignedUrlResponse {
    uploadUrl: string;
    key: string;
    publicUrl: string;
    expiresIn: number;
}

interface UsePresignedUploadOptions {
    apiUrl: string;
    authToken: string;
    folder?: 'images' | 'audio';
    onProgress?: (progress: number) => void;
    onSuccess?: (publicUrl: string, key: string) => void;
    onError?: (error: Error) => void;
}

export function usePresignedUpload({
    apiUrl,
    authToken,
    folder = 'images',
    onProgress,
    onSuccess,
    onError,
}: UsePresignedUploadOptions) {
    const [uploading, setUploading] = useState(false);
    const [progress, setProgress] = useState(0);
    const [error, setError] = useState<string | null>(null);

    const uploadFile = async (file: File) => {
        try {
            setUploading(true);
            setProgress(0);
            setError(null);

            // ✅ 1. VALIDACIONES CLIENT-SIDE
            const maxSizes = {
                images: 5 * 1024 * 1024, // 5MB
                audio: 100 * 1024 * 1024, // 100MB
            };

            if (file.size > maxSizes[folder]) {
                throw new Error(
                    `Archivo muy grande. Máximo: ${Math.round(maxSizes[folder] / 1024 / 1024)}MB`
                );
            }

            const allowedTypes = {
                images: ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'],
                audio: ['audio/mpeg', 'audio/mp3', 'audio/wav', 'audio/flac', 'audio/aac'],
            };

            if (!allowedTypes[folder].includes(file.type)) {
                throw new Error(`Tipo de archivo no permitido: ${file.type}`);
            }

            setProgress(10);
            onProgress?.(10);

            // ✅ 2. SOLICITAR PRESIGNED URL AL BACKEND
            const presignedResponse = await fetch(`${apiUrl}/api/v1/upload/presigned-url`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    Authorization: `Bearer ${authToken}`,
                },
                body: JSON.stringify({
                    fileName: file.name,
                    contentType: file.type,
                    folder,
                    expectedSize: file.size,
                }),
            });

            if (!presignedResponse.ok) {
                const errorData = await presignedResponse.json();
                throw new Error(errorData.message || 'Error obteniendo presigned URL');
            }

            const { uploadUrl, key, publicUrl }: PresignedUrlResponse =
                await presignedResponse.json();

            setProgress(20);
            onProgress?.(20);

            // ✅ 3. UPLOAD DIRECTO A R2
            const uploadResponse = await fetch(uploadUrl, {
                method: 'PUT',
                headers: {
                    'Content-Type': file.type,
                },
                body: file,
            });

            if (!uploadResponse.ok) {
                throw new Error(`Error subiendo archivo: ${uploadResponse.statusText}`);
            }

            setProgress(100);
            onProgress?.(100);

            // ✅ 4. SUCCESS
            setUploading(false);
            onSuccess?.(publicUrl, key);

            return { publicUrl, key };
        } catch (err) {
            const errorMessage = err instanceof Error ? err.message : 'Error desconocido';
            setError(errorMessage);
            setUploading(false);
            onError?.(err instanceof Error ? err : new Error(errorMessage));
            throw err;
        }
    };

    return {
        uploadFile,
        uploading,
        progress,
        error,
    };
}
