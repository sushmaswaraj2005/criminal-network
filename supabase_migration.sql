-- =============================================================================
-- SENTINEL // NET-INTEL - SUPABASE POSTGRESQL MIGRATION
-- Project: AI Powered Criminal Network Analysis System
-- Target: Supabase SQL Editor
-- Security Model: RBAC (LEAD_ADMIN / INVESTIGATOR) + Cryptographic RLS
-- =============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. ENUM TYPES
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
    CREATE TYPE public.user_role AS ENUM ('LEAD_ADMIN', 'INVESTIGATOR');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'account_status') THEN
    CREATE TYPE public.account_status AS ENUM ('ACTIVE', 'SUSPENDED', 'PENDING_ACTIVATION');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'request_status') THEN
    CREATE TYPE public.request_status AS ENUM ('PENDING', 'APPROVED', 'REJECTED');
  END IF;
END $$;

-- 3. PROFILES TABLE (Extends Supabase auth.users without duplicating passwords)
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL UNIQUE,
  full_name TEXT NOT NULL,
  badge TEXT NOT NULL DEFAULT '#UNASSIGNED',
  role public.user_role NOT NULL DEFAULT 'INVESTIGATOR',
  agency TEXT NOT NULL DEFAULT 'Special Taskforce',
  division TEXT DEFAULT 'Field Operations',
  clearance_level TEXT NOT NULL DEFAULT 'LEVEL-2 INVESTIGATOR',
  account_status public.account_status NOT NULL DEFAULT 'ACTIVE',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 4. ACCESS REQUESTS TABLE (Strictly applicant metadata - NO PASSWORDS)
CREATE TABLE IF NOT EXISTS public.access_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  agency TEXT NOT NULL,
  badge TEXT NOT NULL,
  role TEXT NOT NULL,
  justification TEXT NOT NULL,
  status public.request_status NOT NULL DEFAULT 'PENDING',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  reviewed_at TIMESTAMPTZ,
  reviewed_by TEXT,
  reviewed_by_id UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

-- Unique index preventing duplicate pending requests from same email
CREATE UNIQUE INDEX IF NOT EXISTS idx_access_requests_pending_email 
  ON public.access_requests(lower(email)) 
  WHERE status = 'PENDING';

-- 5. ROW-LEVEL SECURITY ENABLING
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.access_requests ENABLE ROW LEVEL SECURITY;

-- 6. SECURITY DEFINER HELPER: IS LEAD ADMIN
CREATE OR REPLACE FUNCTION public.is_lead_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
      AND role = 'LEAD_ADMIN'
      AND account_status = 'ACTIVE'
  );
$$;

-- 7. RLS POLICIES FOR PROFILES
DROP POLICY IF EXISTS "profiles_select_policy" ON public.profiles;
CREATE POLICY "profiles_select_policy"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (
    id = auth.uid() OR public.is_lead_admin()
  );

DROP POLICY IF EXISTS "profiles_update_policy" ON public.profiles;
CREATE POLICY "profiles_update_policy"
  ON public.profiles
  FOR UPDATE
  TO authenticated
  USING (
    id = auth.uid() OR public.is_lead_admin()
  )
  WITH CHECK (
    (id = auth.uid() AND role = (SELECT role FROM public.profiles WHERE id = auth.uid()))
    OR public.is_lead_admin()
  );

DROP POLICY IF EXISTS "profiles_insert_policy" ON public.profiles;
CREATE POLICY "profiles_insert_policy"
  ON public.profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_lead_admin() OR id = auth.uid()
  );

-- 8. RLS POLICIES FOR ACCESS REQUESTS
-- Public insert: anyone can submit request, but MUST have status = 'PENDING'
DROP POLICY IF EXISTS "access_requests_public_insert" ON public.access_requests;
CREATE POLICY "access_requests_public_insert"
  ON public.access_requests
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (
    status = 'PENDING' 
    AND reviewed_at IS NULL 
    AND reviewed_by IS NULL
    AND reviewed_by_id IS NULL
  );

-- Select: LEAD_ADMIN can see all requests; applicants can check their own request
DROP POLICY IF EXISTS "access_requests_select_policy" ON public.access_requests;
CREATE POLICY "access_requests_select_policy"
  ON public.access_requests
  FOR SELECT
  TO authenticated
  USING (
    public.is_lead_admin()
    OR email = (SELECT email FROM auth.users WHERE id = auth.uid())
  );

-- Update: STRICTLY restricted to LEAD_ADMIN (approvals and rejections)
DROP POLICY IF EXISTS "access_requests_update_admin_only" ON public.access_requests;
CREATE POLICY "access_requests_update_admin_only"
  ON public.access_requests
  FOR UPDATE
  TO authenticated
  USING (public.is_lead_admin())
  WITH CHECK (public.is_lead_admin());

-- Delete: STRICTLY restricted to LEAD_ADMIN
DROP POLICY IF EXISTS "access_requests_delete_admin_only" ON public.access_requests;
CREATE POLICY "access_requests_delete_admin_only"
  ON public.access_requests
  FOR DELETE
  TO authenticated
  USING (public.is_lead_admin());

-- 9. TRIGGER: AUTOMATIC PROFILE GENERATION ON USER SIGNUP / INVITATION ACCEPT
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  req_record RECORD;
BEGIN
  -- 1. Check if this is the designated Lead Admin email
  IF lower(new.email) = 'velurusushma45@gmail.com' THEN
    INSERT INTO public.profiles (
      id, email, full_name, badge, role, agency, division, clearance_level, account_status
    ) VALUES (
      new.id,
      new.email,
      'Investigator V. Sushma',
      '#889-INTEL',
      'LEAD_ADMIN',
      'Special Investigation Taskforce / Cyber Defense',
      'Lead Investigation Command',
      'LEVEL-4 LEAD INVESTIGATOR',
      'ACTIVE'
    )
    ON CONFLICT (id) DO UPDATE SET
      role = 'LEAD_ADMIN',
      clearance_level = 'LEVEL-4 LEAD INVESTIGATOR',
      account_status = 'ACTIVE';

    RETURN new;
  END IF;

  -- 2. Check if user email corresponds to an approved access request
  SELECT * INTO req_record 
  FROM public.access_requests 
  WHERE lower(email) = lower(new.email) AND status = 'APPROVED'
  ORDER BY created_at DESC 
  LIMIT 1;

  IF req_record IS NOT NULL THEN
    INSERT INTO public.profiles (
      id, email, full_name, badge, role, agency, division, clearance_level, account_status
    ) VALUES (
      new.id,
      new.email,
      req_record.name,
      req_record.badge,
      'INVESTIGATOR',
      req_record.agency,
      'Field Operations',
      'LEVEL-2 INVESTIGATOR',
      'ACTIVE'
    )
    ON CONFLICT (id) DO NOTHING;
  ELSE
    -- 3. Standard fallback investigator profile
    INSERT INTO public.profiles (
      id, email, full_name, badge, role, agency, division, clearance_level, account_status
    ) VALUES (
      new.id,
      new.email,
      COALESCE(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
      COALESCE(new.raw_user_meta_data->>'badge', '#OP-' || floor(random() * 900 + 100)::text),
      'INVESTIGATOR',
      'Investigative Division',
      'General Field Intel',
      'LEVEL-2 INVESTIGATOR',
      'ACTIVE'
    )
    ON CONFLICT (id) DO NOTHING;
  END IF;

  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 10. ENABLE REALTIME ON access_requests
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'access_requests'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.access_requests;
  END IF;
END $$;
