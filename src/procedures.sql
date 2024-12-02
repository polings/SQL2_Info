-- This procedure imports data from a specified CSV file into a target table
CREATE OR REPLACE PROCEDURE import_csv(
    table_name TEXT,
    file_path TEXT,
    delim TEXT DEFAULT ';')
LANGUAGE plpgsql
AS $$
BEGIN
    EXECUTE format(
        'COPY %I FROM %L WITH (FORMAT CSV, HEADER, DELIMITER %L)',
        table_name, file_path, delim
        );
    RAISE NOTICE 'Data imported successfully from file % to table %', file_path, table_name;
END;
$$;

-- This procedure exports data from a table into a target specified CSV file
CREATE OR REPLACE PROCEDURE export_csv(
    table_name TEXT,
    file_path TEXT,
    delim TEXT DEFAULT ';')
LANGUAGE plpgsql
AS $$
BEGIN
    EXECUTE format(
        'COPY %I TO %L WITH (FORMAT CSV, HEADER, DELIMITER %L)',
        table_name, file_path, delim
        );
    RAISE NOTICE 'Data exported successfully from table % to file %', table_name, file_path;
END;
$$;

CALL import_csv('your_table_name', '/path/to/your/file.csv');