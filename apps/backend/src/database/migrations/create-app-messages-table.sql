-- Tabla para mensajes de aplicación (ej. banner de inicio)
CREATE TABLE IF NOT EXISTS app_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    type VARCHAR(50) NOT NULL DEFAULT 'HOME_BANNER',
    message TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_by UUID NULL REFERENCES users(id) ON DELETE SET NULL,
    published_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_app_messages_type_active ON app_messages(type, is_active);
CREATE INDEX IF NOT EXISTS idx_app_messages_published_at ON app_messages(published_at DESC);

-- Trigger para mantener updated_at
CREATE OR REPLACE FUNCTION update_app_messages_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_app_messages_updated_at
    BEFORE UPDATE ON app_messages
    FOR EACH ROW
    EXECUTE FUNCTION update_app_messages_updated_at();





