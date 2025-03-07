-- Simplest possible solution to fix the ambiguous user_id issue
-- This script provides just the essential fix with minimal changes

-- Option 1: Use a database function to handle the query with proper column qualification
CREATE OR REPLACE FUNCTION get_team_members()
RETURNS SETOF json
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    json_build_object(
      'id', u.id,
      'email', u.email,
      'created_at', u.created_at,
      'last_sign_in_at', u.last_sign_in_at,
      'role', ur.role,
      'api_keys', COALESCE((
        SELECT jsonb_agg(row_to_json(ak))
        FROM (
          SELECT
            eak.id,
            eak.organization_name,
            eak.created_at
          FROM eventbrite_api_keys eak
          WHERE eak.user_id = u.id
        ) ak
      ), '[]'::jsonb)
    )
  FROM
    auth.users u
    JOIN user_roles ur ON u.id = ur.user_id
  WHERE
    ur.role = 'employee';
END;
$$ LANGUAGE plpgsql;

-- Grant permission to execute the function
GRANT EXECUTE ON FUNCTION get_team_members() TO authenticated;

-- Option 2: Use a view with explicit column naming
CREATE OR REPLACE VIEW team_members_view AS 
SELECT 
  u.id,      -- No need to rename if used consistently
  u.email, 
  u.created_at, 
  u.last_sign_in_at,
  ur.role
FROM 
  auth.users u
  JOIN user_roles ur ON u.id = ur.user_id
WHERE 
  ur.role = 'employee';

-- Grant proper permissions
GRANT SELECT ON team_members_view TO authenticated;

-- Option 3: Direct fix in the API (Pseudocode for your API endpoint)
/*
In your API code, replace:

const { data, error } = await supabase
  .from('user_details')
  .select(`
    *,
    user_roles!inner (
      role
    ),
    eventbrite_api_keys (
      id,
      organization_name,
      ...
    )
  `)
  .eq('user_roles.role', 'employee');

With:

const { data, error } = await supabase.rpc('get_team_members');

OR:

const { data, error } = await supabase
  .from('team_members_view')
  .select('*');
  
OR with a manual join that properly qualifies columns:

const { data, error } = await supabase.rpc('get_team_members');
*/