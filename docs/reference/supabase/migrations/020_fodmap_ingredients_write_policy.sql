-- Migration 020: Allow authenticated users to insert/update/delete fodmap_ingredients
-- Needed for the Ingredients management screen in the app.

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'fodmap_ingredients' AND policyname = 'Authenticated users can insert ingredients') THEN
    CREATE POLICY "Authenticated users can insert ingredients"
      ON public.fodmap_ingredients FOR INSERT
      TO authenticated
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'fodmap_ingredients' AND policyname = 'Authenticated users can update ingredients') THEN
    CREATE POLICY "Authenticated users can update ingredients"
      ON public.fodmap_ingredients FOR UPDATE
      TO authenticated
      USING (true)
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'fodmap_ingredients' AND policyname = 'Authenticated users can delete ingredients') THEN
    CREATE POLICY "Authenticated users can delete ingredients"
      ON public.fodmap_ingredients FOR DELETE
      TO authenticated
      USING (true);
  END IF;
END $$;
