begin;

select plan(13);

select ok(
  (select relrowsecurity from pg_class where oid = 'public.profiles'::regclass),
  'profiles has row level security enabled'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.posts'::regclass),
  'posts has row level security enabled'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.favorites'::regclass),
  'favorites has row level security enabled'
);
select ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
      and policyname = 'Allow public read access for profiles'
  ),
  'guest profile read policy exists'
);
select ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'posts'
      and policyname = 'Allow visible profile posts to be read'
  ),
  'visible post read policy exists'
);
select ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'posts'
      and policyname = 'Allow authenticated users to insert posts'
  ),
  'authenticated post insert policy exists'
);
select ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'favorites'
      and policyname = 'Allow authenticated users to insert/delete favorites'
  ),
  'authenticated favorite policy exists'
);

set local role anon;
select ok(
  (select count(*) >= 0 from public.profiles),
  'guest can select public profiles'
);
select throws_ok(
  $$insert into public.posts (profile_id, book_id, rating, comment)
    values ('d3b07384-d113-4ec5-a587-f3e098a58f4a', 'rls-test', 3, 'rls-test')$$,
  '42501',
  'guest cannot insert posts'
);
select throws_ok(
  $$insert into public.favorites (profile_id, book_id)
    values ('d3b07384-d113-4ec5-a587-f3e098a58f4a', 'rls-test')$$,
  '42501',
  'guest cannot insert favorites'
);
set local role postgres;

select ok(
  (select prosecdef from pg_proc where oid = 'public.is_current_user_admin()'::regprocedure),
  'admin check function is security definer'
);
select ok(
  not has_function_privilege('anon', 'public.admin_delete_reported_post(bigint)', 'execute'),
  'anon cannot execute admin post deletion RPC'
);
select ok(
  has_function_privilege('authenticated', 'public.admin_delete_reported_post(bigint)', 'execute'),
  'authenticated users reach the admin RPC authorization check'
);

select * from finish();
rollback;
