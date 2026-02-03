-- =============================================
-- SCHEMA PARA GESTOR DE VEHICULOS
-- Ejecutar este SQL en el SQL Editor de Supabase
-- =============================================

-- Tabla de ciudades (sistema jerárquico de ubicación)
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

-- Tabla de vehículos
CREATE TABLE IF NOT EXISTS vehicles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plate TEXT NOT NULL UNIQUE,
  type INTEGER NOT NULL,
  brand TEXT NOT NULL,
  model TEXT NOT NULL,
  year INTEGER NOT NULL,
  color BIGINT NOT NULL,  -- BIGINT para soportar colores de Flutter (>2B)
  km INTEGER NOT NULL DEFAULT 0,
  vtv_expiry TIMESTAMPTZ,
  insurance_company TEXT,
  insurance_expiry TIMESTAMPTZ,
  fuel_type INTEGER NOT NULL,
  status INTEGER NOT NULL DEFAULT 0,
  province_id INTEGER NOT NULL,
  city TEXT NOT NULL,
  city_id UUID REFERENCES cities(id),
  lugar_id UUID REFERENCES lugares(id),
  lugar TEXT,
  responsible_name TEXT NOT NULL,
  responsible_phone TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tabla de historial de cambios
CREATE TABLE IF NOT EXISTS vehicle_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  field TEXT NOT NULL,
  old_value TEXT NOT NULL,
  new_value TEXT NOT NULL,
  changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tabla de mantenimientos
CREATE TABLE IF NOT EXISTS maintenances (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  date TIMESTAMPTZ NOT NULL,
  detail TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tabla de facturas de mantenimiento (imagenes o PDFs en Cloudinary)
CREATE TABLE IF NOT EXISTS maintenance_invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  maintenance_id UUID NOT NULL REFERENCES maintenances(id) ON DELETE CASCADE,
  cloudinary_url TEXT NOT NULL,
  cloudinary_public_id TEXT NOT NULL,
  file_type INTEGER NOT NULL DEFAULT 0, -- 0: image, 1: pdf
  file_name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tabla de notas del vehículo
CREATE TABLE IF NOT EXISTS vehicle_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  detail TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tabla de fotos de notas
CREATE TABLE IF NOT EXISTS note_photos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  note_id UUID NOT NULL REFERENCES vehicle_notes(id) ON DELETE CASCADE,
  cloudinary_url TEXT NOT NULL,
  cloudinary_public_id TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tabla de fotos del vehículo (galería)
CREATE TABLE IF NOT EXISTS vehicle_photos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  cloudinary_url TEXT NOT NULL,
  cloudinary_public_id TEXT NOT NULL,
  is_primary BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tabla de fotos de documentos (cédula verde, cédula azul, título)
CREATE TABLE IF NOT EXISTS document_photos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  document_type INTEGER NOT NULL, -- 0: cédula verde, 1: cédula azul, 2: título
  cloudinary_url TEXT NOT NULL,
  cloudinary_public_id TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tabla de cargas de combustible
CREATE TABLE IF NOT EXISTS fuel_charges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  date TIMESTAMPTZ NOT NULL,
  liters DECIMAL(10,2) NOT NULL,
  price DECIMAL(12,2) NOT NULL,
  price_per_liter DECIMAL(10,2),
  odometer INTEGER,
  receipt_photo_url TEXT,
  receipt_photo_public_id TEXT,
  display_photo_url TEXT,
  display_photo_public_id TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para mejorar rendimiento
CREATE INDEX IF NOT EXISTS idx_vehicles_plate ON vehicles(plate);
CREATE INDEX IF NOT EXISTS idx_vehicles_province ON vehicles(province_id);
CREATE INDEX IF NOT EXISTS idx_vehicles_status ON vehicles(status);
CREATE INDEX IF NOT EXISTS idx_vehicles_city_id ON vehicles(city_id);
CREATE INDEX IF NOT EXISTS idx_vehicles_lugar_id ON vehicles(lugar_id);
CREATE INDEX IF NOT EXISTS idx_history_vehicle ON vehicle_history(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_maintenances_vehicle ON maintenances(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_notes_vehicle ON vehicle_notes(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_photos_vehicle ON vehicle_photos(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_document_photos_vehicle ON document_photos(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_fuel_charges_vehicle ON fuel_charges(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_fuel_charges_date ON fuel_charges(date);
CREATE INDEX IF NOT EXISTS idx_fuel_charges_vehicle_date ON fuel_charges(vehicle_id, date);

-- Índices para ciudades y lugares
CREATE INDEX IF NOT EXISTS idx_cities_province ON cities(province_id);
CREATE INDEX IF NOT EXISTS idx_cities_name_normalized ON cities(name_normalized);
CREATE INDEX IF NOT EXISTS idx_lugares_city ON lugares(city_id);
CREATE INDEX IF NOT EXISTS idx_lugares_name_normalized ON lugares(name_normalized);

-- Trigger para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_vehicles_updated_at
  BEFORE UPDATE ON vehicles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_maintenances_updated_at
  BEFORE UPDATE ON maintenances
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_notes_updated_at
  BEFORE UPDATE ON vehicle_notes
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_cities_updated_at
  BEFORE UPDATE ON cities
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_lugares_updated_at
  BEFORE UPDATE ON lugares
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_fuel_charges_updated_at
  BEFORE UPDATE ON fuel_charges
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- =============================================
-- POLÍTICAS RLS (Row Level Security)
-- Como es una app personal, permitimos todo
-- =============================================

ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicle_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenances ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicle_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE note_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicle_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE document_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE cities ENABLE ROW LEVEL SECURITY;
ALTER TABLE lugares ENABLE ROW LEVEL SECURITY;
ALTER TABLE fuel_charges ENABLE ROW LEVEL SECURITY;

-- Políticas permisivas (app personal, sin auth)
CREATE POLICY "Allow all on vehicles" ON vehicles FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on vehicle_history" ON vehicle_history FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on maintenances" ON maintenances FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on maintenance_invoices" ON maintenance_invoices FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on vehicle_notes" ON vehicle_notes FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on note_photos" ON note_photos FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on vehicle_photos" ON vehicle_photos FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on document_photos" ON document_photos FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on cities" ON cities FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on lugares" ON lugares FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on fuel_charges" ON fuel_charges FOR ALL USING (true) WITH CHECK (true);
