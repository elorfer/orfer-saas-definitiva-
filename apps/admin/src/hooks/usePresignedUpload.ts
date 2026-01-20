import imageCompression from 'browser-image-compression';
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
        setUploading(true);
        setProgress(0);
        setError(null);

        // 1. Definir variable fuera del try para que sea accesible en ambos flujos
        let fileToUpload = file;

        // 2. Compresión de imágenes (común para ambos flujos)
        if (folder === 'images' && file.type.startsWith('image/')) {
            try {
                console.log(`📉 Comprimiendo imagen... Original: ${(file.size / 1024 / 1024).toFixed(2)} MB`);
                const options = {
                    maxSizeMB: 1,
                    maxWidthOrHeight: 1920,
                    useWebWorker: true,
                    initialQuality: 0.8,
                };
                fileToUpload = await imageCompression(file, options);
                console.log(`✅ Comprimida: ${(fileToUpload.size / 1024 / 1024).toFixed(2)} MB`);
            } catch (err) {
                console.warn('⚠️ Error comprimiendo, usando original:', err);
            }
        }

        // 🌍 DETECCIÓN AUTOMÁTICA DE ENTORNO
        const isLocalhost = typeof window !== 'undefined' &&
            (window.location.hostname === 'localhost' ||
                window.location.hostname === '127.0.0.1');

        // ============================================================================
        // 💻 MODO LOCAL: Upload directo al backend (más rápido, sin dependencias cloud)
        // ============================================================================
        if (isLocalhost) {
            try {
                console.log('🏠 [Modo Local] Subiendo directo al backend...');

                // Validaciones básicas
                const maxSizes = {
                    images: 5 * 1024 * 1024,
                    audio: 100 * 1024 * 1024,
                };
                if (fileToUpload.size > maxSizes[folder]) {
                    throw new Error(`Archivo muy grande. Máximo: ${Math.round(maxSizes[folder] / 1024 / 1024)}MB`);
                }

                setProgress(20);
                onProgress?.(20);

                const formData = new FormData();
                formData.append('file', fileToUpload, file.name);

                const endpoint = folder === 'images' ? 'image' : 'audio';
                const response = await fetch(`${apiUrl}/api/v1/upload/${endpoint}`, {
                    method: 'POST',
                    headers: {
                        Authorization: `Bearer ${authToken}`,
                    },
                    body: formData,
                });

                if (!response.ok) {
                    const errorData = await response.json().catch(() => ({ message: 'Error desconocido' }));
                    throw new Error(errorData.message || `Error ${response.status}`);
                }

                const data = await response.json();

                setProgress(100);
                onProgress?.(100);
                setUploading(false);
                onSuccess?.(data.url, data.key);

                console.log('✅ Upload local exitoso');
                return { publicUrl: data.url, key: data.key };

            } catch (err) {
                console.error('❌ Error en upload local:', err);
                const errorMessage = err instanceof Error ? err.message : 'Error al subir archivo';
                setError(errorMessage);
                setUploading(false);
                onError?.(err instanceof Error ? err : new Error(errorMessage));
                throw err;
            }
        }

        // ============================================================================
        // ☁️ MODO PRODUCCIÓN: Presigned URL a R2/S3 (seguro, escalable)
        // ============================================================================
        try {
            console.log('☁️ [Modo Producción] Usando presigned URL...');

            // Validaciones
            const maxSizes = {
                images: 5 * 1024 * 1024,
                audio: 100 * 1024 * 1024,
            };
            if (fileToUpload.size > maxSizes[folder]) {
                throw new Error(`Archivo muy grande. Máximo: ${Math.round(maxSizes[folder] / 1024 / 1024)}MB`);
            }

            const allowedTypes = {
                images: ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'],
                audio: ['audio/mpeg', 'audio/mp3', 'audio/wav', 'audio/flac', 'audio/aac'],
            };
            if (!allowedTypes[folder].includes(file.type) && !allowedTypes[folder].includes(fileToUpload.type)) {
                throw new Error(`Tipo de archivo no permitido: ${file.type}`);
            }

            setProgress(10);
            onProgress?.(10);

            // Solicitar URL firmada
            const presignedResponse = await fetch(`${apiUrl}/api/v1/upload/presigned-url`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    Authorization: `Bearer ${authToken}`,
                },
                body: JSON.stringify({
                    fileName: file.name,
                    contentType: fileToUpload.type,
                    folder,
                    expectedSize: fileToUpload.size,
                }),
            });

            if (!presignedResponse.ok) {
                const errorData = await presignedResponse.json();
                throw new Error(errorData.message || 'Error obteniendo presigned URL');
            }

            const { uploadUrl, key, publicUrl }: PresignedUrlResponse = await presignedResponse.json();
            setProgress(20);
            onProgress?.(20);

            // Upload a R2/S3
            const uploadResponse = await fetch(uploadUrl, {
                method: 'PUT',
                headers: {
                    'Content-Type': fileToUpload.type,
                },
                body: fileToUpload,
            });

            if (!uploadResponse.ok) {
                throw new Error(`Error subiendo archivo: ${uploadResponse.statusText}`);
            }

            setProgress(100);
            onProgress?.(100);
            setUploading(false);
            onSuccess?.(publicUrl, key);

            console.log('✅ Upload a R2 exitoso');
            return { publicUrl, key };

        } catch (err) {
            console.error('❌ Error en presigned upload:', err);
            const errorMessage = err instanceof Error ? err.message : 'Error al subir archivo';
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
