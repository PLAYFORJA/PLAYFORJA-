create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated,anon;

create or replace function private.create_game_room(p_title text,p_game text,p_platform text,p_mode text,p_max_players integer default 2)
returns jsonb language plpgsql security definer set search_path='' as $$
declare current_user_id uuid:=auth.uid(); new_room public.game_rooms%rowtype; new_code text;
begin
 if current_user_id is null then raise exception 'Debés iniciar sesión para crear una sala.'; end if;
 if nullif(trim(p_title),'') is null or nullif(trim(p_game),'') is null then raise exception 'Completá el nombre de la sala y el juego.'; end if;
 if p_max_players<2 or p_max_players>10 then raise exception 'La sala debe admitir entre 2 y 10 jugadores.'; end if;
 new_code:=upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
 insert into public.game_rooms(code,title,game,platform,mode,host_user_id,max_players,member_count,status)
 values(new_code,left(trim(p_title),60),left(trim(p_game),40),left(trim(p_platform),20),left(trim(p_mode),30),current_user_id,p_max_players,1,'open')
 returning * into new_room;
 insert into public.game_room_members(room_id,user_id) values(new_room.id,current_user_id);
 return jsonb_build_object('ok',true,'code',new_room.code,'room_id',new_room.id);
end; $$;

create or replace function private.join_game_room(p_room_code text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare current_user_id uuid:=auth.uid(); r public.game_rooms%rowtype;
begin
 if current_user_id is null then raise exception 'Debés iniciar sesión para unirte a una sala.'; end if;
 select * into r from public.game_rooms where code=upper(trim(p_room_code)) for update;
 if not found then raise exception 'No existe esa sala.'; end if;
 if r.status<>'open' or r.member_count>=r.max_players then raise exception 'La sala está completa o cerrada.'; end if;
 insert into public.game_room_members(room_id,user_id) values(r.id,current_user_id) on conflict do nothing;
 if not found then raise exception 'Ya estás dentro de esa sala.'; end if;
 update public.game_rooms set member_count=member_count+1,status=case when member_count+1>=max_players then 'full' else 'open' end where id=r.id;
 return jsonb_build_object('ok',true,'code',r.code,'members',r.member_count+1);
end; $$;

create or replace function private.join_tournament(p_tournament_code text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare t public.tournaments%rowtype; current_user_id uuid:=auth.uid();
begin
 if current_user_id is null then raise exception 'Debés iniciar sesión para inscribirte.'; end if;
 select * into t from public.tournaments where code=p_tournament_code for update;
 if not found then raise exception 'Torneo inexistente.'; end if;
 if t.status<>'open' or t.enrolled>=t.capacity then raise exception 'El torneo no tiene cupos disponibles.'; end if;
 insert into public.tournament_registrations(tournament_id,user_id) values(t.id,current_user_id)
 on conflict(tournament_id,user_id) do nothing;
 if not found then raise exception 'Ya estás inscripto en este torneo.'; end if;
 update public.tournaments set enrolled=enrolled+1,status=case when enrolled+1>=capacity then 'full' else 'open' end where id=t.id;
 return jsonb_build_object('ok',true,'registered',true,'message','Inscripción confirmada. El XP se acredita cuando se valide el resultado del torneo.');
end; $$;

create or replace function private.redeem_frame(p_frame_code text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare current_user_id uuid:=auth.uid(); f public.frame_catalog%rowtype;
begin
 if current_user_id is null then raise exception 'Debés iniciar sesión para canjear.'; end if;
 select * into f from public.frame_catalog where code=p_frame_code and active=true;
 if not found then raise exception 'Marco no disponible.'; end if;
 if exists(select 1 from public.frame_redemptions where frame_code=p_frame_code and user_id=current_user_id) then raise exception 'Ya canjeaste este marco.'; end if;
 update public.wallets set pf_coins=pf_coins-f.price_pf,updated_at=now() where user_id=current_user_id and pf_coins>=f.price_pf;
 if not found then raise exception 'No tenés suficientes monedas PF.'; end if;
 insert into public.frame_redemptions(frame_code,user_id) values(p_frame_code,current_user_id);
 insert into public.wallet_ledger(user_id,amount_pf,reason) values(current_user_id,-f.price_pf,'canje_marco:'||p_frame_code);
 return jsonb_build_object('ok',true,'spent_pf',f.price_pf);
end; $$;

create or replace function private.get_leaderboard()
returns table(rank_position bigint,username text,xp integer,rank_name text)
language sql stable security definer set search_path='' as $$
 select dense_rank() over(order by w.xp desc,p.username asc),p.username,w.xp,
 case when w.xp>=1750 then 'Leyenda' when w.xp>=1300 then 'Diamante' when w.xp>=900 then 'Platino'
 when w.xp>=550 then 'Oro' when w.xp>=250 then 'Plata' else 'Bronce' end
 from public.wallets w join public.profiles p on p.id=w.user_id
 order by w.xp desc,p.username asc limit 100;
$$;

create or replace function public.create_game_room(p_title text,p_game text,p_platform text,p_mode text,p_max_players integer default 2)
returns jsonb language sql security invoker set search_path='' as $$ select private.create_game_room($1,$2,$3,$4,$5); $$;
create or replace function public.join_game_room(p_room_code text)
returns jsonb language sql security invoker set search_path='' as $$ select private.join_game_room($1); $$;
create or replace function public.join_tournament(p_tournament_code text)
returns jsonb language sql security invoker set search_path='' as $$ select private.join_tournament($1); $$;
create or replace function public.redeem_frame(p_frame_code text)
returns jsonb language sql security invoker set search_path='' as $$ select private.redeem_frame($1); $$;
create or replace function public.get_leaderboard()
returns table(rank_position bigint,username text,xp integer,rank_name text)
language sql stable security invoker set search_path='' as $$ select * from private.get_leaderboard(); $$;

revoke all on function private.create_game_room(text,text,text,text,integer) from public,anon,authenticated;
revoke all on function private.join_game_room(text) from public,anon,authenticated;
revoke all on function private.join_tournament(text) from public,anon,authenticated;
revoke all on function private.redeem_frame(text) from public,anon,authenticated;
revoke all on function private.get_leaderboard() from public,anon,authenticated;
grant execute on function private.create_game_room(text,text,text,text,integer) to authenticated;
grant execute on function private.join_game_room(text) to authenticated;
grant execute on function private.join_tournament(text) to authenticated;
grant execute on function private.redeem_frame(text) to authenticated;
grant execute on function private.get_leaderboard() to anon,authenticated;

revoke all on function public.create_game_room(text,text,text,text,integer) from public,anon;
revoke all on function public.join_game_room(text) from public,anon;
revoke all on function public.join_tournament(text) from public,anon;
revoke all on function public.redeem_frame(text) from public,anon;
revoke all on function public.get_leaderboard() from public;
grant execute on function public.create_game_room(text,text,text,text,integer) to authenticated;
grant execute on function public.join_game_room(text) to authenticated;
grant execute on function public.join_tournament(text) to authenticated;
grant execute on function public.redeem_frame(text) to authenticated;
grant execute on function public.get_leaderboard() to anon,authenticated;
