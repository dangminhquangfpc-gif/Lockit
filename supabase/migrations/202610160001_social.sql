-- Run once in a new Supabase project, as postgres (SQL Editor or supabase db push).
begin;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique check (username ~ '^[a-z0-9_]{3,24}$'),
  display_name text not null check (char_length(btrim(display_name)) between 1 and 40),
  created_at timestamptz not null default now()
);

create function public.create_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles(id, username, display_name)
  values (new.id, new.raw_user_meta_data->>'username',
          btrim(new.raw_user_meta_data->>'display_name'));
  return new;
end;
$$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.create_profile();

create table public.friendships (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at timestamptz not null default now(),
  check (sender_id <> recipient_id)
);
create unique index friendships_pair on public.friendships
  (least(sender_id, recipient_id), greatest(sender_id, recipient_id));
create index friendships_recipient on public.friendships(recipient_id);
create index friendships_sender on public.friendships(sender_id);

create function public.are_friends(first_user uuid, second_user uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.friendships
    where status = 'accepted' and (
      (sender_id = first_user and recipient_id = second_user) or
      (sender_id = second_user and recipient_id = first_user)
    ) and auth.uid() in (first_user, second_user));
$$;

create function public.send_friend_request(target_username text) returns void
language plpgsql security definer set search_path = '' as $$
declare target_id uuid;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select id into target_id from public.profiles where username = btrim(target_username);
  if target_id is null then raise exception 'user_not_found'; end if;
  if target_id = auth.uid() then raise exception 'cannot_add_self'; end if;
  insert into public.friendships(sender_id, recipient_id) values (auth.uid(), target_id);
exception when unique_violation then raise exception 'request_exists';
end;
$$;

create function public.respond_friend_request(request_id uuid, approve boolean) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if approve then
    update public.friendships set status = 'accepted'
      where id = request_id and recipient_id = auth.uid() and status = 'pending';
  else
    delete from public.friendships
      where id = request_id and recipient_id = auth.uid() and status = 'pending';
  end if;
  if not found then raise exception 'request_not_found'; end if;
end;
$$;

create function public.remove_friendship(request_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  delete from public.friendships where id = request_id
    and auth.uid() in (sender_id, recipient_id);
  if not found then raise exception 'request_not_found'; end if;
end;
$$;

create table public.moments (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  image_path text not null unique,
  caption text not null default '' check (char_length(caption) <= 280),
  created_at timestamptz not null default now(),
  check (split_part(image_path, '/', 1) = author_id::text)
);
create index moments_feed on public.moments(created_at desc, id desc);
create index moments_author on public.moments(author_id, created_at desc, id desc);

create table public.reactions (
  moment_id uuid not null references public.moments(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  primary key (moment_id, user_id)
);

alter table public.profiles enable row level security;
alter table public.friendships enable row level security;
alter table public.moments enable row level security;
alter table public.reactions enable row level security;

-- Profile rows contain no email addresses or private auth metadata.
create policy profiles_read on public.profiles for select to authenticated using (true);
create policy friendship_read on public.friendships for select to authenticated
  using (auth.uid() in (sender_id, recipient_id));
create policy moments_read on public.moments for select to authenticated
  using (author_id = auth.uid() or public.are_friends(author_id, auth.uid()));
create policy moments_insert on public.moments for insert to authenticated
  with check (author_id = auth.uid() and exists (
    select 1 from storage.objects where bucket_id = 'moments' and name = image_path
  ));
create policy moments_delete on public.moments for delete to authenticated
  using (author_id = auth.uid());
create policy reactions_read on public.reactions for select to authenticated
  using (exists(select 1 from public.moments where id = moment_id));
create policy reactions_insert on public.reactions for insert to authenticated
  with check (user_id = auth.uid() and exists(select 1 from public.moments where id = moment_id));
create policy reactions_delete on public.reactions for delete to authenticated
  using (user_id = auth.uid());

-- Private bucket. No public URLs or signed URLs that outlive a friendship.
insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('moments', 'moments', false, 10485760, array['image/jpeg']);

create policy moment_photo_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'moments' and (storage.foldername(name))[1] = auth.uid()::text);
create policy moment_photo_read on storage.objects for select to authenticated
  using (bucket_id = 'moments' and (
    (storage.foldername(name))[1] = auth.uid()::text
    or exists(select 1 from public.moments where image_path = name)
  ));
create policy moment_photo_delete on storage.objects for delete to authenticated
  using (bucket_id = 'moments' and (storage.foldername(name))[1] = auth.uid()::text);

-- No direct client writes to friendships: RPCs enforce who can accept a request.
revoke all on public.profiles, public.friendships, public.moments, public.reactions from anon, authenticated;
grant select on public.profiles, public.friendships to authenticated;
grant select, insert, delete on public.moments, public.reactions to authenticated;
revoke all on function public.create_profile() from public;
revoke all on function public.are_friends(uuid, uuid) from public;
revoke all on function public.send_friend_request(text) from public;
revoke all on function public.respond_friend_request(uuid, boolean) from public;
revoke all on function public.remove_friendship(uuid) from public;
grant execute on function public.are_friends(uuid, uuid),
  public.send_friend_request(text), public.respond_friend_request(uuid, boolean),
  public.remove_friendship(uuid) to authenticated;

commit;
