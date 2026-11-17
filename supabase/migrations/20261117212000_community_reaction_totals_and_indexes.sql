drop view if exists public.community_reaction_counts;
create table if not exists public.community_reaction_counts (
 post_id uuid not null references public.community_posts(id) on delete cascade,
 reaction text not null check(reaction in ('forja','gg','fuego','corazon')),
 total integer not null default 0 check(total>=0),
 primary key(post_id,reaction)
);
insert into public.community_reaction_counts(post_id,reaction,total)
select post_id,reaction,count(*)::integer from public.community_reactions
group by post_id,reaction
on conflict(post_id,reaction) do update set total=excluded.total;
alter table public.community_reaction_counts enable row level security;
drop policy if exists "Public can read reaction totals" on public.community_reaction_counts;
create policy "Public can read reaction totals" on public.community_reaction_counts
for select to anon,authenticated using(true);
grant select on public.community_reaction_counts to anon,authenticated;

create or replace function public.sync_community_reaction_totals()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if tg_op='INSERT' then
  insert into public.community_reaction_counts(post_id,reaction,total)
  values(new.post_id,new.reaction,1)
  on conflict(post_id,reaction) do update set total=public.community_reaction_counts.total+1;
  return new;
 elsif tg_op='DELETE' then
  update public.community_reaction_counts set total=greatest(0,total-1)
  where post_id=old.post_id and reaction=old.reaction;
  delete from public.community_reaction_counts
  where post_id=old.post_id and reaction=old.reaction and total=0;
  return old;
 end if;
 return null;
end;
$$;
revoke all on function public.sync_community_reaction_totals() from public,anon,authenticated;
drop trigger if exists community_reaction_totals_trigger on public.community_reactions;
create trigger community_reaction_totals_trigger after insert or delete on public.community_reactions
for each row execute function public.sync_community_reaction_totals();

create index if not exists community_posts_sticker_code_idx on public.community_posts(sticker_code);
create index if not exists community_reactions_user_idx on public.community_reactions(user_id);
create index if not exists game_room_members_user_idx on public.game_room_members(user_id);
create index if not exists game_rooms_host_user_idx on public.game_rooms(host_user_id);
