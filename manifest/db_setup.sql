-- 1. TABLA DE PERFILES DE USUARIO
create table public.profiles (
  id uuid references auth.users on delete cascade primary key,
  updated_at timestamp with time zone,
  full_name text,
  subscription_tier text default 'free' check (subscription_tier in ('free', 'pro'))
);

-- Habilitar RLS para seguridad de perfiles
alter table public.profiles enable row level security;

create policy "Users can view their own profile." on public.profiles
  for select using (auth.uid() = id);

create policy "Users can update their own profile." on public.profiles
  for update using (auth.uid() = id);


-- Trigger para crear el perfil automáticamente al registrarse en Auth
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name, subscription_tier)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', 'Usuario de Manifest'), 'free');
  return new;
end;
$$ language plpgsql security definer;

create or replace trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();


-- 2. TABLA DE METAS (GOALS)
create table public.goals (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade not null,
  title text not null,
  description text,
  progress integer default 0 check (progress >= 0 and progress <= 100),
  duration_days integer default 90,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Habilitar RLS para seguridad de metas
alter table public.goals enable row level security;

create policy "Users can view their own goals." on public.goals
  for select using (auth.uid() = user_id);

create policy "Users can insert their own goals." on public.goals
  for insert with check (auth.uid() = user_id);

create policy "Users can update their own goals." on public.goals
  for update using (auth.uid() = user_id);

create policy "Users can delete their own goals." on public.goals
  for delete using (auth.uid() = user_id);


-- 3. TABLA DE DIARIO DE GRATITUD (GRATITUDE_ENTRIES)
create table public.gratitude_entries (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade not null,
  text text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Habilitar RLS para seguridad de diario de gratitud
alter table public.gratitude_entries enable row level security;

create policy "Users can view their own gratitude entries." on public.gratitude_entries
  for select using (auth.uid() = user_id);

create policy "Users can insert their own gratitude entries." on public.gratitude_entries
  for insert with check (auth.uid() = user_id);

create policy "Users can delete their own gratitude entries." on public.gratitude_entries
  for delete using (auth.uid() = user_id);


-- 4. TABLA DE HISTORIAL DE CHATS (CHAT_MESSAGES)
create table public.chat_messages (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade not null,
  sender text not null check (sender in ('ai', 'user')),
  text text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Habilitar RLS para seguridad de chat
alter table public.chat_messages enable row level security;

create policy "Users can view their own chat messages." on public.chat_messages
  for select using (auth.uid() = user_id);

create policy "Users can insert their own chat messages." on public.chat_messages
  for insert with check (auth.uid() = user_id);
