-- 1. First, identify tables containing user_id column which might be involved in the join
-- This will help us understand the schema better
SELECT 
  table_name, 
  column_name
FROM 
  information_schema.columns 
WHERE 
  column_name = 'user_id' 
  AND table_schema = 'public';

-- 2. Create a view for user details with properly qualified columns
CREATE OR REPLACE VIEW team_members_view AS 
SELECT 
  u.id, 
  u.email, 
  u.created_at, 
  u.last_sign_in_at, 
  ur.role,
  ur.id as role_id
FROM 
  auth.users u 
  JOIN user_roles ur ON u.id = ur.user_id;

-- 3. Create a policy allowing access to the view
ALTER TABLE team_members_view ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow access to team_members_view" 
ON team_members_view FOR ALL TO authenticated USING (true);

-- 4. Create a function that handles the complex query with fully qualified columns
CREATE OR REPLACE FUNCTION get_team_members()
RETURNS TABLE (
  id uuid, 
  email text, 
  role text, 
  created_at timestamptz, 
  last_sign_in_at timestamptz, 
  api_keys jsonb
) AS $$
BEGIN
  RETURN QUERY 
  SELECT 
    u.id, 
    u.email, 
    ur.role, 
    u.created_at, 
    u.last_sign_in_at, 
    (
      SELECT jsonb_agg(row_to_json(a)) 
      FROM (
        SELECT 
          ak.id, 
          ak.organization_name, 
          (
            SELECT jsonb_agg(row_to_json(e)) 
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
                    SELECT o.id, o.paid_amount 
                    FROM eventbrite_orders o 
                    WHERE o.event_id = e.event_id
                  ) o
                ) AS eventbrite_orders 
              FROM eventbrite_events e 
              WHERE e.api_key_id = ak.id
            ) e
          ) AS eventbrite_events 
        FROM eventbrite_api_keys ak 
        WHERE ak.user_id = u.id
      ) a
    ) AS api_keys 
  FROM auth.users u 
  JOIN user_roles ur ON u.id = ur.user_id 
  WHERE ur.role = 'employee';
END;
$$ LANGUAGE plpgsql;

-- 5. Backup solution: Allow access to eventbrite_api_keys directly if needed
ALTER TABLE eventbrite_api_keys ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow authenticated to read eventbrite_api_keys" 
ON eventbrite_api_keys FOR SELECT TO authenticated USING (true);

-- 6. Backup solution: Create a simplified view to avoid the ambiguous join
CREATE OR REPLACE VIEW user_roles_view AS 
SELECT 
  ur.id AS role_id, 
  ur.user_id, 
  ur.role,
  u.email,
  u.created_at,
  u.last_sign_in_at
FROM 
  user_roles ur
  JOIN auth.users u ON ur.user_id = u.id;

ALTER TABLE user_roles_view ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow authenticated to read user_roles_view" 
ON user_roles_view FOR SELECT TO authenticated USING (true);

-- 7. Simplified fix that just focuses on the user_id ambiguity
CREATE OR REPLACE FUNCTION fix_ambiguous_user_id() RETURNS void AS $$
BEGIN
  -- Update the team page query with fully qualified user_id references
  EXECUTE '
  CREATE OR REPLACE VIEW team_members_with_keys AS
  SELECT 
    u.id, 
    u.email, 
    u.created_at, 
    u.last_sign_in_at, 
    ur.role,
    eak.id as api_key_id,
    eak.organization_name
  FROM 
    auth.users u
    JOIN user_roles ur ON u.id = ur.user_id
    LEFT JOIN eventbrite_api_keys eak ON u.id = eak.user_id
  WHERE 
    ur.role = ''employee''';
    
  EXECUTE 'ALTER TABLE team_members_with_keys ENABLE ROW LEVEL SECURITY';
  EXECUTE 'CREATE POLICY "Allow authenticated to read team_members_with_keys" ON team_members_with_keys FOR SELECT TO authenticated USING (true)';
END;
$$ LANGUAGE plpgsql;