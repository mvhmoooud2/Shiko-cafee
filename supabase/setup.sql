-- =====================================================================
--  قهوة شيكو — إعداد قاعدة البيانات على Supabase (شغّله مرة واحدة)
-- =====================================================================
--  الطريقة:
--   1) افتح مشروعك على Supabase → من القائمة الجانبية "SQL Editor" → "New query"
--   2) عدّل الإيميل في السطر اللي عليه علامة ✏️ تحت (إيميل العميل اللي هيدخل بيه)
--   3) انسخ الملف كله والصقه واضغط Run
--
--  الملف آمن لو اتشغّل أكتر من مرة (مش هيمسح بيانات موجودة).
--  ملحوظة: المنيو نفسه (الأقسام والأصناف) بيتضاف من لوحة التحكم بزرار
--  "استيراد المنيو الحالي" — مش من هنا — عشان الملف يفضل صغير وسهل النسخ.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1) الأدمنز: الإيميلات المسموح لها تدخل لوحة التحكم
-- ---------------------------------------------------------------------
create table if not exists public.admins (
  email      text primary key,
  created_at timestamptz not null default now()
);

-- ✏️ غيّر الإيميل ده لإيميل العميل (نفس الإيميل اللي هتعمله من Authentication → Users)
insert into public.admins (email) values ('mahmoudmohamedd91@gmail.com')
on conflict (email) do nothing;

-- محدش يقدر يقرأ جدول الأدمنز مباشرة (بيتقرأ بس من جوه دالة is_admin)
alter table public.admins enable row level security;

-- الدالة اللي بتحدد: هل المستخدم اللي عامل تسجيل دخول دلوقتي أدمن؟
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.admins
    where lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;

grant execute on function public.is_admin() to anon, authenticated;


-- ---------------------------------------------------------------------
-- 2) الجداول
-- ---------------------------------------------------------------------
create table if not exists public.categories (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  icon       text not null default '',
  sort_order integer not null default 0,
  is_active  boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.items (
  id           uuid primary key default gen_random_uuid(),
  category_id  uuid not null references public.categories(id) on delete cascade,
  name         text not null,
  description  text not null default '',
  price        numeric(10,2),   -- سعر واحد
  price_s      numeric(10,2),   -- حجم S
  price_m      numeric(10,2),   -- حجم M
  price_l      numeric(10,2),   -- حجم L
  image_url    text,             -- الصورة الكبيرة
  thumb_url    text,             -- صورة صغيرة للقائمة
  sort_order   integer not null default 0,
  is_available boolean not null default true,
  created_at   timestamptz not null default now()
);

alter table public.items add column if not exists thumb_url text;
create index if not exists items_category_idx on public.items (category_id, sort_order);

-- بيانات المحل: صف واحد بس (id = 1)
create table if not exists public.settings (
  id         integer primary key default 1 check (id = 1),
  shop_name  text not null default '',
  tagline    text not null default '',
  address    text not null default '',
  whatsapp   text not null default '',
  instagram1 text not null default '',
  instagram2 text not null default '',
  maps_url   text not null default '',
  logo_url   text,
  updated_at timestamptz not null default now()
);


-- ---------------------------------------------------------------------
-- 3) الصلاحيات (Row Level Security)
--    الكل يقدر يقرأ المنيو  /  الأدمن بس يقدر يضيف ويعدل ويحذف
-- ---------------------------------------------------------------------
alter table public.categories enable row level security;
alter table public.items      enable row level security;
alter table public.settings   enable row level security;

drop policy if exists "public read categories" on public.categories;
drop policy if exists "admin write categories" on public.categories;
create policy "public read categories" on public.categories for select using (true);
create policy "admin write categories" on public.categories for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

drop policy if exists "public read items" on public.items;
drop policy if exists "admin write items" on public.items;
create policy "public read items" on public.items for select using (true);
create policy "admin write items" on public.items for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

drop policy if exists "public read settings" on public.settings;
drop policy if exists "admin write settings" on public.settings;
create policy "public read settings" on public.settings for select using (true);
create policy "admin write settings" on public.settings for all to authenticated
  using (public.is_admin()) with check (public.is_admin());


-- ---------------------------------------------------------------------
-- 4) تخزين الصور (Storage) — bucket عام اسمه menu-images
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('menu-images', 'menu-images', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = true,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "public read menu images"   on storage.objects;
drop policy if exists "admin upload menu images"  on storage.objects;
drop policy if exists "admin update menu images"  on storage.objects;
drop policy if exists "admin delete menu images"  on storage.objects;

create policy "public read menu images" on storage.objects for select
  using (bucket_id = 'menu-images');
create policy "admin upload menu images" on storage.objects for insert to authenticated
  with check (bucket_id = 'menu-images' and public.is_admin());
create policy "admin update menu images" on storage.objects for update to authenticated
  using (bucket_id = 'menu-images' and public.is_admin());
create policy "admin delete menu images" on storage.objects for delete to authenticated
  using (bucket_id = 'menu-images' and public.is_admin());


-- ✅ خلصنا!
-- الخطوة الجاية: افتح لوحة التحكم (/admin) وسجّل دخول، وهتلاقي زرار
-- "استيراد المنيو الحالي" بيضيف الأقسام والأصناف والأسعار كلها بضغطة واحدة.
