-- LabFlow / Group Activity Manager
-- Chạy toàn bộ file này trong Supabase SQL Editor trên một project mới.
create extension if not exists pgcrypto;

create type public.app_role as enum ('teacher','student');
create type public.session_status as enum ('draft','waiting','live','paused','finished');
create type public.activity_status as enum ('draft','open','closed');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role public.app_role not null default 'teacher',
  display_name text,
  created_at timestamptz not null default now()
);

create table public.classes (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  school_year text,
  subject text,
  created_at timestamptz not null default now()
);

create table public.students (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id) on delete cascade,
  student_code text not null,
  full_name text not null,
  email text,
  is_active boolean not null default true,
  unique(class_id, student_code)
);

create table public.groups (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id) on delete cascade,
  name text not null,
  color text not null default '#2563eb',
  machine_label text,
  position_x integer not null default 0,
  position_y integer not null default 0,
  join_pin_hash text,
  unique(class_id, name)
);

create table public.group_members (
  group_id uuid not null references public.groups(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  member_role text not null default 'member' check (member_role in ('leader','member')),
  primary key(group_id, student_id),
  unique(student_id)
);

create table public.sessions (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id) on delete cascade,
  teacher_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  topic text,
  join_code text not null unique,
  status public.session_status not null default 'draft',
  started_at timestamptz,
  ended_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.session_groups (
  session_id uuid not null references public.sessions(id) on delete cascade,
  group_id uuid not null references public.groups(id) on delete cascade,
  primary key(session_id, group_id)
);

create table public.activities (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.sessions(id) on delete cascade,
  title text not null,
  instructions text,
  position integer not null default 1,
  status public.activity_status not null default 'draft',
  duration_minutes integer,
  submission_type text not null default 'mixed' check (submission_type in ('text','link','file','mixed','none')),
  require_submission_before_buzz boolean not null default true,
  allow_resubmission boolean not null default true,
  opened_at timestamptz,
  closed_at timestamptz,
  unique(session_id, position)
);

create table public.criteria (
  id uuid primary key default gen_random_uuid(),
  activity_id uuid not null references public.activities(id) on delete cascade,
  title text not null,
  description text,
  criterion_type text not null default 'score' check (criterion_type in ('score','checkbox')),
  max_score numeric(6,2) not null default 1,
  position integer not null default 1
);

create table public.participant_sessions (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.sessions(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'online' check (status in ('online','offline','revoked')),
  joined_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  unique(session_id, student_id),
  unique(session_id, user_id)
);

create table public.submissions (
  id uuid primary key default gen_random_uuid(),
  activity_id uuid not null references public.activities(id) on delete cascade,
  group_id uuid not null references public.groups(id) on delete cascade,
  submitted_by uuid not null references public.participant_sessions(id),
  answer_text text,
  link_url text,
  file_path text,
  file_name text,
  version integer not null default 1,
  status text not null default 'submitted',
  submitted_at timestamptz not null default now(),
  unique(activity_id, group_id)
);

create table public.buzz_rounds (
  id uuid primary key default gen_random_uuid(),
  activity_id uuid not null references public.activities(id) on delete cascade,
  round_number integer not null default 1,
  is_open boolean not null default true,
  opened_at timestamptz not null default now(),
  closed_at timestamptz,
  unique(activity_id, round_number)
);

create table public.buzz_events (
  id uuid primary key default gen_random_uuid(),
  buzz_round_id uuid not null references public.buzz_rounds(id) on delete cascade,
  activity_id uuid not null references public.activities(id) on delete cascade,
  group_id uuid not null references public.groups(id) on delete cascade,
  participant_session_id uuid not null references public.participant_sessions(id),
  submission_id uuid references public.submissions(id),
  result text not null default 'pending' check (result in ('pending','correct','incorrect','skipped')),
  score_awarded numeric(7,2) not null default 0,
  created_at timestamptz not null default clock_timestamp(),
  unique(buzz_round_id, group_id)
);

create table public.evaluation_assignments (
  id uuid primary key default gen_random_uuid(),
  activity_id uuid not null references public.activities(id) on delete cascade,
  evaluator_group_id uuid not null references public.groups(id) on delete cascade,
  target_group_id uuid not null references public.groups(id) on delete cascade,
  is_open boolean not null default false,
  check(evaluator_group_id <> target_group_id),
  unique(activity_id, evaluator_group_id, target_group_id)
);

create table public.evaluations (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null unique references public.evaluation_assignments(id) on delete cascade,
  submitted_by uuid not null references public.participant_sessions(id),
  comment text,
  submitted_at timestamptz not null default now()
);

create table public.evaluation_scores (
  id uuid primary key default gen_random_uuid(),
  evaluation_id uuid not null references public.evaluations(id) on delete cascade,
  criterion_id uuid not null references public.criteria(id) on delete cascade,
  score numeric(6,2),
  checked boolean,
  unique(evaluation_id, criterion_id)
);

create table public.score_entries (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.sessions(id) on delete cascade,
  activity_id uuid references public.activities(id) on delete cascade,
  group_id uuid not null references public.groups(id) on delete cascade,
  source_type text not null,
  source_id uuid,
  points numeric(7,2) not null,
  reason text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table public.audit_logs (
  id bigint generated always as identity primary key,
  session_id uuid references public.sessions(id) on delete cascade,
  actor_id uuid references auth.users(id),
  action text not null,
  entity_type text,
  entity_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index sessions_teacher_idx on public.sessions(teacher_id, created_at desc);
create index activities_session_idx on public.activities(session_id, position);
create index participants_user_idx on public.participant_sessions(user_id, session_id);
create index buzz_events_round_time_idx on public.buzz_events(buzz_round_id, created_at);

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin
  if not coalesce(new.is_anonymous, false) then
    insert into public.profiles(id, role, display_name)
    values(new.id, 'teacher', coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email,'@',1)))
    on conflict(id) do nothing;
  end if;
  return new;
end; $$;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

create or replace function public.is_session_teacher(p_session_id uuid) returns boolean
language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.sessions where id=p_session_id and teacher_id=auth.uid());
$$;

create or replace function public.join_class_session(p_join_code text,p_student_code text,p_group_pin text default null)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_session public.sessions; v_student public.students; v_group public.groups; v_participant public.participant_sessions;
begin
  if auth.uid() is null then raise exception 'Phiên đăng nhập không hợp lệ'; end if;
  select * into v_session from public.sessions where upper(join_code)=upper(trim(p_join_code)) and status in ('waiting','live','paused');
  if not found then raise exception 'Mã buổi học không tồn tại hoặc đã đóng'; end if;
  select * into v_student from public.students where class_id=v_session.class_id and upper(student_code)=upper(trim(p_student_code)) and is_active;
  if not found then raise exception 'Không tìm thấy mã số học sinh trong lớp'; end if;
  select g.* into v_group from public.groups g join public.group_members gm on gm.group_id=g.id where gm.student_id=v_student.id;
  if not found then raise exception 'Học sinh chưa được phân nhóm'; end if;
  if not exists(select 1 from public.session_groups where session_id=v_session.id and group_id=v_group.id) then raise exception 'Nhóm không tham gia buổi học này'; end if;
  if v_group.join_pin_hash is not null and crypt(coalesce(p_group_pin,''),v_group.join_pin_hash)<>v_group.join_pin_hash then raise exception 'PIN nhóm không đúng'; end if;
  insert into public.participant_sessions(session_id,student_id,group_id,user_id,status,last_seen_at)
  values(v_session.id,v_student.id,v_group.id,auth.uid(),'online',now())
  on conflict(session_id,student_id) do update set user_id=auth.uid(),status='online',last_seen_at=now()
  returning * into v_participant;
  insert into public.audit_logs(session_id,actor_id,action,entity_type,entity_id) values(v_session.id,auth.uid(),'student_joined','participant_session',v_participant.id);
  return jsonb_build_object('participant_id',v_participant.id,'session_id',v_session.id,'student_id',v_student.id,'student_name',v_student.full_name,'group_id',v_group.id,'group_name',v_group.name,'code',v_session.join_code);
end; $$;

create or replace function public.submit_group_work(p_activity_id uuid,p_answer_text text default null,p_link_url text default null,p_file_path text default null,p_file_name text default null)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_activity public.activities; v_participant public.participant_sessions; v_submission public.submissions;
begin
  select * into v_activity from public.activities where id=p_activity_id and status='open';
  if not found then raise exception 'Hoạt động chưa mở hoặc đã khóa'; end if;
  select ps.* into v_participant from public.participant_sessions ps join public.sessions s on s.id=ps.session_id where ps.user_id=auth.uid() and ps.session_id=v_activity.session_id and ps.status='online';
  if not found then raise exception 'Phiên học sinh không hợp lệ'; end if;
  if nullif(trim(coalesce(p_answer_text,'')),'') is null and nullif(trim(coalesce(p_link_url,'')),'') is null and p_file_path is null then raise exception 'Cần nộp nội dung, đường dẫn hoặc tệp'; end if;
  insert into public.submissions(activity_id,group_id,submitted_by,answer_text,link_url,file_path,file_name)
  values(p_activity_id,v_participant.group_id,v_participant.id,nullif(trim(p_answer_text),''),nullif(trim(p_link_url),''),p_file_path,p_file_name)
  on conflict(activity_id,group_id) do update set submitted_by=excluded.submitted_by,answer_text=excluded.answer_text,link_url=excluded.link_url,file_path=coalesce(excluded.file_path,submissions.file_path),file_name=coalesce(excluded.file_name,submissions.file_name),version=submissions.version+1,submitted_at=now()
  returning * into v_submission;
  insert into public.audit_logs(session_id,actor_id,action,entity_type,entity_id) values(v_activity.session_id,auth.uid(),'submission_saved','submission',v_submission.id);
  return jsonb_build_object('id',v_submission.id,'submitted_at',v_submission.submitted_at);
end; $$;

create or replace function public.press_buzzer(p_activity_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_activity public.activities; v_participant public.participant_sessions; v_round public.buzz_rounds; v_submission public.submissions; v_event public.buzz_events; v_rank bigint;
begin
  select * into v_activity from public.activities where id=p_activity_id and status='open' for share;
  if not found then raise exception 'Hoạt động chưa mở hoặc đã khóa'; end if;
  select ps.* into v_participant from public.participant_sessions ps where ps.user_id=auth.uid() and ps.session_id=v_activity.session_id and ps.status='online';
  if not found then raise exception 'Phiên học sinh không hợp lệ'; end if;
  select * into v_round from public.buzz_rounds where activity_id=p_activity_id and is_open order by round_number desc limit 1;
  if not found then raise exception 'Giáo viên chưa mở vòng bấm chuông'; end if;
  select * into v_submission from public.submissions where activity_id=p_activity_id and group_id=v_participant.group_id;
  if v_activity.require_submission_before_buzz and not found then raise exception 'Nhóm cần nộp bài trước khi bấm chuông'; end if;
  insert into public.buzz_events(buzz_round_id,activity_id,group_id,participant_session_id,submission_id)
  values(v_round.id,p_activity_id,v_participant.group_id,v_participant.id,v_submission.id)
  returning * into v_event;
  select count(*) into v_rank from public.buzz_events where buzz_round_id=v_round.id and (created_at,id)<=(v_event.created_at,v_event.id);
  insert into public.audit_logs(session_id,actor_id,action,entity_type,entity_id,metadata) values(v_activity.session_id,auth.uid(),'buzzer_pressed','buzz_event',v_event.id,jsonb_build_object('rank',v_rank));
  return jsonb_build_object('id',v_event.id,'rank',v_rank,'created_at',v_event.created_at);
exception when unique_violation then raise exception 'Nhóm đã bấm chuông trong vòng này';
end; $$;

create or replace view public.buzz_rankings with (security_invoker=true) as
select s.id session_id,be.id,be.activity_id,g.name group_name,g.color,be.created_at,
row_number() over(partition by be.buzz_round_id order by be.created_at,be.id) rank,be.result,be.score_awarded
from public.buzz_events be join public.activities a on a.id=be.activity_id join public.sessions s on s.id=a.session_id join public.groups g on g.id=be.group_id;

alter table public.profiles enable row level security;
alter table public.classes enable row level security;
alter table public.students enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.sessions enable row level security;
alter table public.session_groups enable row level security;
alter table public.activities enable row level security;
alter table public.criteria enable row level security;
alter table public.participant_sessions enable row level security;
alter table public.submissions enable row level security;
alter table public.buzz_rounds enable row level security;
alter table public.buzz_events enable row level security;
alter table public.evaluation_assignments enable row level security;
alter table public.evaluations enable row level security;
alter table public.evaluation_scores enable row level security;
alter table public.score_entries enable row level security;
alter table public.audit_logs enable row level security;

create policy "profile_self" on public.profiles for select using(id=auth.uid());
create policy "teacher_classes" on public.classes for all using(teacher_id=auth.uid()) with check(teacher_id=auth.uid());
create policy "teacher_students" on public.students for all using(exists(select 1 from public.classes c where c.id=class_id and c.teacher_id=auth.uid())) with check(exists(select 1 from public.classes c where c.id=class_id and c.teacher_id=auth.uid()));
create policy "teacher_groups" on public.groups for all using(exists(select 1 from public.classes c where c.id=class_id and c.teacher_id=auth.uid())) with check(exists(select 1 from public.classes c where c.id=class_id and c.teacher_id=auth.uid()));
create policy "teacher_group_members" on public.group_members for all using(exists(select 1 from public.groups g join public.classes c on c.id=g.class_id where g.id=group_id and c.teacher_id=auth.uid()));
create policy "teacher_sessions" on public.sessions for all using(teacher_id=auth.uid()) with check(teacher_id=auth.uid());
create policy "teacher_session_groups" on public.session_groups for all using(public.is_session_teacher(session_id));
create policy "teacher_activities" on public.activities for all using(public.is_session_teacher(session_id));
create policy "teacher_criteria" on public.criteria for all using(exists(select 1 from public.activities a where a.id=activity_id and public.is_session_teacher(a.session_id)));
create policy "teacher_participants" on public.participant_sessions for select using(public.is_session_teacher(session_id));
create policy "teacher_submissions" on public.submissions for select using(exists(select 1 from public.activities a where a.id=activity_id and public.is_session_teacher(a.session_id)));
create policy "teacher_rounds" on public.buzz_rounds for all using(exists(select 1 from public.activities a where a.id=activity_id and public.is_session_teacher(a.session_id)));
create policy "teacher_buzz" on public.buzz_events for all using(exists(select 1 from public.activities a where a.id=activity_id and public.is_session_teacher(a.session_id)));
create policy "teacher_eval_assignments" on public.evaluation_assignments for all using(exists(select 1 from public.activities a where a.id=activity_id and public.is_session_teacher(a.session_id)));
create policy "teacher_evaluations" on public.evaluations for select using(exists(select 1 from public.evaluation_assignments ea join public.activities a on a.id=ea.activity_id where ea.id=assignment_id and public.is_session_teacher(a.session_id)));
create policy "teacher_eval_scores" on public.evaluation_scores for select using(exists(select 1 from public.evaluations e join public.evaluation_assignments ea on ea.id=e.assignment_id join public.activities a on a.id=ea.activity_id where e.id=evaluation_id and public.is_session_teacher(a.session_id)));
create policy "teacher_scores" on public.score_entries for all using(public.is_session_teacher(session_id));
create policy "teacher_audit" on public.audit_logs for select using(public.is_session_teacher(session_id));

grant execute on function public.join_class_session(text,text,text) to anon,authenticated;
grant execute on function public.submit_group_work(uuid,text,text,text,text) to authenticated;
grant execute on function public.press_buzzer(uuid) to authenticated;
grant select on public.buzz_rankings to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('submissions','submissions',false,20971520,array['application/pdf','application/zip','text/plain','text/x-c++src','text/x-python','application/vnd.openxmlformats-officedocument.wordprocessingml.document','image/png','image/jpeg'])
on conflict(id) do nothing;

create policy "participant_upload_submission" on storage.objects for insert to authenticated with check(
  bucket_id='submissions' and exists(
    select 1 from public.participant_sessions ps
    where ps.user_id=auth.uid() and ps.session_id::text=(storage.foldername(name))[1] and ps.status='online'
  )
);
create policy "teacher_read_submission_files" on storage.objects for select to authenticated using(
  bucket_id='submissions' and exists(select 1 from public.sessions s where s.id::text=(storage.foldername(name))[1] and s.teacher_id=auth.uid())
);

do $$ begin
  alter publication supabase_realtime add table public.participant_sessions;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.submissions;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.buzz_events;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.activities;
exception when duplicate_object then null; end $$;
