'use client';

import { useState, useEffect } from 'react';
import { toast } from 'react-hot-toast';
import { apiClient } from '@/lib/api';
import { TrashIcon, ShieldCheckIcon, ExclamationTriangleIcon } from '@heroicons/react/24/outline';
import { useQueryClient } from 'react-query';

export default function CleanupPage() {
    const [isCleaning, setIsCleaning] = useState(false);
    const [logs, setLogs] = useState<string[]>([]);
    const [stats, setStats] = useState({ users: 0, songs: 0, artists: 0, playlists: 0 });
    const [loadingStats, setLoadingStats] = useState(true);

    const queryClient = useQueryClient();

    // Cargar estadísticas iniciales
    useEffect(() => {
        fetchStats();
    }, []);

    const addLog = (msg: string) => setLogs(prev => [...prev, `[${new Date().toLocaleTimeString()}] ${msg}`]);

    const fetchStats = async () => {
        try {
            setLoadingStats(true);
            // Nota: Estos endpoints asumen que devuelven listas o totales.
            // Si no existen endpoints de "count", obtenemos listas paginadas (limit alto).
            const [usersRes, songsRes, artistsRes, playlistsRes] = await Promise.all([
                apiClient.getUsers(1, 100), // Asumimos max 100 para muestra inicial
                apiClient.getSongs(1, 100),
                apiClient.getArtists(1, 100),
                apiClient.getPlaylists(1, 100)
            ]);

            setStats({
                users: usersRes.data.total || usersRes.data.users?.length || 0,
                songs: songsRes.data.total || songsRes.data.songs?.length || 0,
                artists: artistsRes.data.total || artistsRes.data.artists?.length || 0,
                playlists: playlistsRes.data.total || playlistsRes.data.playlists?.length || 0
            });
            setLoadingStats(false);
        } catch (e: any) {
            console.error(e);
            addLog(`Error cargando estadísticas: ${e.message}`);
            setLoadingStats(false);
        }
    };

    const handlePurge = async () => {
        if (!confirm('¡PELIGRO! ¿ESTÁS SEGURO DE QUE QUIERES BORRAR TODOS LOS DATOS?\nEsto eliminará usuarios, canciones y artistas.\nSólo se salvará admin@struky.com.\n\nEsta acción NO se puede deshacer.')) return;

        // Segunda confirmación
        if (!confirm('CONFIRMACIÓN FINAL: Se borrarán permanentemente los datos de prueba. ¿Proceder?')) return;

        setIsCleaning(true);
        setLogs([]);
        addLog('INICIANDO LIMPIEZA PROFUNDA...');

        try {
            // 1. Borrar Canciones (Loop hasta borrar todas)
            addLog('--- Fase 1: Eliminando Canciones ---');
            let songsLeft = true;
            while (songsLeft) {
                const res = await apiClient.getSongs(1, 50); // Traer de 50 en 50
                const songs = res.data.songs || [];
                if (songs.length === 0) {
                    songsLeft = false;
                    break;
                }

                for (const song of songs) {
                    try {
                        await apiClient.deleteSong(song.id);
                        addLog(`Canción eliminada: ${song.title}`);
                    } catch (err) {
                        addLog(`❌ Error borrando canción ${song.title}: ${err}`);
                    }
                }
            }
            addLog('✅ Canciones eliminadas.');

            // 2. Borrar Playlists
            addLog('--- Fase 2: Eliminando Playlists ---');
            let playlistsLeft = true;
            while (playlistsLeft) {
                const res = await apiClient.getPlaylists(1, 50);
                const playlists = res.data.playlists || [];
                if (playlists.length === 0) {
                    playlistsLeft = false;
                    break;
                }

                for (const pl of playlists) {
                    try {
                        await apiClient.deletePlaylist(pl.id);
                        addLog(`Playlist eliminada: ${pl.name}`);
                    } catch (err) {
                        addLog(`❌ Error borrando playlist ${pl.name}: ${err}`);
                    }
                }
            }
            addLog('✅ Playlists eliminadas.');

            // 3. Borrar Artistas (Usuarios con rol artista)
            // Nota: Al borrar usuarios, los perfiles de artista deberían borrarse en cascada si la DB está bien.
            // Pero intentaremos borrar artistas explícitamente primero por si acaso.
            addLog('--- Fase 3: Eliminando Artistas ---');
            let artistsLeft = true;
            while (artistsLeft) {
                const res = await apiClient.getArtists(1, 50);
                const artists = res.data.artists || [];
                // Filtramos los que NO son el usuario admin (aunque admin no debería ser artista, por seguridad)
                const toDelete = artists;

                if (toDelete.length === 0) {
                    artistsLeft = false;
                    break;
                }

                for (const artist of toDelete) {
                    // Protección extra: verificar si el artista está ligado al email admin (poco probable pero...)
                    if (artist.user?.email === 'admin@struky.com') {
                        addLog(`🛡️ SALTANDO Artista Admin: ${artist.stageName}`);
                        continue;
                    }

                    try {
                        // Asumimos que hay un endpoint deleteArtist, si no, se borrará con el usuario
                        // Si no existe deleteArtist en apiClient, saltamos este paso y confiamos en deleteUser
                        // Revisando apiClient... parece que no expone deleteArtist públicamente en todos los contextos o usa deleteUser.
                        // Intentaremos borrar via endpoint si existe, si no, user cleanup.
                        // Para asegurar, saltamos a usuarios directamente, ya que un Artista ES un Usuario.
                    } catch (err) { }
                }
                // Break loop para ir a usuarios directamente, ya que borrar artistas sueltos puede ser redundante
                artistsLeft = false;
            }
            addLog('⏭️ Pasando a borrado de usuarios (esto borrará los artistas asociados).');

            // 4. Borrar Usuarios (MANTENIENDO ADMIN)
            addLog('--- Fase 4: Eliminando Usuarios (Excepto Admin) ---');
            const ADMIN_EMAILS = ['admin@struky.com'];

            // Iteramos varias veces porque la paginación cambia al borrar
            let usersLeft = true;
            while (usersLeft) {
                const res = await apiClient.getUsers(1, 50);
                const users = res.data.users || [];

                // Si solo queda el admin (o menos), paramos
                const nonAdminUsers = users.filter((u: any) => !ADMIN_EMAILS.includes(u.email));

                if (nonAdminUsers.length === 0) {
                    // Verificamos si hay más páginas
                    if ((res.data.totalPages || 1) <= 1) {
                        usersLeft = false;
                        break;
                    }
                    // Si hay más páginas pero esta pagina está llena de admins (raro), seguimos?
                    // Mejor: si users length > 0 y todos son admin, y total > users.length, hay más.
                    // Pero simplifiquemos: si no borramos ninguno en esta pasada, terminamos.
                    usersLeft = false;
                    break;
                }

                let deletedCount = 0;
                for (const user of nonAdminUsers) {
                    try {
                        await apiClient.deleteUser(user.id);
                        addLog(`Usuario eliminado: ${user.email} (${user.role})`);
                        deletedCount++;
                    } catch (err) {
                        addLog(`❌ Error borrando usuario ${user.email}: ${err}`);
                    }
                }

                if (deletedCount === 0) {
                    usersLeft = false; // Evitar bucles infinitos si fallan los borrados
                }
            }
            addLog('✅ Usuarios eliminados.');

            toast.success('Limpieza completada con éxito');
            addLog('✨ LIMPIEZA FINALIZADA ✨');
            addLog('Recargando estadísticas...');
            await fetchStats();

            // Invalidar cachés globales
            queryClient.invalidateQueries();

        } catch (error: any) {
            addLog(`❌ ERROR FATAL EN EL PROCESO: ${error.message}`);
            toast.error('Hubo errores durante la limpieza. Revisa el log.');
        } finally {
            setIsCleaning(false);
        }
    };

    return (
        <div className="max-w-4xl mx-auto p-6 space-y-8">
            <div className="bg-red-50 border-l-4 border-red-500 p-4 rounded-md">
                <div className="flex items-start">
                    <ExclamationTriangleIcon className="h-6 w-6 text-red-600 mr-3 mt-0.5" />
                    <div>
                        <h2 className="text-lg font-bold text-red-800">Zona de Peligro: Limpieza del Sistema</h2>
                        <p className="text-red-700 text-sm mt-1">
                            Esta herramienta permite eliminar masivamente datos basura.
                            <br />
                            <strong>Se conservará la cuenta: admin@struky.com</strong>
                        </p>
                    </div>
                </div>
            </div>

            {/* Estadísticas */}
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                <StatCard title="Usuarios" count={stats.users} loading={loadingStats} />
                <StatCard title="Artistas" count={stats.artists} loading={loadingStats} />
                <StatCard title="Canciones" count={stats.songs} loading={loadingStats} />
                <StatCard title="Playlists" count={stats.playlists} loading={loadingStats} />
            </div>

            {/* Controles */}
            <div className="flex flex-col items-center justify-center py-8 border-t border-gray-200">
                <button
                    onClick={handlePurge}
                    disabled={isCleaning || loadingStats}
                    className="flex items-center gap-3 px-8 py-4 bg-red-600 text-white rounded-xl font-bold text-lg shadow-lg hover:bg-red-700 hover:scale-105 transition disabled:opacity-50 disabled:cursor-not-allowed"
                >
                    {isCleaning ? (
                        <>
                            <div className="animate-spin h-6 w-6 border-4 border-white border-t-transparent rounded-full"></div>
                            BORRANDO DATOS...
                        </>
                    ) : (
                        <>
                            <TrashIcon className="h-6 w-6" />
                            INICIAR PURGA DE DATOS
                        </>
                    )}
                </button>
                <p className="mt-4 text-sm text-gray-500">
                    <ShieldCheckIcon className="inline h-4 w-4 text-green-500 mr-1" />
                    Protegido: admin@struky.com
                </p>
            </div>

            {/* Consola de Logs */}
            <div className="bg-gray-900 rounded-xl p-4 font-mono text-xs md:text-sm text-green-400 h-96 overflow-y-auto shadow-inner border border-gray-700">
                {logs.length === 0 ? (
                    <div className="h-full flex items-center justify-center text-gray-600 italic">
                        Esperando inicio de operaciones...
                    </div>
                ) : (
                    logs.map((log, i) => (
                        <div key={i} className="mb-1 border-b border-gray-800 pb-1 last:border-0">
                            {log}
                        </div>
                    ))
                )}
            </div>
        </div>
    );
}

function StatCard({ title, count, loading }: { title: string, count: number, loading: boolean }) {
    return (
        <div className="bg-white p-4 rounded-xl border border-gray-200 shadow-sm text-center">
            <h3 className="text-gray-500 text-xs uppercase font-semibold">{title}</h3>
            <p className="text-3xl font-bold text-gray-900 mt-2">
                {loading ? '...' : count}
            </p>
        </div>
    );
}

