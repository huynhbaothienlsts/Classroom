-- Classroom Buzz: chạy trong Supabase SQL Editor.
-- Lưu ý: đây là cấu hình lớp học đơn giản dùng anon key và RLS mở cho ứng dụng.
-- Không dùng cho dữ liệu nhạy cảm hoặc môi trường công khai không kiểm soát.
create extension if not exists pgcrypto;

create table if not exists public.buzz_rounds (
  id uuid primary key default gen_random_uuid(),
  room_code text not null,
  is_open boolean not null default true,
  created_at timestamptz not null default now(),
  closed_at timestamptz
);

create index if not exists buzz_rounds_room_created_idx
  on public.buzz_rounds(room_code, created_at desc);

create table if not exists public.buzz_events (
  id uuid primary key default gen_random_uuid(),
  round_id uuid not null references public.buzz_rounds(id) on delete cascade,
  room_code text not null,
  lane smallint not null check (lane between 1 and 3),
  team smallint not null check (team between 1 and 6),
  created_at timestamptz not null default now(),
  unique(round_id, lane, team)
);

create index if not exists buzz_events_round_created_idx
  on public.buzz_events(round_id, created_at asc);

alter table public.buzz_rounds enable row level security;
alter table public.buzz_events enable row level security;

-- Remove existing policies with these names so script can be rerun.
drop policy if exists "buzz_rounds_read_anon" on public.buzz_rounds;
drop policy if exists "buzz_rounds_insert_anon" on public.buzz_rounds;
drop policy if exists "buzz_rounds_update_anon" on public.buzz_rounds;
drop policy if exists "buzz_events_read_anon" on public.buzz_events;
drop policy if exists "buzz_events_insert_anon" on public.buzz_events;

create policy "buzz_rounds_read_anon" on public.buzz_rounds
  for select to anon, authenticated using (true);
create policy "buzz_rounds_insert_anon" on public.buzz_rounds
  for insert to anon, authenticated with check (true);
create policy "buzz_rounds_update_anon" on public.buzz_rounds
  for update to anon, authenticated using (true) with check (true);

create policy "buzz_events_read_anon" on public.buzz_events
  for select to anon, authenticated using (true);
create policy "buzz_events_insert_anon" on public.buzz_events
  for insert to anon, authenticated with check (
    lane between 1 and 3 and team between 1 and 6
    and exists (
      select 1 from public.buzz_rounds r
      where r.id = round_id and r.room_code = buzz_events.room_code and r.is_open = true
    )
  );

grant usage on schema public to anon, authenticated;
grant select, insert, update on public.buzz_rounds to anon, authenticated;
grant select, insert on public.buzz_events to anon, authenticated;

-- Enable Realtime for buzz_events. If this errors because it is already included,
-- open Database > Replication and make sure public.buzz_events is enabled.
do $$
begin
  alter publication supabase_realtime add table public.buzz_events;
exception when duplicate_object then
  null;
when others then
  raise notice 'Could not add buzz_events to supabase_realtime automatically: %', sqlerrm;
end $$;


-- Trạng thái hiển thị form đánh giá trên màn hình học sinh, theo từng mã phòng.
create table if not exists public.buzz_room_settings (
  room_code text primary key,
  evaluation_visible boolean not null default false,
  updated_at timestamptz not null default now()
);

alter table public.buzz_room_settings enable row level security;

drop policy if exists "buzz_room_settings_read_anon" on public.buzz_room_settings;
drop policy if exists "buzz_room_settings_insert_anon" on public.buzz_room_settings;
drop policy if exists "buzz_room_settings_update_anon" on public.buzz_room_settings;

create policy "buzz_room_settings_read_anon" on public.buzz_room_settings
  for select to anon, authenticated using (true);
create policy "buzz_room_settings_insert_anon" on public.buzz_room_settings
  for insert to anon, authenticated with check (true);
create policy "buzz_room_settings_update_anon" on public.buzz_room_settings
  for update to anon, authenticated using (true) with check (true);

grant select, insert, update on public.buzz_room_settings to anon, authenticated;

-- Bật realtime cho bảng cài đặt phòng để học sinh nhận thay đổi ngay lập tức.
do $$
begin
  alter publication supabase_realtime add table public.buzz_room_settings;
exception when duplicate_object then
  null;
when others then
  raise notice 'Could not add buzz_room_settings to supabase_realtime automatically: %', sqlerrm;
end $$;
