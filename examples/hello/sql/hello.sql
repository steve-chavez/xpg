create or replace function hello(you text)
returns text
language 'c'
immutable
as 'hello';
