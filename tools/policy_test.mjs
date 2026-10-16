// PostgreSQL policy regression tests. Auth/Storage schemas are minimal fixtures;
// run the manual two-device checklist too before publishing a real application.
import { PGlite } from '@electric-sql/pglite';
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';

const db = new PGlite();
let checks = 0;
const alice = '00000000-0000-0000-0000-000000000001';
const bob = '00000000-0000-0000-0000-000000000002';
const eve = '00000000-0000-0000-0000-000000000003';
const photoPath = `${alice}/today.jpg`;
const photoId = '00000000-0000-0000-0000-000000000004';
async function as(user) {
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claim.sub', $1, false)", [user]);
  await db.exec('set role authenticated');
}
async function ok(sql, values = []) { return db.query(sql, values); }
async function count(table) {
  return Number((await ok(`select count(*) as count from ${table}`)).rows[0].count);
}
async function denied(sql, values = []) {
  await assert.rejects(() => ok(sql, values)); checks++;
}
function equal(actual, expected, label) {
  assert.equal(actual, expected, label); checks++;
}
try {
  await db.exec(`
    create role anon nologin;
    create role authenticated nologin;
    create schema auth;
    create schema storage;
    create table auth.users(id uuid primary key, raw_user_meta_data jsonb not null);
    create function auth.uid() returns uuid language sql stable as
      $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
    create table storage.buckets(id text primary key, name text, public boolean,
      file_size_limit bigint, allowed_mime_types text[]);
    create table storage.objects(id uuid default gen_random_uuid(), bucket_id text, name text);
    create function storage.foldername(text) returns text[] language sql immutable as
      $$ select string_to_array($1, '/') $$;
    alter table storage.objects enable row level security;
    grant usage on schema auth, public, storage to authenticated, anon;
    grant select, insert, delete on storage.objects to authenticated;
    grant execute on function auth.uid(), storage.foldername(text) to authenticated, anon;
  `);
  await db.exec(await readFile(new URL('../supabase/migrations/202610160001_social.sql', import.meta.url), 'utf8'));
  await db.exec(await readFile(new URL('../supabase/migrations/202610160002_profiles.sql', import.meta.url), 'utf8'));
  await db.exec(await readFile(new URL('../supabase/migrations/202610160003_comments.sql', import.meta.url), 'utf8'));
  for (const [id, username] of [[alice, 'alice'], [bob, 'bob'], [eve, 'eve']]) {
    await ok('insert into auth.users values($1, $2::jsonb)', [id,
      JSON.stringify({username, display_name: username})]);
  }
  await as(alice);
  equal(await count('profiles'), 3, 'signup trigger creates profiles');
  await ok('select update_profile($1,$2,$3,$4)', ['  Alice mới  ', '  Hôm nay vui  ', '🌻', 2]);
  const updated = (await ok('select * from profiles where id=$1', [alice])).rows[0];
  equal(updated.display_name, 'Alice mới', 'profile name trimmed and saved');
  equal(updated.bio, 'Hôm nay vui', 'profile bio trimmed and saved');
  equal(updated.avatar_emoji, '🌻', 'profile emoji saved');
  equal(updated.avatar_color, 2, 'profile color saved');
  equal(updated.username, 'alice', 'profile update preserves username');
  equal((await ok('select display_name from profiles where id=$1', [bob])).rows[0].display_name, 'bob', 'other profile untouched');
  await denied('update profiles set display_name=$1 where id=$2', ['spoofed', bob]);
  await denied('select update_profile($1,$2,$3,$4)', ['', '', '', 0]);
  await denied('select update_profile($1,$2,$3,$4)', ['a'.repeat(41), '', '', 0]);
  await denied('select update_profile($1,$2,$3,$4)', ['Alice', 'a'.repeat(81), '', 0]);
  await denied('select update_profile($1,$2,$3,$4)', ['Alice', '', 'not-an-avatar', 0]);
  await denied('select update_profile($1,$2,$3,$4)', ['Alice', '', '', 99]);
  await ok("insert into storage.objects(bucket_id, name) values('moments', $1)", [photoPath]);
  await ok('insert into moments(id, author_id, image_path, caption) values($1,$2,$3,$4)',
    [photoId, alice, photoPath, 'Hôm nay']);
  equal(await count('moments'), 1, 'author sees own post');
  await denied("select send_friend_request('alice')");
  await denied("select send_friend_request('missing')");
  await ok("select send_friend_request('bob')");
  const requestId = (await ok('select id from friendships')).rows[0].id;
  await denied("select send_friend_request('bob')");
  await denied('select respond_friend_request($1, true)', [requestId]);
  await denied("update friendships set status = 'accepted'");

  await as(bob);
  equal(await count('moments'), 0, 'pending friend cannot read moments');
  equal(await count('storage.objects'), 0, 'pending friend cannot download photo');
  await denied("select send_friend_request('alice')");
  await denied('insert into reactions values($1,$2)', [photoId, bob]);
  await denied('insert into moments(author_id,image_path) values($1,$2)', [alice, photoPath]);
  await denied("insert into storage.objects(bucket_id,name) values('moments',$1)", [`${alice}/spoof.jpg`]);
  await denied('insert into moments(author_id,image_path) values($1,$2)', [bob, `${bob}/not-uploaded.jpg`]);
  await denied('select send_photo_comment($1,$2,null)', [photoId, 'pending']);
  await ok('select respond_friend_request($1, true)', [requestId]);
  await ok('select send_photo_comment($1,$2,null)', [photoId, '  Đẹp quá 😍  ']);
  const commentId = (await ok('select id from photo_comments')).rows[0].id;
  equal((await ok('select body from photo_comments')).rows[0].body, 'Đẹp quá 😍', 'comment trimmed with emoji');
  equal((await ok('select author_id from photo_comments')).rows[0].author_id, bob, 'server assigns comment author');
  await denied('insert into photo_comments(moment_id,author_id,body) values($1,$2,$3)', [photoId, alice, 'spoof']);
  await denied('select send_photo_comment($1,$2,null)', [photoId, '   ']);
  await denied('select send_photo_comment($1,$2,null)', [photoId, 'a'.repeat(501)]);
  await as(alice);
  await ok('select send_photo_comment($1,$2,$3)', [photoId, 'Cảm ơn ❤️', commentId]);
  equal(await count('photo_comments'), 2, 'owner replies to friend');
  const secondPath = `${alice}/second.jpg`;
  await ok("insert into storage.objects(bucket_id,name) values('moments',$1)", [secondPath]);
  const secondPhoto = (await ok('insert into moments(author_id,image_path) values($1,$2) returning id', [alice, secondPath])).rows[0].id;
  await denied('select send_photo_comment($1,$2,$3)', [secondPhoto, 'wrong photo', commentId]);
  await ok('delete from moments where id=$1', [secondPhoto]);
  await ok('delete from storage.objects where name=$1', [secondPath]);
  await as(bob);
  equal(await count('moments'), 1, 'accepted friend sees posts');
  equal(await count('storage.objects'), 1, 'accepted friend reads private photo');
  await ok('insert into reactions values($1,$2)', [photoId, bob]);
  equal(await count('reactions'), 1, 'friend can react');
  await denied('insert into reactions values($1,$2)', [photoId, alice]);
  await ok('delete from moments where id=$1', [photoId]);
  equal(await count('moments'), 1, 'friend cannot delete author post');

  await as(eve);
  equal(await count('photo_comments'), 0, 'stranger cannot read comments');
  await denied('select send_photo_comment($1,$2,null)', [photoId, 'stranger']);
  equal(await count('moments'), 0, 'stranger cannot read post');
  equal(await count('storage.objects'), 0, 'stranger cannot read storage');
  equal(await count('friendships'), 0, 'stranger cannot see friendship');
  equal(await count('reactions'), 0, 'stranger cannot read reactions');
  await denied('select respond_friend_request($1, true)', [requestId]);
  await denied('select remove_friendship($1)', [requestId]);

  await as(bob);
  await ok('select remove_friendship($1)', [requestId]);
  equal(await count('photo_comments'), 0, 'unfriend revokes comments');
  await denied('select send_photo_comment($1,$2,null)', [photoId, 'unfriended']);
  equal(await count('moments'), 0, 'unfriend revokes posts');
  equal(await count('storage.objects'), 0, 'unfriend revokes photo requests');
  equal(await count('reactions'), 0, 'unfriend revokes reaction reads');
  await denied('insert into reactions values($1,$2)', [photoId, bob]);
  await ok("select send_friend_request('alice')");
  const reverse = (await ok('select id from friendships')).rows[0].id;
  await as(alice);
  await ok('select respond_friend_request($1, false)', [reverse]);
  equal(await count('friendships'), 0, 'decline removes request');
  await ok("select send_friend_request('bob')");
  const cancelled = (await ok('select id from friendships')).rows[0].id;
  await ok('select remove_friendship($1)', [cancelled]);
  equal(await count('friendships'), 0, 'sender can cancel');
  await ok('delete from moments where id=$1', [photoId]);
  equal(await count('photo_comments'), 0, 'photo deletion cascades comments and replies');
  equal(await count('moments'), 0, 'owner can delete moment');
  equal(await count('reactions'), 0, 'deletion cascades reactions');
  await ok("delete from storage.objects where name=$1", [photoPath]);
  equal(await count('storage.objects'), 0, 'owner can clean up deleted photo');

  await db.exec('reset role; set role anon');
  await denied("select update_profile('stranger', '', '', 0)");
  await denied('select * from photo_comments');
  await denied('select send_photo_comment($1,$2,null)', [photoId, 'anonymous']);
  await denied('select * from moments');
  await denied("select send_friend_request('bob')");
  console.log(`Passed ${checks} PostgreSQL authorization assertions.`);
} finally {
  await db.close();
}
