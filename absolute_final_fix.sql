-- Absolute final fix for the user_id ambiguity error
-- This solution directly addresses the error seen in the frontend
-- "column reference \"user_id\" is ambiguous"

-- If user_details is a table (not a view), you'll need to create a backup first
-- CREATE TABLE user_details_backup AS SELECT * FROM user_details;

-- Drop the existing view or table if it exists
DROP VIEW IF EXISTS user_details CASCADE;

-- Create a new user_details view with properly qualified user_id reference
CREATE OR REPLACE VIEW user_details AS 
SELECT 
  u.id, 
  u.email, 
  u.created_at, 
  u.updated_at,
  u.last_sign_in_at,
  u.raw_user_meta_data,
  u.raw_app_meta_data,
  -- All other columns from auth.users you need
  ur.role,
  -- Important: Only reference the user_id from a single table or rename them
  u.id AS user_id  -- Use this pattern instead of exposing multiple user_id columns
FROM 
  auth.users u
  JOIN user_roles ur ON u.id = ur.user_id;

-- Grant proper permissions
GRANT SELECT ON user_details TO authenticated;

-- To fix the issue in the admin_team page specifically, we can also create
-- a function that the page can call directly:
CREATE OR REPLACE FUNCTION get_admin_team() 
RETURNS SETOF json 
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    jsonb_build_object(
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
            (
              SELECT jsonb_agg(row_to_json(ev))
              FROM (
                SELECT 
                  e.event_id, 
                  e.name, 
                  e.start_date, 
                  e.end_date, 
                  e.status,
                  (
                    SELECT jsonb_agg(row_to_json(o))
                    FROM (
                      SELECT 
                        o.id, 
                        o.paid_amount
                      FROM eventbrite_orders o
                      WHERE o.event_id = e.event_id
                    ) o
                  ) AS eventbrite_orders
                FROM eventbrite_events e
                WHERE e.api_key_id = eak.id
              ) ev
            ) AS eventbrite_events
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

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_admin_team() TO authenticated;

-- Important: If there are existing functions or stored procedures that use
-- user_details, they may need to be updated to work with the new view definition.

-- Finally, check if there's a stored procedure being called by the frontend:
-- SELECT routine_name, routine_type 
-- FROM information_schema.routines 
-- WHERE routine_schema = 'public'
-- AND (routine_definition LIKE '%user_details%' OR routine_name LIKE '%team%');