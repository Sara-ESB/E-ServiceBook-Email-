create table profiles(id uuid primary key references auth.users on delete cascade,name text,username text,role text not null default 'user' check(role in('user','admin','super')),status text not null default 'active' check(status in('active','banned')),created_at timestamptz default now());
create table contacts(id bigint generated always as identity primary key,name text,email text unique,phone text,company text,category text not null default 'Uncategorized',unsubscribed boolean not null default false,created_by uuid default auth.uid(),created_at timestamptz default now());
create table messages(id bigint generated always as identity primary key,channel text not null default 'email',direction text not null default 'out',to_addr text,name text,category text default 'Uncategorized',from_addr text,subject text,body text,btn_text text,btn_link text,status text not null default 'queued',send_at timestamptz default now(),sent_at timestamptz,error text,attempts int default 0,created_by uuid default auth.uid(),created_at timestamptz default now());
create index on messages(status,channel,send_at);
create table activity_log(id bigint generated always as identity primary key,at timestamptz default now(),username text,action text);
create function my_role() returns text language sql stable security definer set search_path=public as $$ select role from profiles where id=auth.uid() and status='active' $$;
create function handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
declare u text:=lower(coalesce(new.raw_user_meta_data->>'username',split_part(new.email,'@',1)));
begin if u='supreme-admin' then u:=split_part(new.email,'@',1); end if;
insert into profiles(id,name,username) values(new.id,coalesce(new.raw_user_meta_data->>'name','User'),u); return new; end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function handle_new_user();
alter table profiles enable row level security;alter table contacts enable row level security;alter table messages enable row level security;alter table activity_log enable row level security;
create policy p_sel on profiles for select to authenticated using(id=auth.uid() or my_role() in('admin','super'));
create policy c_sel on contacts for select to authenticated using(my_role() is not null);
create policy c_ins on contacts for insert to authenticated with check(my_role() is not null);
create policy c_upd on contacts for update to authenticated using(my_role() is not null);
create policy c_del on contacts for delete to authenticated using(my_role() in('admin','super'));
create policy m_sel on messages for select to authenticated using(my_role() is not null and (created_by=auth.uid() or my_role() in('admin','super')));
create policy m_upd on messages for update to authenticated using(my_role() is not null and (created_by=auth.uid() or my_role() in('admin','super')));
create policy l_sel on activity_log for select to authenticated using(my_role() in('admin','super'));
create function log_action(a text) returns void language sql security definer set search_path=public as $$
insert into activity_log(username,action) select username,a from profiles where id=auth.uid() and status='active' $$;
create function queue_messages(rows jsonb) returns int language plpgsql security definer set search_path=public as $$
declare r text:=my_role(); n int:=jsonb_array_length(rows);
begin
 if r is null then raise exception 'Not allowed'; end if;
 if n>1 and r='user' then raise exception 'Bulk sending needs an admin account'; end if;
 insert into messages(channel,to_addr,name,category,from_addr,subject,body,btn_text,btn_link,send_at,status,created_by)
 select coalesce(x->>'channel','email'),x->>'to_addr',x->>'name',coalesce(x->>'category','Uncategorized'),x->>'from_addr',x->>'subject',x->>'body',x->>'btn_text',x->>'btn_link',coalesce((x->>'send_at')::timestamptz,now()),'queued',auth.uid() from jsonb_array_elements(rows) x;
 perform log_action('Queued '||n||' '||coalesce(rows->0->>'channel','email')||' message(s)');
 return n; end $$;
create function set_role(uid uuid,new_role text) returns void language plpgsql security definer set search_path=public as $$
begin if my_role()<>'super' then raise exception 'Only the owner can change roles'; end if;
 if new_role not in('user','admin') then raise exception 'Bad role'; end if;
 update profiles set role=new_role where id=uid and role<>'super'; perform log_action('Set role of '||uid||' to '||new_role); end $$;
create function set_status(uid uuid,new_status text) returns void language plpgsql security definer set search_path=public as $$
declare r text:=my_role();
begin if r is null or r='user' then raise exception 'Not allowed'; end if;
 if new_status='banned' and r<>'super' then raise exception 'Only the owner can ban accounts'; end if;
 if new_status not in('active','banned') then raise exception 'Bad status'; end if;
 update profiles set status=new_status where id=uid and role<>'super'; perform log_action(case when new_status='banned' then 'Banned ' else 'Reactivated ' end||uid); end $$;
