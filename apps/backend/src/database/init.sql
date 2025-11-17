-- Crear base de datos si no existe
CREATE DATABASE IF NOT EXISTS vintage_music;

-- Usar la base de datos
\c vintage_music;

-- Crear extensiones necesarias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Crear tipos de enum
CREATE TYPE user_role AS ENUM ('admin', 'artist', 'user');
CREATE TYPE subscription_status AS ENUM ('active', 'inactive', 'cancelled', 'expired');
CREATE TYPE song_status AS ENUM ('draft', 'published', 'archived');
CREATE TYPE playlist_visibility AS ENUM ('public', 'private', 'unlisted');

-- Tabla de usuarios
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    avatar_url TEXT,
    role user_role NOT NULL DEFAULT 'user',
    subscription_status subscription_status NOT NULL DEFAULT 'inactive',
    subscription_expires_at TIMESTAMP,
    is_verified BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    last_login_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de artistas (extiende usuarios)
CREATE TABLE IF NOT EXISTS artists (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    stage_name VARCHAR(100) NOT NULL,
    bio TEXT,
    website_url TEXT,
    social_links JSONB DEFAULT '{}',
    verification_status BOOLEAN DEFAULT FALSE,
    total_streams BIGINT DEFAULT 0,
    total_followers INTEGER DEFAULT 0,
    monthly_listeners INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de géneros musicales
CREATE TABLE IF NOT EXISTS genres (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    color_hex VARCHAR(7),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de álbumes
CREATE TABLE IF NOT EXISTS albums (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    artist_id UUID NOT NULL REFERENCES artists(id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    cover_art_url TEXT,
    release_date DATE,
    genre_id UUID REFERENCES genres(id),
    total_tracks INTEGER DEFAULT 0,
    total_duration INTEGER DEFAULT 0, -- en segundos
    is_single BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de canciones
CREATE TABLE IF NOT EXISTS songs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    artist_id UUID NOT NULL REFERENCES artists(id) ON DELETE CASCADE,
    album_id UUID REFERENCES albums(id) ON DELETE SET NULL,
    title VARCHAR(200) NOT NULL,
    duration INTEGER NOT NULL, -- en segundos
    file_url TEXT NOT NULL, -- URL del archivo HLS
    cover_art_url TEXT,
    lyrics TEXT,
    genre_id UUID REFERENCES genres(id),
    track_number INTEGER,
    status song_status NOT NULL DEFAULT 'draft',
    is_explicit BOOLEAN DEFAULT FALSE,
    release_date DATE,
    total_streams BIGINT DEFAULT 0,
    total_likes INTEGER DEFAULT 0,
    total_shares INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de playlists
CREATE TABLE IF NOT EXISTS playlists (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    cover_art_url TEXT,
    visibility playlist_visibility NOT NULL DEFAULT 'public',
    total_tracks INTEGER DEFAULT 0,
    total_duration INTEGER DEFAULT 0, -- en segundos
    total_followers INTEGER DEFAULT 0,
    is_featured BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de canciones en playlists
CREATE TABLE IF NOT EXISTS playlist_songs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    playlist_id UUID NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
    song_id UUID NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
    position INTEGER NOT NULL,
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(playlist_id, song_id)
);

-- Tabla de seguidores de artistas
CREATE TABLE IF NOT EXISTS artist_followers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    artist_id UUID NOT NULL REFERENCES artists(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    followed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(artist_id, user_id)
);

-- Tabla de seguidores de playlists
CREATE TABLE IF NOT EXISTS playlist_followers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    playlist_id UUID NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    followed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(playlist_id, user_id)
);

-- Tabla de likes de canciones
CREATE TABLE IF NOT EXISTS song_likes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    song_id UUID NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    liked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(song_id, user_id)
);

-- Tabla de historial de reproducción
CREATE TABLE IF NOT EXISTS play_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    song_id UUID NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
    played_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    duration_played INTEGER, -- duración reproducida en segundos
    completed BOOLEAN DEFAULT FALSE
);

-- Tabla de estadísticas de streaming
CREATE TABLE IF NOT EXISTS streaming_stats (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    song_id UUID NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    total_streams INTEGER DEFAULT 0,
    unique_listeners INTEGER DEFAULT 0,
    total_duration INTEGER DEFAULT 0, -- duración total reproducida
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(song_id, date)
);

-- Tabla de pagos
CREATE TABLE IF NOT EXISTS payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    payment_method VARCHAR(50) NOT NULL, -- 'stripe', 'paypal'
    payment_intent_id VARCHAR(255),
    status VARCHAR(50) NOT NULL, -- 'pending', 'completed', 'failed', 'refunded'
    subscription_period_start DATE,
    subscription_period_end DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices para optimización
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_artists_user_id ON artists(user_id);
CREATE INDEX IF NOT EXISTS idx_songs_artist_id ON songs(artist_id);
CREATE INDEX IF NOT EXISTS idx_songs_album_id ON songs(album_id);
CREATE INDEX IF NOT EXISTS idx_songs_status ON songs(status);
CREATE INDEX IF NOT EXISTS idx_playlists_user_id ON playlists(user_id);
CREATE INDEX IF NOT EXISTS idx_playlist_songs_playlist_id ON playlist_songs(playlist_id);
CREATE INDEX IF NOT EXISTS idx_playlist_songs_song_id ON playlist_songs(song_id);
CREATE INDEX IF NOT EXISTS idx_play_history_user_id ON play_history(user_id);
CREATE INDEX IF NOT EXISTS idx_play_history_song_id ON play_history(song_id);
CREATE INDEX IF NOT EXISTS idx_streaming_stats_song_id ON streaming_stats(song_id);
CREATE INDEX IF NOT EXISTS idx_streaming_stats_date ON streaming_stats(date);

-- Insertar géneros por defecto
INSERT INTO genres (name, description, color_hex) VALUES
('Rock', 'Música rock clásica y moderna', '#FF6B6B'),
('Pop', 'Música pop comercial', '#4ECDC4'),
('Jazz', 'Música jazz tradicional y contemporánea', '#45B7D1'),
('Blues', 'Música blues clásica', '#96CEB4'),
('Country', 'Música country tradicional', '#FFEAA7'),
('Folk', 'Música folk y acústica', '#DDA0DD'),
('Electronic', 'Música electrónica', '#98D8C8'),
('Classical', 'Música clásica', '#F7DC6F'),
('Reggae', 'Música reggae', '#BB8FCE'),
('Hip Hop', 'Música hip hop y rap', '#85C1E9')
ON CONFLICT (name) DO NOTHING;

-- Crear usuario admin por defecto
INSERT INTO users (email, username, password_hash, first_name, last_name, role, is_verified, is_active) VALUES
('admin@vintagemusic.com', 'admin', '$2b$10$rQZ8K9mN2pL3sT4uV5wX6yZ7aB8cD9eF0gH1iJ2kL3mN4oP5qR6sT7uV8wX9yZ', 'Admin', 'Vintage', 'admin', true, true)
ON CONFLICT (email) DO NOTHING;









