-- Immediate solution for the ambiguous user_id issue
-- This is a minimal fix that just addresses the immediate problem

-- Create a view with the most basic information needed with fully qualified columns
CREATE OR REPLACE VIEW admin_team_members AS 
SELECT 
  u.id AS user_id,  -- Renamed to be explicit
  u.email, 
  u.created_at, 
  u.last_sign_in_at,
  u.raw_user_meta_data,
  u.raw_app_meta_data, 
  ur.role,
  ur.id AS role_id
FROM 
  auth.users u
  JOIN user_roles ur ON u.id = ur.user_id
WHERE 
  ur.role = 'employee';

-- Set proper permissions
ALTER TABLE admin_team_members ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow authenticated users to view team members" 
ON admin_team_members FOR SELECT TO authenticated USING (true);

-- Connect API keys to users without ambiguity
CREATE OR REPLACE VIEW admin_team_api_keys AS
SELECT
  atm.user_id,
  eak.id AS api_key_id,
  eak.organization_name
FROM
  admin_team_members atm
  LEFT JOIN eventbrite_api_keys eak ON atm.user_id = eak.user_id;

-- Set proper permissions
ALTER TABLE admin_team_api_keys ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow authenticated users to view team API keys" 
ON admin_team_api_keys FOR SELECT TO authenticated USING (true);

-- Note: After implementing these views, modify the frontend code to use them instead of
-- the direct table joins that are causing the ambiguous column reference error.