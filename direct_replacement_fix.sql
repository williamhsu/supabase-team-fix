-- Direct replacement solution for the frontend error
-- This script replaces the user_details view being used by the frontend
-- without requiring any frontend code changes

-- First, drop the existing user_details view if it exists
DROP VIEW IF EXISTS user_details;

-- Create a new user_details view with properly qualified columns
CREATE OR REPLACE VIEW user_details AS 
SELECT 
  u.id, 
  u.email, 
  u.created_at, 
  u.raw_user_meta_data, 
  u.raw_app_meta_data,
  u.last_sign_in_at,
  ur.role,
  -- Explicitly cast and rename the user_id from user_roles to avoid ambiguity
  ur.user_id AS role_user_id 
FROM 
  auth.users u
  JOIN user_roles ur ON u.id = ur.user_id;

-- Grant proper permissions to the view
GRANT SELECT ON user_details TO authenticated;

-- If you want to check that the view works correctly:
-- SELECT * FROM user_details LIMIT 10;

-- If the error persists, the issue might be with a stored function or procedure
-- that's being called by the frontend. In that case, we would need to identify
-- and fix that function.

-- Alternative approach: Create a function that wraps the existing query
-- but properly qualifies all column references
CREATE OR REPLACE FUNCTION get_user_details()
RETURNS TABLE (
  id uuid,
  email text,
  created_at timestamptz,
  raw_user_meta_data jsonb,
  raw_app_meta_data jsonb,
  last_sign_in_at timestamptz,
  role text,
  eventbrite_api_keys jsonb
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    u.id,
    u.email,
    u.created_at,
    u.raw_user_meta_data,
    u.raw_app_meta_data,
    u.last_sign_in_at,
    ur.role,
    COALESCE(
      (
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
      ),
      '[]'::jsonb
    ) AS eventbrite_api_keys
  FROM 
    auth.users u
    JOIN user_roles ur ON u.id = ur.user_id
  WHERE 
    ur.role = 'employee';
END;
$$ LANGUAGE plpgsql;

-- Grant permission to execute the function
GRANT EXECUTE ON FUNCTION get_user_details() TO authenticated;