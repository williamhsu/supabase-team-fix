-- Simplified fix focusing just on resolving the ambiguous user_id reference
-- Run these commands in your Supabase SQL editor

-- 1. Check which tables have user_id columns (don't run this in production, just for understanding)
SELECT 
  table_name, 
  column_name
FROM 
  information_schema.columns 
WHERE 
  column_name = 'user_id' 
  AND table_schema = 'public';

-- 2. Create a view with properly qualified columns for team members
CREATE OR REPLACE VIEW team_members_with_api_keys AS 
SELECT 
  u.id AS user_id, -- explicitly name it to avoid confusion
  u.email, 
  u.created_at, 
  u.last_sign_in_at, 
  ur.role, 
  eak.id AS api_key_id, 
  eak.organization_name
FROM 
  auth.users u
  JOIN user_roles ur ON u.id = ur.user_id
  LEFT JOIN eventbrite_api_keys eak ON u.id = eak.user_id
WHERE 
  ur.role = 'employee';

-- 3. Make sure the view is accessible
ALTER TABLE team_members_with_api_keys ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow authenticated to read team_members_with_api_keys" 
ON team_members_with_api_keys 
FOR SELECT TO authenticated 
USING (true);

-- 4. Create a view for events related to the API keys
CREATE OR REPLACE VIEW team_api_key_events AS
SELECT 
  eak.id AS api_key_id,
  eak.user_id,
  e.event_id,
  e.name AS event_name,
  e.start_date,
  e.end_date,
  e.status
FROM 
  eventbrite_api_keys eak
  JOIN eventbrite_events e ON eak.id = e.api_key_id;

-- 5. Make the events view accessible
ALTER TABLE team_api_key_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow authenticated to read team_api_key_events" 
ON team_api_key_events 
FOR SELECT TO authenticated 
USING (true);

-- 6. Create a view for orders related to the events
CREATE OR REPLACE VIEW team_event_orders AS
SELECT 
  e.event_id,
  e.api_key_id,
  o.id AS order_id,
  o.paid_amount
FROM 
  team_api_key_events e
  JOIN eventbrite_orders o ON e.event_id = o.event_id;

-- 7. Make the orders view accessible
ALTER TABLE team_event_orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow authenticated to read team_event_orders" 
ON team_event_orders 
FOR SELECT TO authenticated 
USING (true);