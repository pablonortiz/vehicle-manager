-- =============================================
-- MIGRATION: Add hierarchical location system
-- Province -> City -> Lugar
-- =============================================

-- Tabla de ciudades
CREATE TABLE IF NOT EXISTS cities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  province_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  name_normalized TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(province_id, name_normalized)
);

-- Tabla de lugares (dentro de ciudades)
CREATE TABLE IF NOT EXISTS lugares (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  city_id UUID NOT NULL REFERENCES cities(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  name_normalized TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(city_id, name_normalized)
);

-- Agregar columnas a vehicles
ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS city_id UUID REFERENCES cities(id);
ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS lugar_id UUID REFERENCES lugares(id);
ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS lugar TEXT;

-- Índices para ciudades
CREATE INDEX IF NOT EXISTS idx_cities_province ON cities(province_id);
CREATE INDEX IF NOT EXISTS idx_cities_name_normalized ON cities(name_normalized);

-- Índices para lugares
CREATE INDEX IF NOT EXISTS idx_lugares_city ON lugares(city_id);
CREATE INDEX IF NOT EXISTS idx_lugares_name_normalized ON lugares(name_normalized);

-- Índices para vehicles
CREATE INDEX IF NOT EXISTS idx_vehicles_city_id ON vehicles(city_id);
CREATE INDEX IF NOT EXISTS idx_vehicles_lugar_id ON vehicles(lugar_id);

-- Triggers para updated_at en ciudades y lugares
CREATE TRIGGER update_cities_updated_at
  BEFORE UPDATE ON cities
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_lugares_updated_at
  BEFORE UPDATE ON lugares
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- RLS para ciudades y lugares
ALTER TABLE cities ENABLE ROW LEVEL SECURITY;
ALTER TABLE lugares ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all on cities" ON cities FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on lugares" ON lugares FOR ALL USING (true) WITH CHECK (true);

-- =============================================
-- MIGRACIÓN DE DATOS EXISTENTES
-- Crear ciudades desde los vehículos existentes
-- =============================================

-- Función para normalizar texto (remover acentos y convertir a minúsculas)
CREATE OR REPLACE FUNCTION normalize_text(input_text TEXT)
RETURNS TEXT AS $$
BEGIN
  RETURN LOWER(
    TRANSLATE(
      input_text,
      'ÁÉÍÓÚáéíóúÑñÜüÀÈÌÒÙàèìòùÂÊÎÔÛâêîôûÄËÏÖäëïö',
      'AEIOUaeiouNnUuAEIOUaeiouAEIOUaeiouAEIOaeio'
    )
  );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Crear ciudades desde vehículos existentes
INSERT INTO cities (province_id, name, name_normalized)
SELECT DISTINCT
  province_id,
  city,
  normalize_text(city)
FROM vehicles
WHERE city IS NOT NULL AND city != ''
ON CONFLICT (province_id, name_normalized) DO NOTHING;

-- Actualizar vehicles con city_id
UPDATE vehicles v
SET city_id = c.id
FROM cities c
WHERE v.province_id = c.province_id
  AND normalize_text(v.city) = c.name_normalized
  AND v.city_id IS NULL;
