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
-- CREATE OR REPLACE PROCEDURE DeleteTableNameTables()
-- AS $$
-- DECLARE
--     table_name RECORD;
-- BEGIN
--     FOR table_name IN
--         SELECT TableName FROM TablesToDelete;
--     LOOP
--         EXECUTE format('DROP TABLE IF EXISTS %I', table_name.TableName);
--     END LOOP;
-- END;
-- $$;


-- 2) Создай хранимую процедуру с выходным параметром, которая выводит список имен
-- и параметров всех скалярных SQL-функций пользователя в текущей базе данных.
-- Имена функций без параметров выводить не нужно. Имена и список параметров должны выводиться в одну строку.
-- Выходной параметр возвращает количество найденных функций.
--
-- 3) Создай хранимую процедуру с выходным параметром, которая уничтожает все SQL DML триггеры в текущей базе данных.
-- Выходной параметр возвращает количество уничтоженных триггеров.
--
-- 4) Создай хранимую процедуру с входным параметром, которая выводит имена
-- и описания типа объектов (только хранимых процедур и скалярных функций),
-- в тексте которых на языке SQL встречается строка, задаваемая параметром процедуры.