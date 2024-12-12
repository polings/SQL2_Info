DROP DATABASE IF EXISTS "s21_info_temp";
CREATE DATABASE "s21_info_temp";

\c s21_info;



-- 1) Create a stored procedure that, without destroying the database, destroys all those
-- tables in the current database whose names begin with the phrase 'TableName'.
DROP PROCEDURE delete_tablename_tables();
CREATE OR REPLACE PROCEDURE delete_tablename_tables()
LANGUAGE plpgsql
AS $$
DECLARE
    table_name_list RECORD;
BEGIN
    FOR table_name_list IN
        SELECT table_name FROM information_schema.tables where table_schema='public' AND table_name LIKE 'TableName%'
    LOOP
        EXECUTE format('DROP TABLE IF EXISTS %I', table_name_list.table_name);
    END LOOP;
END;
$$;

CREATE TABLE "TableName_1"();
CREATE TABLE "TableName_2"();
CREATE TABLE "TableName_3"();

SELECT table_name FROM information_schema.tables where table_schema='public' AND table_name LIKE 'TableName%';

CALL delete_tablename_tables();

SELECT table_name FROM information_schema.tables where table_schema='public' AND table_name LIKE 'TableName%';



-- 2)  Create a stored procedure with an output parameter that outputs a list of names
-- and parameters of all scalar user's SQL functions in the current database. Do not output
-- function names without parameters. The names and the list of parameters must be in a single string.
-- The output parameter returns the number of functions found.

-- FUNCTIONS FOR TESTING
-- Scalar functions with parameters
CREATE OR REPLACE FUNCTION is_system_catalog_table_name(r anyelement)
RETURNS BOOLEAN AS $$
  SELECT substring(r.relname FROM 1 for 3)='pg_'
$$
IMMUTABLE
LANGUAGE sql;
SELECT * FROM pg_class pc WHERE is_system_catalog_table_name(pc);

CREATE OR REPLACE FUNCTION get_square_of_number(input_number INT)
RETURNS INT AS $$
BEGIN
    RETURN input_number * input_number;
END;
$$ LANGUAGE plpgsql;
SELECT * FROM get_square_of_number(25);

-- Scalar function with no parameters
CREATE OR REPLACE FUNCTION get_current_timestamp()
RETURNS TEXT AS $$
BEGIN
    RETURN NOW()::TEXT;
END;
$$ LANGUAGE plpgsql;
SELECT * FROM get_current_timestamp();

-- Not scalar function with parameter
CREATE OR REPLACE FUNCTION get_peers_not_left_campus_whole_day(day DATE)
    RETURNS TABLE ("Peer" VARCHAR(255))
AS $$
BEGIN
    RETURN QUERY
        SELECT peer FROM timetracking
        WHERE date = day
        GROUP BY peer, date
        HAVING count(presence) > 2
        ORDER BY peer;
END;
$$ LANGUAGE plpgsql;
SELECT * FROM get_peers_not_left_campus_whole_day('2021-06-26');

-- MAIN PROCEDURE
DROP PROCEDURE IF EXISTS check_scalar_functions(OUT scalar_function_count INTEGER);
CREATE OR REPLACE PROCEDURE check_scalar_functions(OUT scalar_function_count INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    rec RECORD;
    count_scalar INT := 0;
BEGIN
    FOR rec IN
        SELECT p.proname AS function_name,
               pg_catalog.pg_get_function_arguments(p.oid) AS parameter_types, p.proretset, t.typname, cardinality(p.proargtypes), p.prorettype
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        JOIN pg_type t ON t.oid = p.prorettype
        WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
          AND p.proretset = false
          AND t.typname IN ('int4', 'text', 'bool', 'numeric', 'date', 'timestamp without time zone', 'uuid', 'float4', 'int8')
          AND cardinality(p.proargtypes) > 0
        ORDER BY function_name
    LOOP
        RAISE NOTICE 'NAME: %, PARAMETRS: %',
                     rec.function_name, rec.parameter_types ;
        count_scalar := count_scalar + 1;
    END LOOP;
    scalar_function_count := count_scalar;
END;
$$;

CALL check_scalar_functions(0);



-- 3) Создай хранимую процедуру с выходным параметром, которая уничтожает все SQL DML триггеры в текущей базе данных.
-- Выходной параметр возвращает количество уничтоженных триггеров.

-- 3) Create a stored procedure with an output parameter that destroys all SQL DML triggers in the current database.
-- The output parameter will return the number of triggers destroyed.
DROP PROCEDURE IF EXISTS delete_dml_triggers(OUT deleted_triggers_count INTEGER);
CREATE OR REPLACE PROCEDURE delete_dml_triggers(OUT deleted_triggers_count INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    rec RECORD;
    count_scalar INT := 0;
BEGIN
    FOR rec IN
        SELECT p.proname AS function_name,
               pg_catalog.pg_get_function_arguments(p.oid) AS parameter_types, p.proretset, t.typname, cardinality(p.proargtypes), p.prorettype
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        JOIN pg_type t ON t.oid = p.prorettype
        WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
          AND p.proretset = false
          AND t.typname IN ('int4', 'text', 'bool', 'numeric', 'date', 'timestamp without time zone', 'uuid', 'float4', 'int8')
          AND cardinality(p.proargtypes) > 0
        ORDER BY function_name
    LOOP
        RAISE NOTICE 'NAME: %, PARAMETRS: %',
                     rec.function_name, rec.parameter_types ;
        count_scalar := count_scalar + 1;
    END LOOP;
    scalar_function_count := count_scalar;
END;
$$;




SELECT
    t.tgname AS trigger_name,
    c.relname AS table_name,
    CASE
        WHEN t.tgtype & 1 <> 0 THEN 'BEFORE'
        WHEN t.tgtype & 2 <> 0 THEN 'AFTER'
        WHEN t.tgtype & 4 <> 0 THEN 'INSTEAD OF'
        ELSE 'UNKNOWN'
    END AS timing,
    CASE
        WHEN t.tgtype & 8 <> 0 THEN 'INSERT'
        WHEN t.tgtype & 16 <> 0 THEN 'UPDATE'
        WHEN t.tgtype & 32 <> 0 THEN 'DELETE'
        ELSE 'UNKNOWN'
    END AS event,
    p.proname AS function_name
FROM
    pg_trigger t
JOIN
    pg_class c ON c.oid = t.tgrelid
JOIN
    pg_proc p ON p.oid = t.tgfoid
WHERE
    c.relkind = 'r' -- Only regular tables, excluding views, indexes, etc.
    AND t.tgenabled = 'O' -- Only enabled triggers
    AND t.tgtype & 8 <> 0  -- For INSERT triggers
    OR t.tgtype & 16 <> 0  -- For UPDATE triggers
    OR t.tgtype & 32 <> 0  -- For DELETE triggers
ORDER BY
    table_name, trigger_name;








-- 4) Create a stored procedure with an input parameter that returns names
-- and descriptions of object types (stored procedures and scalar functions only)
-- that have a string specified by the procedure parameter.

-- 4) Создай хранимую процедуру с входным параметром, которая выводит имена
-- и описания типа объектов (только хранимых процедур и скалярных функций),
-- в тексте которых на языке SQL встречается строка, задаваемая параметром процедуры.