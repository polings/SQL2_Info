DROP DATABASE IF EXISTS "s21_info_temp";
CREATE DATABASE "s21_info_temp";

\c s21_info;

-- 1) Create a stored procedure that, without destroying the database, destroys all those tables in the current database whose names begin with the phrase 'TableName'.
--
-- 2) Create a stored procedure with an output parameter that outputs a list of names and parameters of all scalar user's SQL functions in the current database. Do not output function names without parameters. The names and the list of parameters must be in a single string. The output parameter returns the number of functions found.
--
-- 3) Create a stored procedure with an output parameter that destroys all SQL DML triggers in the current database. The output parameter will return the number of triggers destroyed.
--
-- 4) Create a stored procedure with an input parameter that returns names and descriptions of object types (stored procedures and scalar functions only) that have a string specified by the procedure parameter.
--



-- 1) Создай хранимую процедуру, которая, не уничтожая базу данных,
-- уничтожает все те таблицы текущей базы данных, имена которых начинаются с фразы 'TableName'.
CREATE OR REPLACE PROCEDURE DeleteTableNameTables()
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

CALL DeleteTableNameTables();

SELECT table_name FROM information_schema.tables where table_schema='public' AND table_name LIKE 'TableName%';


-- 2) Создай хранимую процедуру с выходным параметром, которая выводит список имен
-- и параметров всех скалярных SQL-функций пользователя в текущей базе данных.
-- Имена функций без параметров выводить не нужно. Имена и список параметров должны выводиться в одну строку.
-- Выходной параметр возвращает количество найденных функций.

-- Скалярная функция
create or replace function is_system_catalog_table_name(r anyelement) returns boolean as
$$
  select substring(r.relname from 1 for 3)='pg_'
$$
immutable
language sql;

select * from pg_class pc where is_system_catalog_table_name(pc);

-- SELECT n.nspname AS schema_name,
--        p.proname AS function_name,
--        t.typname AS return_type,
--        p.proretset AS is_set_returning
-- FROM pg_proc p
-- JOIN pg_namespace n ON n.oid = p.pronamespace
-- JOIN pg_type t ON t.oid = p.prorettype
-- WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
-- ORDER BY schema_name, function_name;



-- DROP PROCEDURE IF EXISTS check_scalar_functions(OUT scalar_function_count INTEGER);
-- CREATE OR REPLACE PROCEDURE check_scalar_functions(OUT scalar_function_count INTEGER)
-- LANGUAGE plpgsql
-- AS $$
-- DECLARE
--     rec RECORD;
--     count_scalar INT := 0;
-- BEGIN
--     RAISE NOTICE 'Проверка скалярных функций в базе данных:';
--
--     FOR rec IN
--         SELECT n.nspname AS schema_name,
--                p.proname AS function_name,
--                t.typname AS return_type,
--                p.proretset AS is_set_returning
--         FROM pg_proc p
--         JOIN pg_namespace n ON n.oid = p.pronamespace
--         JOIN pg_type t ON t.oid = p.prorettype
--         WHERE n.nspname NOT IN ('pg_catalog', 'information_schema') -- Исключаем системные схемы
--           --AND p.proretset = false                                  -- Только функции, не возвращающие набор
--           AND t.typname IN ('integer', 'text', 'bool', 'numeric', 'date', 'timestamp', 'uuid') -- Условие для скалярных типов
--         ORDER BY schema_name, function_name
--     LOOP
--         RAISE NOTICE 'Схема: %, Функция: %, Тип возврата: %, Скалярная: Да',
--                      rec.schema_name, rec.function_name, rec.return_type;
--         count_scalar := count_scalar + 1;
--     END LOOP;
--
--     scalar_function_count := count_scalar;
-- END;
-- $$;
--
--
-- CALL check_scalar_functions(0);
--
-- SELECT n.nspname AS schema_name,
--                p.proname AS function_name,
--                t.typname AS return_type,
--                p.proretset AS is_set_returning
--         FROM pg_proc p
--         JOIN pg_namespace n ON n.oid = p.pronamespace
--         JOIN pg_type t ON t.oid = p.prorettype
--         WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
--         ORDER BY schema_name, function_name;
--
--
-- DO $$
-- DECLARE
--     scalar_count INT;
-- BEGIN
--     CALL check_scalar_functions(scalar_count);
--     RAISE NOTICE 'Количество скалярных функций: %', scalar_count;
-- END;
-- $$;






-- 3) Создай хранимую процедуру с выходным параметром, которая уничтожает все SQL DML триггеры в текущей базе данных.
-- Выходной параметр возвращает количество уничтоженных триггеров.
--
-- 4) Создай хранимую процедуру с входным параметром, которая выводит имена
-- и описания типа объектов (только хранимых процедур и скалярных функций),
-- в тексте которых на языке SQL встречается строка, задаваемая параметром процедуры.