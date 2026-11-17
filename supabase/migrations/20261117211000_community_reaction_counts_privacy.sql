-- Keep reaction identities private while publishing aggregate totals.
drop policy if exists "Community reactions are public" on public.community_reactions;
create policy "Players see their own reactions" on public.community_reactions
for select to authenticated using (user_id=(select auth.uid()));
create or replace view public.community_reaction_counts with (security_invoker=false) as
select post_id,reaction,count(*)::integer as total
from public.community_reactions
group by post_id,reaction;
grant select on public.community_reaction_counts to anon,authenticated;
