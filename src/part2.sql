-- 1) a procedure for adding P2P check
CREATE OR REPLACE PROCEDURE add_p2p_check(
    peer_nickname VARCHAR,
    checking_peer VARCHAR,
    task_name VARCHAR,
    check_status SMALLINT,
    check_time TIMESTAMP)
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

DROP TYPE IF EXISTS check_status CASCADE;
CREATE TYPE check_status AS ENUM ('Start', 'Success', 'Failure');

select 1 where 0 < 'Start'::check_status;
