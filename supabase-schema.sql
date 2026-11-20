create table if not exists public.fontaine_profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  saved_ids text[] not null default '{}',
  recent jsonb not null default '[]'::jsonb,
  list_statuses jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.fontaine_profiles
  add column if not exists list_statuses jsonb not null default '{}'::jsonb;

create table if not exists public.fontaine_community_profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  username text,
  username_font text not null default 'default',
  avatar_url text,
  banner_url text,
  updated_at timestamptz not null default now(),
  constraint fontaine_community_username_format
    check (username is null or username ~ '^[A-Za-z0-9_]{3,20}$'),
  constraint fontaine_community_username_font
    check (username_font in ('default', 'bookish', 'mono', 'rounded', 'vampyr'))
);

alter table public.fontaine_community_profiles
  drop constraint if exists fontaine_community_username_font;

alter table public.fontaine_community_profiles
  add constraint fontaine_community_username_font
  check (username_font in ('default', 'bookish', 'mono', 'rounded', 'vampyr'));

alter table public.fontaine_community_profiles
  add column if not exists banner_url text,
  add column if not exists username_color text not null default '#f1f5fb',
  add column if not exists username_color_end text,
  add column if not exists username_badge text;

alter table public.fontaine_community_profiles
  drop constraint if exists fontaine_community_username_color,
  drop constraint if exists fontaine_community_username_color_end;

alter table public.fontaine_community_profiles
  add constraint fontaine_community_username_color
    check (username_color ~ '^#[0-9A-Fa-f]{6}$'),
  add constraint fontaine_community_username_color_end
    check (username_color_end is null or username_color_end ~ '^#[0-9A-Fa-f]{6}$');

alter table public.fontaine_community_profiles
  drop constraint if exists fontaine_community_username_badge;

alter table public.fontaine_community_profiles
  add constraint fontaine_community_username_badge
    check (username_badge is null or username_badge in ('newbie', 'starlight', 'comet', 'royal', 'owner'));

create unique index if not exists fontaine_community_username_unique
  on public.fontaine_community_profiles (lower(username))
  where username is not null;

grant select on public.fontaine_community_profiles to anon, authenticated;
grant insert, update on public.fontaine_community_profiles to authenticated;

alter table public.fontaine_community_profiles enable row level security;

drop policy if exists "Anyone can view Fontaine community profiles" on public.fontaine_community_profiles;
create policy "Anyone can view Fontaine community profiles"
  on public.fontaine_community_profiles for select to anon, authenticated
  using (true);

drop policy if exists "Users create their own Fontaine community profile" on public.fontaine_community_profiles;
create policy "Users create their own Fontaine community profile"
  on public.fontaine_community_profiles for insert to authenticated
  with check (
    auth.uid() = user_id and
    (username_badge is distinct from 'owner' or lower(coalesce(auth.jwt() ->> 'email', '')) = 'bloodshot.1002@gmail.com')
  );

drop policy if exists "Users update their own Fontaine community profile" on public.fontaine_community_profiles;
create policy "Users update their own Fontaine community profile"
  on public.fontaine_community_profiles for update to authenticated
  using (auth.uid() = user_id)
  with check (
    auth.uid() = user_id and
    (username_badge is distinct from 'owner' or lower(coalesce(auth.jwt() ->> 'email', '')) = 'bloodshot.1002@gmail.com')
  );

insert into public.fontaine_community_profiles (user_id, username_badge)
select id, 'owner'
from auth.users
where lower(email) = 'bloodshot.1002@gmail.com'
on conflict (user_id) do update
set username_badge = 'owner', updated_at = now();

create table if not exists public.fontaine_credit_accounts (
  user_id uuid primary key references auth.users (id) on delete cascade,
  balance integer not null default 0 check (balance >= 0),
  claimed_on date,
  last_work_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.fontaine_credit_accounts
  add column if not exists last_work_at timestamptz;

grant select, insert, update on public.fontaine_credit_accounts to authenticated;

alter table public.fontaine_credit_accounts enable row level security;

drop policy if exists "Users read their own Fontaine Credits" on public.fontaine_credit_accounts;
create policy "Users read their own Fontaine Credits"
  on public.fontaine_credit_accounts for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users create their own Fontaine Credits" on public.fontaine_credit_accounts;
create policy "Users create their own Fontaine Credits"
  on public.fontaine_credit_accounts for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users update their own Fontaine Credits" on public.fontaine_credit_accounts;
create policy "Users update their own Fontaine Credits"
  on public.fontaine_credit_accounts for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create table if not exists public.fontaine_economy_cooldowns (
  user_id uuid primary key references auth.users (id) on delete cascade,
  last_heist_at timestamptz not null default now()
);

alter table public.fontaine_economy_cooldowns enable row level security;

create table if not exists public.fontaine_community_posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 2000),
  title_id text,
  source_comment_id uuid,
  created_at timestamptz not null default now()
);

alter table public.fontaine_community_posts
  add column if not exists title_id text,
  add column if not exists source_comment_id uuid;

create index if not exists fontaine_community_posts_created
  on public.fontaine_community_posts (created_at desc);

create unique index if not exists fontaine_community_posts_source_comment_unique
  on public.fontaine_community_posts (source_comment_id)
  where source_comment_id is not null;

grant select on public.fontaine_community_posts to anon, authenticated;
grant insert on public.fontaine_community_posts to authenticated;

alter table public.fontaine_community_posts enable row level security;

drop policy if exists "Anyone can view Fontaine community posts" on public.fontaine_community_posts;
create policy "Anyone can view Fontaine community posts"
  on public.fontaine_community_posts for select to anon, authenticated
  using (true);

drop policy if exists "Users create their own Fontaine community posts" on public.fontaine_community_posts;
create policy "Users create their own Fontaine community posts"
  on public.fontaine_community_posts for insert to authenticated
  with check (auth.uid() = user_id);

create table if not exists public.fontaine_community_chat (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 2000),
  attachment_url text,
  attachment_name text,
  attachment_type text,
  created_at timestamptz not null default now()
);

alter table public.fontaine_community_chat
  add column if not exists attachment_url text,
  add column if not exists attachment_name text,
  add column if not exists attachment_type text;

create index if not exists fontaine_community_chat_created
  on public.fontaine_community_chat (created_at desc);

grant select on public.fontaine_community_chat to anon, authenticated;
grant insert on public.fontaine_community_chat to authenticated;

alter table public.fontaine_community_chat enable row level security;

drop policy if exists "Anyone can view Fontaine community chat" on public.fontaine_community_chat;
create policy "Anyone can view Fontaine community chat"
  on public.fontaine_community_chat for select to anon, authenticated
  using (true);

drop policy if exists "Users create their own Fontaine community chat messages" on public.fontaine_community_chat;
create policy "Users create their own Fontaine community chat messages"
  on public.fontaine_community_chat for insert to authenticated
  with check (auth.uid() = user_id);

create table if not exists public.fontaine_economy_chat (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users (id) on delete set null,
  body text not null check (char_length(btrim(body)) between 1 and 2000),
  message_type text not null default 'message' check (message_type in ('message', 'action')),
  created_at timestamptz not null default now()
);

create index if not exists fontaine_economy_chat_created
  on public.fontaine_economy_chat (created_at desc);

grant select on public.fontaine_economy_chat to anon, authenticated;

alter table public.fontaine_economy_chat enable row level security;

drop policy if exists "Anyone can view Fontaine economy chat" on public.fontaine_economy_chat;
create policy "Anyone can view Fontaine economy chat"
  on public.fontaine_economy_chat for select to anon, authenticated
  using (true);

create table if not exists public.fontaine_economy_items (
  item_id text primary key,
  name text not null,
  price integer not null check (price >= 0),
  item_type text not null check (item_type in ('theme', 'font', 'badge', 'usernameGradient'))
);

insert into public.fontaine_economy_items (item_id, name, price, item_type) values
  ('theme-lumen', 'Original Lumen theme', 100, 'theme'),
  ('theme-violet', 'Midnight Violet theme', 150, 'theme'),
  ('font-vampyr', 'Vampyr title font', 200, 'font'),
  ('font-serif', 'Classic Serif title font', 125, 'font'),
  ('badge-starlight', 'Starlight badge', 120, 'badge'),
  ('badge-comet', 'Comet badge', 160, 'badge'),
  ('badge-royal', 'Royal badge', 220, 'badge'),
  ('username-gradient-aurora', 'Aurora name gradient', 250, 'usernameGradient')
on conflict (item_id) do update set name = excluded.name, price = excluded.price, item_type = excluded.item_type;

create table if not exists public.fontaine_economy_inventory (
  user_id uuid not null references auth.users (id) on delete cascade,
  item_id text not null references public.fontaine_economy_items (item_id),
  purchased_at timestamptz not null default now(),
  primary key (user_id, item_id)
);

grant select on public.fontaine_economy_inventory to authenticated;

alter table public.fontaine_economy_inventory enable row level security;

drop policy if exists "Users read their own Fontaine economy inventory" on public.fontaine_economy_inventory;
create policy "Users read their own Fontaine economy inventory"
  on public.fontaine_economy_inventory for select to authenticated
  using (auth.uid() = user_id);

create or replace function public.fontaine_economy_command(p_command text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_username text;
  v_command text := pg_catalog.btrim(coalesce(p_command, ''));
  v_action text;
  v_arg text;
  v_message text;
  v_balance integer := 0;
  v_amount integer := 0;
  v_reward integer := 0;
  v_payout integer := 0;
  v_chance numeric := 0;
  v_target_id uuid;
  v_target_name text;
  v_target_balance integer := 0;
  v_item public.fontaine_economy_items%rowtype;
begin
  if v_user_id is null then
    raise exception 'Sign in to use the community economy.';
  end if;
  if pg_catalog.char_length(v_command) < 1 or pg_catalog.char_length(v_command) > 500 then
    raise exception 'Messages must be between 1 and 500 characters.';
  end if;

  select coalesce(nullif(username, ''), 'Fontaine member')
    into v_username
    from public.fontaine_community_profiles
    where user_id = v_user_id;
  v_username := coalesce(v_username, 'Fontaine member');

  insert into public.fontaine_credit_accounts (user_id, balance)
    values (v_user_id, 0)
    on conflict (user_id) do nothing;
  select balance into v_balance
    from public.fontaine_credit_accounts where user_id = v_user_id;

  v_action := pg_catalog.lower(pg_catalog.split_part(v_command, ' ', 1));
  v_arg := pg_catalog.btrim(pg_catalog.substr(v_command, pg_catalog.char_length(v_action) + 1));

  if pg_catalog.left(v_command, 1) <> '/' then
    insert into public.fontaine_economy_chat (user_id, body, message_type)
      values (v_user_id, v_command, 'message');
    return pg_catalog.jsonb_build_object('message', v_command, 'balance', v_balance);
  end if;

  if v_action = '/help' then
    v_message := '/work · /gamble amount · /rob username · /steal username · /shoot username · /buy item-id. Shooting is only a harmless paintball-style game.';
  elsif v_action = '/work' then
    select balance into v_balance
      from public.fontaine_credit_accounts where user_id = v_user_id for update;
    if exists (select 1 from public.fontaine_credit_accounts where user_id = v_user_id and last_work_at > now() - interval '30 seconds') then
      raise exception 'You can work again in a few seconds.';
    end if;
    v_reward := 8 + pg_catalog.floor(pg_catalog.random() * 33)::integer;
    update public.fontaine_credit_accounts set balance = balance + v_reward, last_work_at = now(), updated_at = now()
      where user_id = v_user_id returning balance into v_balance;
    v_message := v_username || ' worked a shift and earned ' || v_reward || ' Credits.';
  elsif v_action = '/gamble' then
    if v_arg !~ '^[0-9]{1,4}$' then raise exception 'Usage: /gamble amount (1–1000 Credits).'; end if;
    v_amount := v_arg::integer;
    if v_amount < 1 or v_amount > 1000 then raise exception 'Gamble between 1 and 1,000 Credits.'; end if;
    select balance into v_balance from public.fontaine_credit_accounts where user_id = v_user_id for update;
    if v_balance < v_amount then raise exception 'Not enough Credits for that wager.'; end if;
    if pg_catalog.random() < 0.06 then v_payout := v_amount * 5;
    elsif pg_catalog.random() < 0.50 then v_payout := v_amount * 2;
    else v_payout := 0; end if;
    update public.fontaine_credit_accounts set balance = balance - v_amount + v_payout, updated_at = now()
      where user_id = v_user_id returning balance into v_balance;
    v_message := case when v_payout = v_amount * 5 then v_username || ' hit a jackpot and won ' || v_payout || ' Credits!'
      when v_payout > 0 then v_username || ' won ' || v_payout || ' Credits.'
      else v_username || ' lost the ' || v_amount || ' Credit wager.' end;
  elsif v_action in ('/rob', '/steal', '/shoot') then
    if v_arg = '' or pg_catalog.char_length(v_arg) > 20 then raise exception 'Name a community username.'; end if;
    select user_id, coalesce(nullif(username, ''), 'Fontaine member')
      into v_target_id, v_target_name
      from public.fontaine_community_profiles
      where pg_catalog.lower(username) = pg_catalog.lower(pg_catalog.regexp_replace(v_arg, '^@', ''));
    if v_target_id is null then raise exception 'That community username was not found.'; end if;
    if v_target_id = v_user_id then raise exception 'Choose another player.'; end if;
    insert into public.fontaine_credit_accounts (user_id, balance)
      values (v_target_id, 0)
      on conflict (user_id) do nothing;
    perform user_id from public.fontaine_credit_accounts
      where user_id in (v_user_id, v_target_id) order by user_id for update;
    select balance into v_balance from public.fontaine_credit_accounts where user_id = v_user_id;
    select balance into v_target_balance from public.fontaine_credit_accounts where user_id = v_target_id;
    if v_action in ('/rob', '/steal') then
      if exists (select 1 from public.fontaine_economy_cooldowns where user_id = v_user_id and last_heist_at > now() - interval '45 seconds') then
        raise exception 'Wait a little before another heist.';
      end if;
      insert into public.fontaine_economy_cooldowns (user_id, last_heist_at) values (v_user_id, now())
        on conflict (user_id) do update set last_heist_at = excluded.last_heist_at;
      v_chance := case when v_action = '/rob' then 0.38 else 0.52 end;
      if pg_catalog.random() < v_chance and v_target_balance > 0 then
        v_reward := least(v_target_balance, case when v_action = '/rob' then greatest(1, pg_catalog.floor(pg_catalog.random() * 30 + 5)::integer) else greatest(1, pg_catalog.floor(pg_catalog.random() * 12 + 2)::integer) end);
        update public.fontaine_credit_accounts set balance = balance - v_reward, updated_at = now() where user_id = v_target_id;
        update public.fontaine_credit_accounts set balance = balance + v_reward, updated_at = now() where user_id = v_user_id returning balance into v_balance;
        v_message := v_username || ' pulled off a fictional ' || case when v_action = '/rob' then 'heist' else 'pickpocket' end || ' on ' || v_target_name || ' and took ' || v_reward || ' Credits.';
      else
        v_reward := least(v_balance, 2 + pg_catalog.floor(pg_catalog.random() * 9)::integer);
        update public.fontaine_credit_accounts set balance = balance - v_reward, updated_at = now() where user_id = v_user_id returning balance into v_balance;
        update public.fontaine_credit_accounts set balance = balance + v_reward, updated_at = now() where user_id = v_target_id;
        v_message := v_username || ' was caught trying a fictional heist on ' || v_target_name || ' and paid ' || v_reward || ' Credits.';
      end if;
    else
      if pg_catalog.random() < 0.5 then
        v_reward := 3 + pg_catalog.floor(pg_catalog.random() * 13)::integer;
        update public.fontaine_credit_accounts set balance = balance + v_reward, updated_at = now() where user_id = v_user_id returning balance into v_balance;
        v_message := v_username || ' won a harmless paintball tag duel with ' || v_target_name || ' and earned ' || v_reward || ' Credits.';
      else
        v_reward := 2 + pg_catalog.floor(pg_catalog.random() * 9)::integer;
        update public.fontaine_credit_accounts set balance = balance + v_reward, updated_at = now() where user_id = v_target_id;
        v_message := v_username || ' was tagged in a paintball duel by ' || v_target_name || '. ' || v_target_name || ' earned ' || v_reward || ' Credits.';
      end if;
    end if;
  elsif v_action = '/buy' then
    if v_arg = '' then raise exception 'Usage: /buy item-id. Browse the Shop for item IDs.'; end if;
    select * into v_item from public.fontaine_economy_items where item_id = v_arg;
    if not found then raise exception 'That item is not in the Shop.'; end if;
    select balance into v_balance from public.fontaine_credit_accounts where user_id = v_user_id for update;
    if exists (select 1 from public.fontaine_economy_inventory where user_id = v_user_id and item_id = v_item.item_id) then
      raise exception 'You already own that item.';
    end if;
    if v_balance < v_item.price then raise exception 'Insufficient Credits for that item.'; end if;
    update public.fontaine_credit_accounts set balance = balance - v_item.price, updated_at = now()
      where user_id = v_user_id returning balance into v_balance;
    insert into public.fontaine_economy_inventory (user_id, item_id) values (v_user_id, v_item.item_id);
    if v_item.item_type = 'badge' then
      insert into public.fontaine_community_profiles (user_id, username_badge)
        values (v_user_id, pg_catalog.replace(v_item.item_id, 'badge-', ''))
        on conflict (user_id) do update set username_badge = excluded.username_badge, updated_at = now();
    elsif v_item.item_type = 'usernameGradient' then
      insert into public.fontaine_community_profiles (user_id, username_color, username_color_end)
        values (v_user_id, '#47e8d2', '#8b5cf6')
        on conflict (user_id) do update set username_color = excluded.username_color, username_color_end = excluded.username_color_end, updated_at = now();
    end if;
    v_message := v_username || ' bought ' || v_item.name || ' from the Shop.';
  else
    raise exception 'Unknown command. Type /help to see available commands.';
  end if;

  insert into public.fontaine_economy_chat (user_id, body, message_type)
    values (v_user_id, v_message, 'action');
  return pg_catalog.jsonb_build_object('message', v_message, 'balance', v_balance);
end;
$$;

revoke all on function public.fontaine_economy_command(text) from public, anon;
grant execute on function public.fontaine_economy_command(text) to authenticated;

create table if not exists public.fontaine_stream_sources (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 1 and 16),
  section text not null check (section in ('hentai', 'anime', 'movies', 'live')),
  endpoint_template text not null check (char_length(endpoint_template) between 1 and 2000),
  created_by uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

grant select on public.fontaine_stream_sources to anon, authenticated;
grant insert, update, delete on public.fontaine_stream_sources to authenticated;

alter table public.fontaine_stream_sources enable row level security;

drop policy if exists "Anyone can view Fontaine stream sources" on public.fontaine_stream_sources;
create policy "Anyone can view Fontaine stream sources"
  on public.fontaine_stream_sources for select to anon, authenticated
  using (true);

drop policy if exists "Fontaine admin creates stream sources" on public.fontaine_stream_sources;
create policy "Fontaine admin creates stream sources"
  on public.fontaine_stream_sources for insert to authenticated
  with check (lower(coalesce(auth.jwt() ->> 'email', '')) = 'bloodshot.1002@gmail.com' and auth.uid() = created_by);

drop policy if exists "Fontaine admin updates stream sources" on public.fontaine_stream_sources;
create policy "Fontaine admin updates stream sources"
  on public.fontaine_stream_sources for update to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'bloodshot.1002@gmail.com')
  with check (lower(coalesce(auth.jwt() ->> 'email', '')) = 'bloodshot.1002@gmail.com');

drop policy if exists "Fontaine admin deletes stream sources" on public.fontaine_stream_sources;
create policy "Fontaine admin deletes stream sources"
  on public.fontaine_stream_sources for delete to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'bloodshot.1002@gmail.com');

create table if not exists public.fontaine_title_comments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title_id text not null check (char_length(title_id) between 1 and 160),
  body text not null check (char_length(btrim(body)) between 1 and 2000),
  created_at timestamptz not null default now()
);

create index if not exists fontaine_title_comments_title_created
  on public.fontaine_title_comments (title_id, created_at);

grant select on public.fontaine_title_comments to anon, authenticated;
grant insert on public.fontaine_title_comments to authenticated;

alter table public.fontaine_title_comments enable row level security;

drop policy if exists "Anyone can view Fontaine title comments" on public.fontaine_title_comments;
create policy "Anyone can view Fontaine title comments"
  on public.fontaine_title_comments for select to anon, authenticated
  using (true);

drop policy if exists "Users create their own Fontaine title comments" on public.fontaine_title_comments;
create policy "Users create their own Fontaine title comments"
  on public.fontaine_title_comments for insert to authenticated
  with check (auth.uid() = user_id);

insert into public.fontaine_community_posts (user_id, body, title_id, source_comment_id, created_at)
select comments.user_id, comments.body, comments.title_id, comments.id, comments.created_at
from public.fontaine_title_comments as comments
on conflict (source_comment_id) where source_comment_id is not null do nothing;

create or replace function public.fontaine_manage_community_message(
  p_channel text,
  p_message_id uuid,
  p_action text,
  p_body text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then raise exception 'Sign in to manage your messages.'; end if;
  if p_action is null or p_action not in ('edit', 'delete') then raise exception 'Unsupported message action.'; end if;
  if p_action = 'edit' and (p_body is null or pg_catalog.char_length(pg_catalog.btrim(p_body)) not between 1 and 2000) then
    raise exception 'Messages must be between 1 and 2,000 characters.';
  end if;

  if p_channel = 'feed' then
    if p_action = 'edit' then
      update public.fontaine_community_posts
      set body = pg_catalog.btrim(p_body)
      where id = p_message_id and user_id = v_user_id;
    else
      delete from public.fontaine_community_posts
      where id = p_message_id and user_id = v_user_id;
    end if;
  elsif p_channel = 'chat' then
    if p_action = 'edit' then
      update public.fontaine_community_chat
      set body = pg_catalog.btrim(p_body)
      where id = p_message_id and user_id = v_user_id;
    else
      delete from public.fontaine_community_chat
      where id = p_message_id and user_id = v_user_id;
    end if;
  elsif p_channel = 'title' then
    if p_action = 'edit' then
      update public.fontaine_title_comments
      set body = pg_catalog.btrim(p_body)
      where id = p_message_id and user_id = v_user_id;
      if not found then raise exception 'Message not found or you do not own it.'; end if;
      update public.fontaine_community_posts
      set body = pg_catalog.btrim(p_body)
      where source_comment_id = p_message_id and user_id = v_user_id;
    else
      delete from public.fontaine_title_comments
      where id = p_message_id and user_id = v_user_id;
      if not found then raise exception 'Message not found or you do not own it.'; end if;
      delete from public.fontaine_community_posts
      where source_comment_id = p_message_id and user_id = v_user_id;
    end if;
  else
    raise exception 'Unsupported community channel.';
  end if;

  if p_channel <> 'title' and not found then raise exception 'Message not found or you do not own it.'; end if;
  return pg_catalog.jsonb_build_object('ok', true, 'action', p_action);
end;
$$;

revoke all on function public.fontaine_manage_community_message(text, uuid, text, text) from public, anon;
grant execute on function public.fontaine_manage_community_message(text, uuid, text, text) to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('fontaine-avatars', 'fontaine-avatars', true, 3145728, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = true, file_size_limit = 3145728, allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('fontaine-banners', 'fontaine-banners', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = true, file_size_limit = 5242880, allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('fontaine-chat-files', 'fontaine-chat-files', true, 10485760, array['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'video/mp4', 'video/webm', 'application/pdf'])
on conflict (id) do update
  set public = true, file_size_limit = 10485760,
      allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'video/mp4', 'video/webm', 'application/pdf'];

drop policy if exists "Anyone can view Fontaine avatars" on storage.objects;
create policy "Anyone can view Fontaine avatars"
  on storage.objects for select to anon, authenticated
  using (bucket_id = 'fontaine-avatars');

drop policy if exists "Users upload their own Fontaine avatar" on storage.objects;
create policy "Users upload their own Fontaine avatar"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'fontaine-avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "Users update their own Fontaine avatar" on storage.objects;
create policy "Users update their own Fontaine avatar"
  on storage.objects for update to authenticated
  using (bucket_id = 'fontaine-avatars' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'fontaine-avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "Users delete their own Fontaine avatar" on storage.objects;
create policy "Users delete their own Fontaine avatar"
  on storage.objects for delete to authenticated
  using (bucket_id = 'fontaine-avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "Anyone can view Fontaine banners" on storage.objects;
create policy "Anyone can view Fontaine banners"
  on storage.objects for select to anon, authenticated
  using (bucket_id = 'fontaine-banners');

drop policy if exists "Users upload their own Fontaine banners" on storage.objects;
create policy "Users upload their own Fontaine banners"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'fontaine-banners' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "Users update their own Fontaine banners" on storage.objects;
create policy "Users update their own Fontaine banners"
  on storage.objects for update to authenticated
  using (bucket_id = 'fontaine-banners' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'fontaine-banners' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "Users delete their own Fontaine banners" on storage.objects;
create policy "Users delete their own Fontaine banners"
  on storage.objects for delete to authenticated
  using (bucket_id = 'fontaine-banners' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "Anyone can view Fontaine chat files" on storage.objects;
create policy "Anyone can view Fontaine chat files"
  on storage.objects for select to anon, authenticated
  using (bucket_id = 'fontaine-chat-files');

drop policy if exists "Users upload their own Fontaine chat files" on storage.objects;
create policy "Users upload their own Fontaine chat files"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'fontaine-chat-files' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "Users delete their own Fontaine chat files" on storage.objects;
create policy "Users delete their own Fontaine chat files"
  on storage.objects for delete to authenticated
  using (bucket_id = 'fontaine-chat-files' and (storage.foldername(name))[1] = auth.uid()::text);

grant select, insert, update on public.fontaine_profiles to authenticated;

alter table public.fontaine_profiles enable row level security;

drop policy if exists "Users read their own Fontaine profile" on public.fontaine_profiles;
create policy "Users read their own Fontaine profile"
  on public.fontaine_profiles for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users create their own Fontaine profile" on public.fontaine_profiles;
create policy "Users create their own Fontaine profile"
  on public.fontaine_profiles for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users update their own Fontaine profile" on public.fontaine_profiles;
create policy "Users update their own Fontaine profile"
  on public.fontaine_profiles for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create or replace function public.delete_my_fontaine_account()
returns void
language sql
security definer
set search_path = ''
as $$
  delete from auth.users where id = (select auth.uid());
$$;

revoke all on function public.delete_my_fontaine_account() from public, anon;
grant execute on function public.delete_my_fontaine_account() to authenticated;
