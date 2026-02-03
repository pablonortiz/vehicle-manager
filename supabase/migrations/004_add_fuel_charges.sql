-- Migration: Add fuel_charges table
-- Description: Adds fuel charges tracking system for vehicles

-- Create fuel_charges table
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

-- Create indexes for fuel_charges
CREATE INDEX IF NOT EXISTS idx_fuel_charges_vehicle ON fuel_charges (vehicle_id);
CREATE INDEX IF NOT EXISTS idx_fuel_charges_date ON fuel_charges (date);
CREATE INDEX IF NOT EXISTS idx_fuel_charges_vehicle_date ON fuel_charges (vehicle_id, date);

-- Enable Row Level Security
ALTER TABLE fuel_charges ENABLE ROW LEVEL SECURITY;

-- Create permissive policy (allows all operations)
CREATE POLICY "Allow all on fuel_charges" ON fuel_charges FOR ALL USING (true) WITH CHECK (true);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_fuel_charges_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for automatic updated_at
CREATE TRIGGER trigger_fuel_charges_updated_at
  BEFORE UPDATE ON fuel_charges
  FOR EACH ROW
  EXECUTE FUNCTION update_fuel_charges_updated_at();
