create extension pltinyexpr;
\echo

DO LANGUAGE pltinyexpr $$
  5 * 4
$$;
\echo

DO LANGUAGE pltinyexpr $$
  -)(
$$;
\echo

create function simple_addition() returns float8 as $$
  1 + 3
$$ language pltinyexpr;
\echo

select simple_addition();

create function more_complex() returns float8 as $$
  abs(sqrt(3^2) - 5*2)
$$ language pltinyexpr;
\echo

select more_complex();

create function trash() returns float8 as $$
  -)(
$$ language pltinyexpr;
\echo

select trash();
\echo

create function undefined_var() returns float8 as $$
  3 + undef
$$ language pltinyexpr;
\echo

select undefined_var();
\echo

create function single_prm(a float8) returns float8 as $$
  abs(a)
$$ language pltinyexpr;
\echo

select single_prm(-10);

create function two_prms(a float8, b float8) returns float8 as $$
  a * b
$$ language pltinyexpr;
\echo

select two_prms(8, 7);

create function three_prms(x float8, y float8, z float8) returns float8 as $$
  x * y + z
$$ language pltinyexpr;
\echo

select three_prms(3, 17, 90);

create function invalid_func1() returns int as $$
  3 + 5
$$ language pltinyexpr;
\echo

create function invalid_func2(x float8) returns int as $$
  x + 5
$$ language pltinyexpr;
\echo

create function invalid_func3(out x float8) as $$
  x + 5
$$ language pltinyexpr;
\echo

create function invalid_func4(inout x float8) as $$
  x + 5
$$ language pltinyexpr;
\echo

create function invalid_func5(float8) returns float8 as $$
  x + 5
$$ language pltinyexpr;
\echo

create function invalid_func6(x float8, float8) returns float8 as $$
  x + y + 5
$$ language pltinyexpr;
\echo

create function invalid_func7(float8, y float8) returns float8 as $$
  x + y + 5
$$ language pltinyexpr;
\echo

create function invalid_func8() returns trigger as $$
  3 + 5
$$ language pltinyexpr;
\echo

create function invalid_func9() returns event_trigger as $$
  3 + 5
$$ language pltinyexpr;
\echo
