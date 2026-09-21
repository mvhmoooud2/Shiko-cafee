-- =====================================================================
--  قهوة شيكو — إعداد قاعدة البيانات على Supabase (شغّله مرة واحدة)
-- =====================================================================
--  الطريقة:
--   1) افتح مشروعك على Supabase → من القائمة الجانبية "SQL Editor" → "New query"
--   2) عدّل الإيميل في السطر اللي عليه علامة ✏️ تحت (إيميل العميل اللي هيدخل بيه)
--   3) انسخ الملف كله والصقه واضغط Run
--
--  الملف آمن لو اتشغّل أكتر من مرة (مش هيمسح بيانات موجودة).
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


-- ---------------------------------------------------------------------
-- 5) المنيو الحالي (بيتضاف بس لو الجداول فاضية)
-- ---------------------------------------------------------------------
insert into public.settings (shop_name, tagline, address, whatsapp, instagram1, instagram2, maps_url, logo_url)
select 'قهوة شيكو', 'قهوتك على أصولها ☕', '٧ شارع الثورة - الكوربة - مصر الجديدة', '201035641725', 'amin.shiko11', 'shiko.coffee', 'https://www.google.com/maps/search/?api=1&query=%D9%A7%D9%84%D9%83%D9%88%D8%B1%D8%A8%D8%A9+%D8%B4%D8%A7%D8%B1%D8%B9+%D8%A7%D9%84%D8%AB%D9%88%D8%B1%D8%A9+%D9%A7+%D9%85%D8%B5%D8%B1+%D8%A7%D9%84%D8%AC%D8%AF%D9%8A%D8%AF%D8%A9', null
where not exists (select 1 from public.settings);

do $$
begin
  if exists (select 1 from public.categories) then
    raise notice 'المنيو موجود بالفعل — تم تخطي إضافة البيانات الافتراضية.';
    return;
  end if;

  insert into public.categories (id, name, icon, sort_order, is_active) values
    ('9d8e7077-b25f-5ecf-b881-6f9a708f939f', 'مشروبات ساخنة', '☕', 1, true),
    ('3608372c-0402-5bd6-8676-549bbe0cc514', 'مشروبات باردة', '🧊', 2, true),
    ('c5f6a9a0-e047-5055-b4b8-aa62e8d7aaac', 'عصائر', '🍹', 3, true),
    ('6231e727-da4b-5bf5-9af2-d96e3aa6f0a1', 'ميلك شيك و سموذي', '🥛', 4, true),
    ('a5433806-0bec-5c64-82d1-4cdc3c844aba', 'مشروبات غازية', '🥤', 5, true),
    ('3d31348a-9438-5a61-a6fb-d25daa92d09e', 'سبيشال شيكو', '⭐', 6, true),
    ('aa4a0fbe-f419-5d46-8822-3010ad0ab888', 'مخبوزات', '🥐', 7, true),
    ('c14e6d74-3195-5bef-83ed-13130d4954b0', 'ساندوتشات', '🥪', 8, true),
    ('b7e8f24c-c1b2-5a98-aab9-2af34f056ad8', 'جاتوه', '🍰', 9, true),
    ('25eb2ee8-4815-5921-8744-582c4dd42aef', 'إضافات', '➕', 10, true);

  insert into public.items (id, category_id, name, description, price, price_s, price_m, price_l, sort_order, is_available) values
    ('bc566d33-d6c7-5a4c-b1f0-92a124cd1bdb', '9d8e7077-b25f-5ecf-b881-6f9a708f939f', 'اسبريسو', 'ESPRESSO', null, 60, 70, null, 1, true),
    ('50634b79-170b-5faf-a5bd-6d7f01c924fc', '9d8e7077-b25f-5ecf-b881-6f9a708f939f', 'اسبريسو ماكياتو', 'ESPRESSO MACCHIATO', null, 65, 75, null, 2, true),
    ('a9f67424-407e-588c-af27-87ac99457d5e', '9d8e7077-b25f-5ecf-b881-6f9a708f939f', 'قهوة تركي', 'TURKISH COFFEE', null, 50, 60, null, 3, true),
    ('cb27aa38-f59b-5750-8524-0960debbdfac', '9d8e7077-b25f-5ecf-b881-6f9a708f939f', 'قهوة فرنساوي', 'FRENCH COFFEE', null, null, 75, null, 4, true),
    ('b1edbdce-43e7-5c4d-9560-beac658b84f6', '9d8e7077-b25f-5ecf-b881-6f9a708f939f', 'أمريكانو', 'AMERICANO', null, 65, 75, null, 5, true),
    ('666db0dd-34f2-52ca-a568-4a87aaa9a5e6', '9d8e7077-b25f-5ecf-b881-6f9a708f939f', 'كورتادو', 'CORTADO', null, 70, null, null, 6, true),
    ('0796acf6-7276-5426-a14a-e2c14cf4b864', '9d8e7077-b25f-5ecf-b881-6f9a708f939f', 'فلات وايت', 'FLAT WHITE', null, 100, 110, null, 7, true),
    ('37026518-d7c2-5fff-98c2-545c9d05be10', '9d8e7077-b25f-5ecf-b881-6f9a708f939f', 'كابتشينو', 'CAPPUCCINO', null, 90, 100, null, 8, true),
    ('9ff62908-a84e-56ac-8dff-c00e9c565483', '9d8e7077-b25f-5ecf-b881-6f9a708f939f', 'لاتيه', 'LATTE', null, 90, 100, null, 9, true),
    ('c6b267f5-8b91-5567-b048-758698188823', '9d8e7077-b25f-5ecf-b881-6f9a708f939f', 'موكا', 'MOCHA', null, null, 115, null, 10, true),
    ('38a27aa2-3ec9-5d9e-b40f-7fbe66e1597a', '9d8e7077-b25f-5ecf-b881-6f9a708f939f', 'سبانيش لاتيه', 'SPANISH LATTE', null, null, 120, null, 11, true),
    ('cbe2dd43-544a-583e-8e73-7016bebe80e9', '9d8e7077-b25f-5ecf-b881-6f9a708f939f', 'بستاشيو لاتيه', 'PISTACHIO LATTE', null, null, 125, null, 12, true),
    ('6370f5a3-d398-5357-b047-0a01f0c56944', '9d8e7077-b25f-5ecf-b881-6f9a708f939f', 'سولتد كراميل لاتيه', 'SALTED CARAMEL LATTE', null, null, 120, null, 13, true),
    ('16407317-0226-5185-9434-ab63159119c4', '9d8e7077-b25f-5ecf-b881-6f9a708f939f', 'لوتس لاتيه', 'LOTUS LATTE', null, null, 120, null, 14, true),
    ('7b20cd85-3cf7-51f8-9fd3-ab2f4a37c593', '9d8e7077-b25f-5ecf-b881-6f9a708f939f', 'شاي', 'TEA', null, 50, 60, null, 15, true),
    ('54368f7a-364d-5ce0-a514-4830c60d22ee', '9d8e7077-b25f-5ecf-b881-6f9a708f939f', 'شاي بنكهة', 'TEA FLOWER', null, 55, 65, null, 16, true),
    ('98c2895e-078c-5abe-aa50-059575e093b0', '9d8e7077-b25f-5ecf-b881-6f9a708f939f', 'شاي لاتيه', 'TEA LATTE', null, 60, 70, null, 17, true),
    ('4ef3bb98-582b-59f5-a7e0-a054e74cf529', '9d8e7077-b25f-5ecf-b881-6f9a708f939f', 'هوت شوكليت', 'HOT CHOCOLATE', null, 110, 120, null, 18, true),
    ('25b38133-1810-5782-b6b2-a16281dba6bb', '3608372c-0402-5bd6-8676-549bbe0cc514', 'لاتيه فرابيه', 'LATTE FRAPPE', null, 110, 125, null, 1, true),
    ('018f21bb-2f86-5a01-b693-c81acbf1aba5', '3608372c-0402-5bd6-8676-549bbe0cc514', 'كراميل فرابيه', 'CARAMEL FRAPPE', null, 120, 140, null, 2, true),
    ('83064ac3-b91b-5068-9598-11515f01c032', '3608372c-0402-5bd6-8676-549bbe0cc514', 'شوكليت فرابيه', 'CHOCOLATE FRAPPE', null, 120, 140, null, 3, true),
    ('66923a16-5727-54dc-a7a1-24faab92f00a', '3608372c-0402-5bd6-8676-549bbe0cc514', 'كراميل لاتيه فرابيه', 'CARAMEL LATTE FRAPPE', null, 135, 150, null, 4, true),
    ('68a836fc-7c34-555b-91f1-2aeada1401f6', '3608372c-0402-5bd6-8676-549bbe0cc514', 'موكا فرابيه', 'MOCHA FRAPPE', null, 135, 150, null, 5, true),
    ('492c7189-4076-5d9d-9c95-0b26437ac2b1', '3608372c-0402-5bd6-8676-549bbe0cc514', 'أوريو فرابيه', 'OREO FRAPPE', null, 130, 150, null, 6, true),
    ('096ee21c-7855-5c13-ba19-e9cb450f0755', '3608372c-0402-5bd6-8676-549bbe0cc514', 'أوريو كوفي فرابيه', 'OREO COFFEE FRAPPE', null, 140, 160, null, 7, true),
    ('47ba6fc9-0c5a-5567-9c80-370de2a591ae', '3608372c-0402-5bd6-8676-549bbe0cc514', 'لوتس لاتيه فرابيه', 'LOTUS LATTE FRAPPE', null, 130, 150, null, 8, true),
    ('61e37665-2d75-5fb9-b0ec-9d3747880f60', '3608372c-0402-5bd6-8676-549bbe0cc514', 'بستاشيو لاتيه فرابيه', 'PISTACHIO LATTE FRAPPE', null, 130, 150, null, 9, true),
    ('a68ac42c-3f7c-5f10-86a4-9bc6d3b635bf', '3608372c-0402-5bd6-8676-549bbe0cc514', 'زبادي بالفواكه', 'FRUIT YOGURT', null, 130, 150, null, 10, true),
    ('a2a4a52a-3916-5d49-ad17-e17cd57f9ffb', '3608372c-0402-5bd6-8676-549bbe0cc514', 'آيس لاتيه', 'ICE LATTE', null, 110, 125, null, 11, true),
    ('9e29a93c-26b7-55a5-8fc7-1889a84ef819', '3608372c-0402-5bd6-8676-549bbe0cc514', 'آيس سبانيش لاتيه', 'ICE SPANISH LATTE', null, 130, 150, null, 12, true),
    ('36958985-7a49-5bc9-93b0-194e46fcfe56', '3608372c-0402-5bd6-8676-549bbe0cc514', 'آيس بستاشيو لاتيه', 'ICE PISTACHIO LATTE', null, 130, 150, null, 13, true),
    ('3284d394-50fa-5e77-b911-2147492008b1', '3608372c-0402-5bd6-8676-549bbe0cc514', 'آيس لوتس لاتيه', 'ICE LOTUS LATTE', null, 130, 150, null, 14, true),
    ('89e93d42-d53c-57d7-8438-98554d46350c', '3608372c-0402-5bd6-8676-549bbe0cc514', 'ريد بول كوفي', 'RED BULL COFFEE', null, null, 140, null, 15, true),
    ('77d96e9f-818d-5e40-9a0a-108798f64ca6', '3608372c-0402-5bd6-8676-549bbe0cc514', 'ريد بول فروت', 'RED BULL FRUIT', null, null, 160, null, 16, true),
    ('28405afa-b396-583b-9f97-7a70dd5f870f', '3608372c-0402-5bd6-8676-549bbe0cc514', 'آيس أمريكانو', 'ICE AMERICANO', null, 100, 115, null, 17, true),
    ('082c2d0d-65db-5ab1-b39c-8358e1be3f7f', '3608372c-0402-5bd6-8676-549bbe0cc514', 'أفوكادو', 'AVOCADO', null, 125, null, null, 18, true),
    ('00592ae2-c6b7-526d-89cf-3f50a8214556', '3608372c-0402-5bd6-8676-549bbe0cc514', 'موهيتو نعناع', 'MOJITO MINT', null, 130, 150, null, 19, true),
    ('af5231aa-9ce3-5eba-9228-4dc83ab863d0', '3608372c-0402-5bd6-8676-549bbe0cc514', 'موهيتو فواكه', 'MOJITO FRUIT', null, 140, 160, null, 20, true),
    ('2c6434c4-d6d9-5837-bb9b-ea4ac55eecb2', 'c5f6a9a0-e047-5055-b4b8-aa62e8d7aaac', 'عصير فراولة', 'STRAWBERRY JUICE', 100, null, null, null, 1, true),
    ('26e50ca1-0e98-5856-9c6a-dcb10bd30b34', 'c5f6a9a0-e047-5055-b4b8-aa62e8d7aaac', 'عصير مانجو', 'MANGO JUICE', 120, null, null, null, 2, true),
    ('51c75da2-9550-57fc-aa75-e9dd17b9d3af', 'c5f6a9a0-e047-5055-b4b8-aa62e8d7aaac', 'عصير برتقال', 'ORANGE JUICE', 100, null, null, null, 3, true),
    ('73e7f6c0-eff4-55ee-83aa-7c3ff9259f0e', 'c5f6a9a0-e047-5055-b4b8-aa62e8d7aaac', 'عصير جوافة', 'GUAVA JUICE', 100, null, null, null, 4, true),
    ('c1e364ec-4e9e-5927-a9aa-a05ca5361989', '6231e727-da4b-5bf5-9af2-d96e3aa6f0a1', 'ميلك شيك', 'VANILLA - CHOCOLATE - STRAWBERRY - MANGO', 130, null, null, null, 1, true),
    ('87ebddea-4bc3-51e6-81ec-1d79443cb9f1', '6231e727-da4b-5bf5-9af2-d96e3aa6f0a1', 'سموذي', 'KIWI - STRAWBERRY - MANGO - PASSION FRUIT - BLUEBERRY', 120, null, null, null, 2, true),
    ('b5c66951-bef7-5582-a219-f5589d0d15b0', 'a5433806-0bec-5c64-82d1-4cdc3c844aba', 'ريد بول', 'RED BULL', 65, null, null, null, 1, true),
    ('693d71ec-55db-5863-b2cb-69d85dcf14e2', 'a5433806-0bec-5c64-82d1-4cdc3c844aba', 'ڤي كولا', 'V COLA', 35, null, null, null, 2, true),
    ('a5c661fb-dd12-5b6e-b05e-66a011d8129f', 'a5433806-0bec-5c64-82d1-4cdc3c844aba', 'مياه', 'WATER', 15, null, null, null, 3, true),
    ('581fb657-74ad-56b7-b759-0f8a5311d0f4', '3d31348a-9438-5a61-a6fb-d25daa92d09e', 'قهوة شيكو سبيشال', 'MANGO - CARAMEL - HAZELNUT - STRAWBERRY - RASPBERRY - PISTACHIO - BANANA - CHOCOLATE', 70, null, null, null, 1, true),
    ('05b9a555-7cfe-592b-a365-e6245ada4ca5', 'aa4a0fbe-f419-5d46-8822-3010ad0ab888', 'بلين', 'PLAIN', 100, null, null, null, 1, true),
    ('b825aead-95ff-511f-ab8e-8768ca75e143', 'aa4a0fbe-f419-5d46-8822-3010ad0ab888', 'تشيدر', 'CHEDDAR', 120, null, null, null, 2, true),
    ('bddbec3f-2457-5274-b362-12b49a81d0b1', 'aa4a0fbe-f419-5d46-8822-3010ad0ab888', 'نوتيلا', 'NUTELLA', 130, null, null, null, 3, true),
    ('4afcddfa-8fcb-5c7b-b5be-13ce20725018', 'aa4a0fbe-f419-5d46-8822-3010ad0ab888', 'بستاشيو', 'PISTACHIO', 140, null, null, null, 4, true),
    ('2632b41c-523d-58b0-bd85-922c61b97b9e', 'c14e6d74-3195-5bef-83ed-13130d4954b0', 'تونة', 'TUNA', 160, null, null, null, 1, true),
    ('13197456-2cfd-500f-bbdc-fcdac74de936', 'c14e6d74-3195-5bef-83ed-13130d4954b0', 'سلمون', 'SALMON', 310, null, null, null, 2, true),
    ('df177553-8291-5362-8f29-f2f196777941', 'c14e6d74-3195-5bef-83ed-13130d4954b0', 'فراخ', 'CHICKEN', 160, null, null, null, 3, true),
    ('342e1489-674c-5e16-98e8-cb3016ab27df', 'c14e6d74-3195-5bef-83ed-13130d4954b0', 'روست بيف', 'ROAST BEEF', 190, null, null, null, 4, true),
    ('b4dff1b1-e2d9-5978-8c88-087868c420ac', 'c14e6d74-3195-5bef-83ed-13130d4954b0', 'حبش (تركي)', 'TURKY', 195, null, null, null, 5, true),
    ('7314089f-116c-5536-9a9c-b4159b81f21f', 'b7e8f24c-c1b2-5a98-aab9-2af34f056ad8', 'روشيه', 'ROCHER', 120, null, null, null, 1, true),
    ('a2905523-eb12-5101-81e2-09e2276dfb8e', 'b7e8f24c-c1b2-5a98-aab9-2af34f056ad8', 'بيكان تشيز كيك', 'PECAN CHEESECAKE', 180, null, null, null, 2, true),
    ('eeded93b-fff6-5362-9da2-d24f9ebd3985', 'b7e8f24c-c1b2-5a98-aab9-2af34f056ad8', 'تشيز كيك بالتوت', 'BERRY CHEESECAKE', 180, null, null, null, 3, true),
    ('4d436144-d87f-5f09-9e53-1aa7abd7b89f', 'b7e8f24c-c1b2-5a98-aab9-2af34f056ad8', 'رول بستاشيو', 'PISTACHIO ROLL', 120, null, null, null, 4, true),
    ('72125383-2206-5477-aa0a-cd5ea190fb7d', 'b7e8f24c-c1b2-5a98-aab9-2af34f056ad8', 'هازلنوت شوكليت', 'HAZELNUT CHOCOLATE', 130, null, null, null, 5, true),
    ('7065384f-5dfd-5834-a88a-bfdb038b51ee', 'b7e8f24c-c1b2-5a98-aab9-2af34f056ad8', 'ميل فاي بالتوت', 'BERRY MILLEFEUILLE', 150, null, null, null, 6, true),
    ('53fd4738-e291-56be-bfaa-9f2754f46e40', 'b7e8f24c-c1b2-5a98-aab9-2af34f056ad8', 'كوفي شوكليت', 'COFFEE CHOCOLATE', 115, null, null, null, 7, true),
    ('7e1ffc19-3287-5e7d-8203-1e233dcd2637', 'b7e8f24c-c1b2-5a98-aab9-2af34f056ad8', 'موس الشوكليت', 'CHOCOLATE MOUSSE', 115, null, null, null, 8, true),
    ('c152a2df-b1be-5307-a209-da954efc1db6', 'b7e8f24c-c1b2-5a98-aab9-2af34f056ad8', 'فانيليا بالرازبيري', 'RASPBERRY VANILLA', 120, null, null, null, 9, true),
    ('36b143db-21be-5255-b69f-29655fa12a9d', '25eb2ee8-4815-5921-8744-582c4dd42aef', 'إضافة نكهة', 'EXTRA FLAVOR', 25, null, null, null, 1, true),
    ('d7ac08b7-56e5-528c-b9fe-35ed01853312', '25eb2ee8-4815-5921-8744-582c4dd42aef', 'إضافة حليب', 'EXTRA MILK', 25, null, null, null, 2, true),
    ('607b82a5-0bb4-50b7-a192-919b73343ae2', '25eb2ee8-4815-5921-8744-582c4dd42aef', 'إضافة شوت', 'EXTRA SHOT', 30, null, null, null, 3, true),
    ('e6e044d4-3c17-554c-b204-a31feed6ea87', '25eb2ee8-4815-5921-8744-582c4dd42aef', 'كريمة مخفوقة', 'WHIPPED CREAM', 25, null, null, null, 4, true),
    ('dfd9854d-7d7c-5c4d-b2e2-cb81469136ed', '25eb2ee8-4815-5921-8744-582c4dd42aef', 'إضافة صوص', 'EXTRA SAUCE', 30, null, null, null, 5, true);
end $$;

-- ✅ خلصنا. ارجع للـ README لباقي الخطوات (إنشاء المستخدم + الربط في config.js).
