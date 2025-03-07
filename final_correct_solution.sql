-- Final corrected solution - Fixed to not use RLS on views
-- PostgreSQL does not support enabling RLS directly on views

-- Create a view that properly qualifies the user_id column
CREATE OR REPLACE VIEW admin_team_view AS 
SELECT 
  u.id AS user_id,  -- Explicitly named to avoid ambiguity
  u.email, 
  u.created_at, 
  u.last_sign_in_at,
  u.raw_user_meta_data,
  u.raw_app_meta_data, 
  ur.role,
  ur.user_id AS role_user_id  -- Explicitly include this for complete clarity
FROM 
  auth.users u
  JOIN user_roles ur ON u.id = ur.user_id
WHERE 
  ur.role = 'employee';

-- Grant proper permissions to the view (instead of using RLS)
GRANT SELECT ON admin_team_view TO authenticated;

-- Create a view for events associated with team members
CREATE OR REPLACE VIEW admin_team_events AS
SELECT
  u.id AS user_id,
  u.email,
  u.created_at,
  ur.role,
  eak.id AS api_key_id,
  eak.organization_name,
  e.event_id,
  e.name AS event_name,
  e.start_date,
  e.end_date,
  e.status
FROM
  auth.users u
  JOIN user_roles ur ON u.id = ur.user_id
  LEFT JOIN eventbrite_api_keys eak ON u.id = eak.user_id
  LEFT JOIN eventbrite_events e ON eak.id = e.api_key_id
WHERE
  ur.role = 'employee';

-- Grant proper permissions
GRANT SELECT ON admin_team_events TO authenticated;

-- Create a function that returns team members with api keys
-- Using a function here to handle permissions properly
CREATE OR REPLACE FUNCTION get_team_members()
RETURNS TABLE (
  user_id uuid,
  email text,
  created_at timestamptz,
  last_sign_in_at timestamptz,
  role text,
  api_keys jsonb
) SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    u.id AS user_id,
    u.email,
    u.created_at,
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
                  e.status
                FROM eventbrite_events e
                WHERE e.api_key_id = eak.id
              ) ev
            ) AS events
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
GRANT EXECUTE ON FUNCTION get_team_members() TO authenticated;

-- Usage example: SELECT * FROM get_team_members();