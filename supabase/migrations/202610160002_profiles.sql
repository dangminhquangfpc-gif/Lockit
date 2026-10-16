begin;

alter table public.profiles
  add column bio text not null default '' check (char_length(bio) <= 80),
  add column avatar_emoji text not null default '' check (
    avatar_emoji in ('', '☀️', '🌻', '🌿', '🌙', '🐻', '🐱', '🌊', '✨')),
  add column avatar_color integer not null default 0 check (avatar_color between 0 and 5);

-- The caller cannot supply an account ID or change a username through this RPC.
create function public.update_profile(new_name text, new_bio text, new_emoji text, new_color integer)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  update public.profiles set display_name = btrim(new_name), bio = btrim(new_bio),
    avatar_emoji = new_emoji, avatar_color = new_color where id = auth.uid();
  if not found then raise exception 'profile_not_found'; end if;
end;
$$;
revoke all on function public.update_profile(text, text, text, integer) from public;
grant execute on function public.update_profile(text, text, text, integer) to authenticated;

commit;
