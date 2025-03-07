-- Final solution - Minimal fix focused solely on resolving the ambiguous user_id column
-- This script is designed to be as simple as possible while fixing the issue

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

-- Set proper permissions
ALTER TABLE admin_team_view ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow authenticated users to view admin_team_view" 
ON admin_team_view FOR SELECT TO authenticated USING (true);

-- The following SQL can be run to check if this view resolves the ambiguity:
-- SELECT * FROM admin_team_view LIMIT 10;

-- To ensure this view works with any frontend code that expects the original data structure,
-- you may need to modify the frontend code to use this view instead of direct table joins.

-- Additionally, if you want to fix the API call without modifying frontend code,
-- you could create an API endpoint that uses this view and formats the data
-- to match the structure expected by the frontend.