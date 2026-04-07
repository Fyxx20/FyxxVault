-- Return total database size in bytes for admin usage dashboards.
-- SECURITY DEFINER allows service_role to call it without broad SQL execution.
CREATE OR REPLACE FUNCTION public.admin_db_size_bytes()
RETURNS BIGINT
LANGUAGE SQL
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
  SELECT pg_database_size(current_database())::BIGINT;
$$;

REVOKE ALL ON FUNCTION public.admin_db_size_bytes() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_db_size_bytes() FROM anon;
REVOKE ALL ON FUNCTION public.admin_db_size_bytes() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_db_size_bytes() TO service_role;
