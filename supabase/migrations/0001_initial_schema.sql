-- =====================================================================
-- Vita — Sức khỏe & Tài chính
-- Migration 0001: Schema ban đầu + RLS
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- PROFILES (1-1 với auth.users)
-- ---------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  gender text not null default 'male' check (gender in ('male', 'female', 'other')),
  birth_date date,
  height_cm numeric(5, 1),
  weight_kg numeric(5, 1),
  activity_level text not null default 'sedentary'
    check (activity_level in ('sedentary', 'light', 'moderate', 'active', 'very_active')),
  goal text not null default 'maintain' check (goal in ('lose', 'maintain', 'gain')),
  daily_water_goal_ml integer not null default 2000
    check (daily_water_goal_ml between 500 and 8000),
  currency text not null default 'VND',
  locale text not null default 'vi',
  onboarding_completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Tự động tạo profile khi user đăng ký
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', split_part(new.email, '@', 1))
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- Cập nhật updated_at tự động
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_touch before update on public.profiles
for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------
-- WEIGHT LOGS — lịch sử cân nặng
-- ---------------------------------------------------------------------
create table public.weight_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  weight_kg numeric(5, 1) not null check (weight_kg between 20 and 400),
  logged_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- FOOD LOGS + FOOD ITEMS — calo nạp vào
-- ---------------------------------------------------------------------
create table public.food_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  meal_type text not null check (meal_type in ('breakfast', 'lunch', 'dinner', 'snack')),
  logged_at timestamptz not null default now(),
  note text,
  photo_url text,
  ai_raw_response jsonb,
  source text not null default 'ai' check (source in ('ai', 'manual'))
);

create table public.food_items (
  id uuid primary key default gen_random_uuid(),
  food_log_id uuid not null references public.food_logs(id) on delete cascade,
  name text not null,
  portion_g numeric(7, 1),
  calories integer not null default 0 check (calories >= 0),
  protein_g numeric(6, 1) default 0,
  carbs_g numeric(6, 1) default 0,
  fat_g numeric(6, 1) default 0
);

-- ---------------------------------------------------------------------
-- ACTIVITY LOGS — calo tiêu hao
-- source: health_connect (Android) / healthkit (iOS) / manual
-- ---------------------------------------------------------------------
create table public.activity_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  activity_type text not null,
  duration_min integer check (duration_min >= 0),
  calories_burned integer not null default 0 check (calories_burned >= 0),
  distance_km numeric(7, 2),
  source text not null default 'manual' check (source in ('manual', 'health_connect', 'healthkit')),
  logged_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- WATER — log nước + cài đặt nhắc nhở
-- ---------------------------------------------------------------------
create table public.water_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  amount_ml integer not null check (amount_ml between 1 and 3000),
  logged_at timestamptz not null default now()
);

create table public.water_reminder_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  enabled boolean not null default true,
  start_time time not null default '07:00',
  end_time time not null default '22:00',
  interval_min integer not null default 60 check (interval_min between 15 and 240),
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- MONEY — danh mục + giao dịch
-- user_id null = danh mục mặc định chung (không dùng, seed per-user)
-- ---------------------------------------------------------------------
create table public.transaction_categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  name text not null,
  icon text not null default 'category',
  color text not null default '#4CAF50',
  type text not null check (type in ('income', 'expense')),
  is_default boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  unique (user_id, name, type)
);

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null check (type in ('income', 'expense')),
  amount numeric(15, 2) not null check (amount > 0),
  category_id uuid references public.transaction_categories(id) on delete set null,
  note text,
  transaction_date date not null default current_date,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- SEED: danh mục mặc định cho user mới (kèm profile)
-- ---------------------------------------------------------------------
create or replace function public.handle_default_categories()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.transaction_categories (user_id, name, icon, color, type, is_default, sort_order) values
    (new.id, 'Ăn uống',   'restaurant',   '#F44336', 'expense', true, 1),
    (new.id, 'Đi lại',    'directions_car','#2196F3', 'expense', true, 2),
    (new.id, 'Mua sắm',   'shopping_bag', '#9C27B0', 'expense', true, 3),
    (new.id, 'Hóa đơn',   'receipt_long', '#FF9800', 'expense', true, 4),
    (new.id, 'Giải trí',  'sports_esports','#00BCD4', 'expense', true, 5),
    (new.id, 'Sức khỏe',  'favorite',     '#E91E63', 'expense', true, 6),
    (new.id, 'Giáo dục',  'school',       '#3F51B5', 'expense', true, 7),
    (new.id, 'Khác (chi)','more_horiz',   '#607D8B', 'expense', true, 8),
    (new.id, 'Lương',     'payments',     '#4CAF50', 'income',  true, 1),
    (new.id, 'Thưởng',    'card_giftcard','#8BC34A', 'income',  true, 2),
    (new.id, 'Đầu tư',    'trending_up',  '#009688', 'income',  true, 3),
    (new.id, 'Quà tặng',  'redeem',       '#CDDC39', 'income',  true, 4),
    (new.id, 'Khác (thu)','more_horiz',   '#795548', 'income',  true, 5)
  on conflict (user_id, name, type) do nothing;
  return new;
end;
$$;

create trigger on_profile_created
after insert on public.profiles
for each row execute function public.handle_default_categories();

-- ---------------------------------------------------------------------
-- STORAGE: bucket ảnh món ăn
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('food-photos', 'food-photos', true)
on conflict (id) do nothing;

create policy "food_photos_public_read"
on storage.objects for select
using (bucket_id = 'food-photos');

create policy "food_photos_auth_upload"
on storage.objects for insert to authenticated
with check (bucket_id = 'food-photos');

create policy "food_photos_owner_delete"
on storage.objects for delete to authenticated
using (bucket_id = 'food-photos' and owner = auth.uid());

-- ---------------------------------------------------------------------
-- ROW LEVEL SECURITY
-- ---------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.weight_logs enable row level security;
alter table public.food_logs enable row level security;
alter table public.food_items enable row level security;
alter table public.activity_logs enable row level security;
alter table public.water_logs enable row level security;
alter table public.water_reminder_settings enable row level security;
alter table public.transaction_categories enable row level security;
alter table public.transactions enable row level security;

-- profiles
create policy "profiles_insert_own" on public.profiles for insert with check (auth.uid() = id);
create policy "profiles_select_own" on public.profiles for select using (auth.uid() = id);
create policy "profiles_update_own" on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);

-- các bảng dữ liệu: user chỉ được thao tác trên dòng của mình
create policy "weight_logs_own" on public.weight_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "food_logs_own" on public.food_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "food_items_own" on public.food_items
  for all using (
    exists (select 1 from public.food_logs fl
            where fl.id = food_log_id and fl.user_id = auth.uid())
  ) with check (
    exists (select 1 from public.food_logs fl
            where fl.id = food_log_id and fl.user_id = auth.uid())
  );

create policy "activity_logs_own" on public.activity_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "water_logs_own" on public.water_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "water_reminder_own" on public.water_reminder_settings
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- danh mục: chỉ đọc/sửa danh mục của mình (không có danh mục chung null)
create policy "categories_own" on public.transaction_categories
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "transactions_own" on public.transactions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------
-- INDEXES
-- ---------------------------------------------------------------------
create index weight_logs_user_idx on public.weight_logs (user_id, logged_at desc);
create index food_logs_user_idx on public.food_logs (user_id, logged_at desc);
create index food_items_log_idx on public.food_items (food_log_id);
create index activity_logs_user_idx on public.activity_logs (user_id, logged_at desc);
create index water_logs_user_idx on public.water_logs (user_id, logged_at desc);
create index transactions_user_idx on public.transactions (user_id, transaction_date desc);
create index transactions_category_idx on public.transactions (category_id);
