-- Run this in the Supabase SQL editor

-- 1) Ensure the table exists with a row for each auth user
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  email text,
  college text,
  major text,
  created_at timestamptz default now()
);

-- 2) Enable row level security
alter table public.profiles enable row level security;

-- 3) Allow users to read, insert, and update only their own profile row
create policy "Users can view own profile"
  on public.profiles
  for select
  using (auth.uid() = id);

create policy "Users can insert own profile"
  on public.profiles
  for insert
  with check (auth.uid() = id);

create policy "Users can update own profile"
  on public.profiles
  for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Optional: allow the service role to manage profiles if needed
-- create policy "Service role can manage all profiles"
--   on public.profiles
--   for all
--   using (auth.role() = 'service_role');
