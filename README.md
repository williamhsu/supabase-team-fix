# Supabase Team Page Fix

This repository contains SQL scripts to fix the issue with the admin team page at https://import.hackerx.org/admin/team. The error is:

```
Error fetching team members:
Object
code: "42702"
details: "It could refer to either a PL/pgSQL variable or a table column."
hint: null
message: "column reference \"user_id\" is ambiguous"
```

## The Problem

The error occurs because multiple tables in a join query have a column named `user_id`, and the SQL query doesn't specify which table's column to use, resulting in an ambiguous column reference.

## The Solution

The fix involves creating views and functions that properly qualify all column references. Several approaches are included in the SQL file:

1. Creating a `team_members_view` with properly qualified columns
2. Adding a function `get_team_members()` that handles the complex join query with fully qualified columns
3. Setting up proper Row Level Security (RLS) policies for the views
4. Creating simplified views to avoid ambiguous joins

## How to Use

Connect to your Supabase database and run the SQL commands in the provided file. You may need to adjust some table or column names based on your specific schema.