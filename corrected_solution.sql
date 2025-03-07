-- Corrected solution for the ambiguous user_id issue
-- Fixed: Removed reference to non-existent ur.id column

-- First, let's check the actual structure of the user_roles table
-- You can run this to see the columns of user_roles:
-- SELECT column_name FROM information_schema.columns WHERE table_name = 'user_roles' AND table_schema = 'public';

-- Create a view with fully qualified columns (without referencing ur.id since it doesn't exist)
CREATE OR REPLACE VIEW admin_team_members AS 
SELECT 
  u.id AS user_id,  -- Renamed to be explicit
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

-- Create a view for events associated with API keys
CREATE OR REPLACE VIEW admin_team_events AS
SELECT
  atak.user_id,
  atak.api_key_id,
  e.event_id,
  e.name AS event_name,
  e.start_date,
  e.end_date,
  e.status
FROM
  admin_team_api_keys atak
  JOIN eventbrite_events e ON atak.api_key_id = e.api_key_id;

-- Set proper permissions
ALTER TABLE admin_team_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow authenticated users to view team events" 
ON admin_team_events FOR SELECT TO authenticated USING (true);

-- Create a view for orders associated with events
CREATE OR REPLACE VIEW admin_team_orders AS
SELECT
  ate.user_id,
  ate.api_key_id,
  ate.event_id,
  o.id AS order_id,
  o.paid_amount
FROM
  admin_team_events ate
  JOIN eventbrite_orders o ON ate.event_id = o.event_id;

-- Set proper permissions
ALTER TABLE admin_team_orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow authenticated users to view team orders" 
ON admin_team_orders FOR SELECT TO authenticated USING (true);