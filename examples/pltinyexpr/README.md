# PL/tinyexpr

PL/tinyexpr is a procedural language handler created for learning purposes.

It evaluates math expressions using https://github.com/codeplea/tinyexpr.

## Installation

```bash
make && sudo make install
```

## Usage

```sql
create extension pltinyexpr;
```

It runs functions with parameters:

```sql
create or replace function sample(a float8, b float8) returns float8 as $$
  abs(sqrt(a^2) - 5*b)
$$ language pltinyexpr;
-- all the functions in tinyexpr are supported https://github.com/codeplea/tinyexpr/#functions-supported

select sample(9,2);
 sample
--------
      1
(1 row)
```


It validates function's signatures:

```sql
create or replace function sample(x text) returns float8 as $$
	x + 4
$$ language pltinyexpr;
ERROR:  only parameters of double precision or float8 types are allowed
```

It runs inline expressions, but they only LOG their result:

```sql
DO LANGUAGE pltinyexpr $$
  5 * 4
$$;
INFO:  expression result is: 20.000000
DO
```

## Testing

```bash
make installcheck
```
