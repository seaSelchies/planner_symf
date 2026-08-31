-- Make weight_kg nullable (weight is now optional when adding a journal entry)
ALTER TABLE weight_logs ALTER COLUMN weight_kg DROP NOT NULL;

-- Add free-text notes field to weight_logs
ALTER TABLE weight_logs ADD COLUMN IF NOT EXISTS notes text;
