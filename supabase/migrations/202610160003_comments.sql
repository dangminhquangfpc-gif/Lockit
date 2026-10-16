begin;
create table public.photo_comments (
  id uuid primary key default gen_random_uuid(),
  moment_id uuid not null references public.moments(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 500),
  created_at timestamptz not null default now(),
  reply_to uuid,
  unique (id, moment_id),
  foreign key (reply_to, moment_id) references public.photo_comments(id, moment_id) on delete cascade,
  check (reply_to is null or reply_to <> id)
);
create index photo_comments_page on public.photo_comments(moment_id, created_at desc, id desc);
alter table public.photo_comments enable row level security;
create policy comments_visible on public.photo_comments for select to authenticated
using (exists (select 1 from public.moments m where m.id = moment_id));
revoke all on public.photo_comments from anon, authenticated;
grant select on public.photo_comments to authenticated;

-- Server assigns author, ID and timestamp; clients cannot forge another account.
create function public.send_photo_comment(photo_id uuid, message text, parent_id uuid default null)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not exists (select 1 from public.moments m where m.id = photo_id
    and (m.author_id = auth.uid() or public.are_friends(m.author_id, auth.uid()))) then
    raise exception 'photo_unavailable';
  end if;
  if parent_id is not null and not exists (select 1 from public.photo_comments
    where id = parent_id and moment_id = photo_id) then
    raise exception 'comment_unavailable';
  end if;
  insert into public.photo_comments(moment_id, author_id, body, reply_to)
    values(photo_id, auth.uid(), btrim(message), parent_id);
end;
$$;
revoke all on function public.send_photo_comment(uuid, text, uuid) from public;
grant execute on function public.send_photo_comment(uuid, text, uuid) to authenticated;
commit;
