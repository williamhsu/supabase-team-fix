-- Fix for the ambiguous relationship issue between user_details and user_roles
-- This solution addresses the PGRST201 error related to multiple relationships

-- Step 1: Examine the structure of the existing tables and views
-- This will help us understand the current relationships
-- SELECT * FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('user_details', 'user_roles');
-- SELECT * FROM information_schema.columns WHERE table_schema = 'public' AND table_name IN ('user_details', 'user_roles');
-- SELECT * FROM information_schema.referential_constraints WHERE constraint_schema = 'public';

-- Step 2: Drop the existing user_details view
DROP VIEW IF EXISTS user_details CASCADE;

-- Step 3: Create a new user_details view with clear relationship definitions
-- Important: Only include one column that could be related to user_roles.user_id
CREATE OR REPLACE VIEW user_details AS 
SELECT 
  u.id,  -- This will be the only column that relates to user_roles.user_id
  u.email, 
  u.created_at,
  u.last_sign_in_at,
  u.raw_user_meta_data,
  u.raw_app_meta_data,
  -- DO NOT include u.id AS user_id here as it creates ambiguity
  -- Only include role, not the user_id from user_roles
  ur.role
FROM 
  auth.users u
  JOIN user_roles ur ON u.id = ur.user_id;

-- Step 4: Set permissions for the view
GRANT SELECT ON user_details TO authenticated;

-- Step 5: Create an RPC function that returns the data in the expected format
-- This avoids the relationship issues entirely by using a function
CREATE OR REPLACE FUNCTION get_team_data()
RETURNS TABLE (
  id uuid,
  email text,
  created_at timestamptz,
  last_sign_in_at timestamptz,
  raw_user_meta_data jsonb,
  raw_app_meta_data jsonb,
  role text,
  api_keys jsonb
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    u.id,
    u.email,
    u.created_at,
    u.last_sign_in_at,
    u.raw_user_meta_data,
    u.raw_app_meta_data,
    ur.role,
    COALESCE(
      (
        SELECT jsonb_agg(row_to_json(ak))
        FROM (
          SELECT 
            eak.id, 
            eak.organization_name,
            eak.created_at,
            (
              SELECT jsonb_agg(row_to_json(ev))
              FROM (
                SELECT 
                  e.event_id, 
                  e.name, 
                  e.start_date, 
                  e.end_date, 
                  e.status
                FROM eventbrite_events e
                WHERE e.api_key_id = eak.id
              ) ev
            ) AS eventbrite_events
          FROM eventbrite_api_keys eak
          WHERE eak.user_id = u.id
        ) ak
      ),
      '[]'::jsonb
    ) AS api_keys
  FROM 
    auth.users u
    JOIN user_roles ur ON u.id = ur.user_id
  WHERE 
    ur.role = 'employee';
END;
$$ LANGUAGE plpgsql;

-- Grant permission to execute the function
GRANT EXECUTE ON FUNCTION get_team_data() TO authenticated;

-- Step 6 (Frontend change): If possible, modify the frontend to use the function instead
-- Original code likely uses something like:
-- const { data, error } = await supabase
--   .from('user_details')
--   .select(`
--     *,
--     user_roles(role),
--     eventbrite_api_keys(...)
--   `)
--   .eq('user_roles.role', 'employee');

-- New code would use:
-- const { data, error } = await supabase.rpc('get_team_data');

-- If you cannot modify the frontend, you can try creating a view that exactly matches
-- what the frontend expects, but without the ambiguous relationships
CREATE OR REPLACE VIEW frontend_team_data AS
SELECT
  u.id,
  u.email,
  u.created_at,
  u.last_sign_in_at,
  u.raw_user_meta_data,
  u.raw_app_meta_data,
  ur.role
FROM
  auth.users u
  JOIN user_roles ur ON u.id = ur.user_id
WHERE
  ur.role = 'employee';

GRANT SELECT ON frontend_team_data TO authenticated;