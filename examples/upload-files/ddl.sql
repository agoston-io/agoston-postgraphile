create table agoston_public.post (
  id serial primary key,
  headline text,
  body text,
  header_image_file jsonb
);
comment on column post.header_image_file is E'@upload';

grant all on post to authenticated;
grant all on post to anonymous;
grant all on sequence post_id_seq to authenticated;
grant all on sequence post_id_seq to anonymous;

