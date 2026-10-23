-- 1. Create the buildings table
CREATE TABLE public.buildings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    address TEXT,
    total_units INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Add building_id to properties table
ALTER TABLE public.properties
ADD COLUMN building_id UUID REFERENCES public.buildings(id) ON DELETE CASCADE;

-- Note: For existing properties, you might want to create a "Default Building" 
-- and assign them to it, or you can just leave building_id as NULL temporarily.
-- Example to create a default building and assign all existing flats to it:
-- 
-- INSERT INTO public.buildings (id, name, total_units) 
-- VALUES ('00000000-0000-0000-0000-000000000000', 'Legacy Building', 0)
-- ON CONFLICT DO NOTHING;
-- 
-- UPDATE public.properties SET building_id = '00000000-0000-0000-0000-000000000000' WHERE building_id IS NULL;
