-- PLAYFORJA community foundation
create table if not exists public.community_channels (
 id uuid primary key default gen_random_uuid(), slug text not null unique, title text not null,
 description text not null default '', follower_count integer not null default 0 check (follower_count >= 0),
 created_at timestamptz not null default now()
);
create table if not exists public.community_follows (
 channel_id uuid not null references public.community_channels(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 created_at timestamptz not null default now(), primary key(channel_id,user_id)
);
create table if not exists public.community_stickers (
 code text primary key, title text not null, symbol text not null,
 kind text not null check (kind in ('emoji','meme','gif')), active boolean not null default true
);
create table if not exists public.community_posts (
 id uuid primary key default gen_random_uuid(),
 channel_id uuid not null references public.community_channels(id) on delete cascade,
 author_id uuid not null references public.profiles(id) on delete cascade,
 body text not null check (char_length(body) between 1 and 1000),
 sticker_code text references public.community_stickers(code),
 status text not null default 'published' check (status in ('published','hidden')),
 created_at timestamptz not null default now()
);
create table if not exists public.community_reactions (
 post_id uuid not null references public.community_posts(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 reaction text not null check (reaction in ('forja','gg','fuego','corazon')),
 created_at timestamptz not null default now(), primary key(post_id,user_id)
);
do $$ begin
 if not exists(select 1 from pg_constraint where conname='community_posts_author_profile_fkey' and conrelid='public.community_posts'::regclass) then
  alter table public.community_posts add constraint community_posts_author_profile_fkey foreign key(author_id) references public.profiles(id) on delete cascade;
 end if;
end $$;
create index if not exists community_posts_channel_created_idx on public.community_posts(channel_id,created_at desc);
create index if not exists community_posts_author_idx on public.community_posts(author_id);
create index if not exists community_follows_user_idx on public.community_follows(user_id);
create index if not exists community_reactions_post_idx on public.community_reactions(post_id);
insert into public.community_channels(slug,title,description)
values ('playforja-oficial','PLAYFORJA Oficial','La comunidad oficial de PLAYFORJA. Forjá tu leyenda junto a jugadores de toda Latinoamérica.')
on conflict (slug) do update set title=excluded.title,description=excluded.description;
insert into public.community_stickers(code,title,symbol,kind) values
('yunque','Yunque legendario','⚒️','emoji'),('llama','Llama de la forja','🔥','emoji'),
('corona','Corona de campeón','👑','emoji'),('gg','GG legendario','🏆','meme'),
('modo-forja','Modo forja activado','⚡','gif')
on conflict (code) do update set title=excluded.title,symbol=excluded.symbol,kind=excluded.kind,active=true;
create or replace function public.sync_community_follower_count()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if tg_op='INSERT' then
  update public.community_channels set follower_count=follower_count+1 where id=new.channel_id; return new;
 elsif tg_op='DELETE' then
  update public.community_channels set follower_count=greatest(0,follower_count-1) where id=old.channel_id; return old;
 end if;
 return null;
end; $$;
revoke all on function public.sync_community_follower_count() from public,anon,authenticated;
drop trigger if exists community_follower_count_trigger on public.community_follows;
create trigger community_follower_count_trigger after insert or delete on public.community_follows
for each row execute function public.sync_community_follower_count();
alter table public.community_channels enable row level security;
alter table public.community_follows enable row level security;
alter table public.community_stickers enable row level security;
alter table public.community_posts enable row level security;
alter table public.community_reactions enable row level security;
drop policy if exists "Community channels are public" on public.community_channels;
create policy "Community channels are public" on public.community_channels for select to anon,authenticated using(true);
drop policy if exists "Active stickers are public" on public.community_stickers;
create policy "Active stickers are public" on public.community_stickers for select to anon,authenticated using(active=true);
drop policy if exists "Published community posts are public" on public.community_posts;
create policy "Published community posts are public" on public.community_posts for select to anon,authenticated using(status='published');
drop policy if exists "Players publish their own posts" on public.community_posts;
create policy "Players publish their own posts" on public.community_posts for insert to authenticated with check(author_id=(select auth.uid()));
drop policy if exists "Players edit their own posts" on public.community_posts;
create policy "Players edit their own posts" on public.community_posts for update to authenticated using(author_id=(select auth.uid())) with check(author_id=(select auth.uid()));
drop policy if exists "Players delete their own posts" on public.community_posts;
create policy "Players delete their own posts" on public.community_posts for delete to authenticated using(author_id=(select auth.uid()));
drop policy if exists "Players see their own follows" on public.community_follows;
create policy "Players see their own follows" on public.community_follows for select to authenticated using(user_id=(select auth.uid()));
drop policy if exists "Players follow channels" on public.community_follows;
create policy "Players follow channels" on public.community_follows for insert to authenticated with check(user_id=(select auth.uid()));
drop policy if exists "Players unfollow channels" on public.community_follows;
create policy "Players unfollow channels" on public.community_follows for delete to authenticated using(user_id=(select auth.uid()));
drop policy if exists "Community reactions are public" on public.community_reactions;
create policy "Community reactions are public" on public.community_reactions for select to anon,authenticated using(true);
drop policy if exists "Players react as themselves" on public.community_reactions;
create policy "Players react as themselves" on public.community_reactions for insert to authenticated with check(user_id=(select auth.uid()));
drop policy if exists "Players remove their own reactions" on public.community_reactions;
create policy "Players remove their own reactions" on public.community_reactions for delete to authenticated using(user_id=(select auth.uid()));
grant select on public.community_channels,public.community_stickers,public.community_posts,public.community_reactions to anon,authenticated;
grant select,insert,update,delete on public.community_follows to authenticated;
grant insert,update,delete on public.community_posts to authenticated;
grant insert,delete on public.community_reactions to authenticated;
