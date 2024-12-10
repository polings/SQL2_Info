-- 1) Write a function that returns the TransferredPoints table in a more human-readable form
DROP FUNCTION IF EXISTS get_human_readable_transferred_points();
CREATE OR REPLACE FUNCTION get_human_readable_transferred_points()
    RETURNS TABLE
            (
                "peer1"        VARCHAR(255),
                "peer2"        VARCHAR(255),
                "pointsamount" INT
            )
AS
$$
BEGIN
    RETURN QUERY
        WITH cte AS (SELECT LEAST(checking_peer, checked_peer)    AS cte_peer1,
                            GREATEST(checking_peer, checked_peer) AS cte_peer2,
                            CASE
                                WHEN checking_peer < checked_peer THEN points_amount
                                ELSE -points_amount
                                END                               AS cte_pointsamount
                     FROM TransferredPoints)
        SELECT cte_peer1                  AS peer1,
               cte_peer2                  AS peer2,
               sum(cte_pointsamount)::INT AS pointsamount
        FROM cte
        GROUP BY cte_peer1, cte_peer2;
END;
$$ LANGUAGE plpgsql;

SELECT *
FROM get_human_readable_transferred_points() AS MyReadableTable;


-- 2) Write a function that returns a table of the following form: username, name of the checked task, number of XP received
DROP FUNCTION IF EXISTS get_peers_xp_from_task();
CREATE OR REPLACE FUNCTION get_peers_xp_from_task()
    RETURNS TABLE
            (
                "Peer" VARCHAR(255),
                "Task" VARCHAR(255),
                "XP"   INT
            )
AS
$$
BEGIN
    RETURN QUERY
        SELECT peer, task, x.xp_amount
        FROM checks c
                 JOIN verter v ON c.id = v.check_id
                 JOIN p2p p ON c.id = p.check_id
                 JOIN xp x ON c.id = x.check_id
        WHERE p.state = 'Success'
          AND (v.state = 'Success' OR v.state IS NULL)
        ORDER BY peer;
END;
$$ LANGUAGE plpgsql;

SELECT *
FROM get_peers_xp_from_task();


-- 3) Write a function that finds the peers who have not left campus for the whole day
DROP FUNCTION IF EXISTS get_peers_not_left_campus_whole_day(DATE);
CREATE OR REPLACE FUNCTION get_peers_not_left_campus_whole_day(day DATE)
    RETURNS TABLE
            (
                "Peer" VARCHAR(255)
            )
AS
$$
BEGIN
    RETURN QUERY
        SELECT peer
        FROM timetracking
        WHERE date = day
        GROUP BY peer, date
        HAVING count(presence) > 2
        ORDER BY peer;
END;
$$ LANGUAGE plpgsql;

SELECT *
FROM get_peers_not_left_campus_whole_day('2021-06-26');


-- 4) Calculate the change in the number of peer points of each peer using the TransferredPoints table
SELECT peer as "Peer", sum(points_change) AS "PointsChange"
FROM ((SELECT checked_peer As peer, -sum(points_amount) as points_change
       FROM transferredpoints
       GROUP BY checked_peer)
      UNION
      (SELECT checking_peer, sum(points_amount)
       FROM transferredpoints
       GROUP BY checking_peer)) as ppccp
GROUP BY peer
ORDER BY "PointsChange" DESC;

-- 5) Calculate the change in the number of peer points of each peer using the table returned by the first function from Part 3
SELECT peer1 AS "Peer", sum(pointsamount) AS "PointsChange"
FROM ((SELECT peer1, sum(pointsamount) AS pointsamount
       FROM get_human_readable_transferred_points()
       group by peer1)
      UNION
      (SELECT peer2, -sum(pointsamount) AS pointsamount
       FROM get_human_readable_transferred_points()
       group by peer2)) as ppccp
GROUP BY peer1
ORDER BY "PointsChange" DESC;


-- 6) Find the most frequently checked task for each day
WITH cte AS
         (SELECT date,
                 task,
                 DENSE_RANK() over (PARTITION BY date ORDER BY count(task) DESC) AS rank
          FROM checks
          GROUP BY date, task)
SELECT date, task
FROM cte
WHERE rank = 1
ORDER BY date;


-- 7) Find all peers who have completed the whole given block of tasks and the completion date of the last task

-- Найди всех пиров, выполнивших весь заданный блок задач и дату завершения последнего задания
-- Параметры процедуры: название блока, например, «CPP».
-- Результат выведи отсортированным по дате завершения.
-- Формат вывода: ник пира, дата завершения блока (т. е. последнего выполненного задания из этого блока).

-- SELECT peer, SUBSTRING(task FROM '^[^0-9]+') AS title_prefix, COUNT(*)
-- FROM checks
-- WHERE task LIKE 'CPP_'
-- GROUP BY peer, title_prefix
-- ORDER BY peer;
--
-- SELECT SUBSTRING(title FROM '^[^0-9]+') AS title_prefix
-- FROM tasks
-- WHERE title LIKE 'AP_'
-- GROUP BY title_prefix
-- ORDER BY title_prefix;


-- DROP FUNCTION IF EXISTS get_peers_completed_block_of_tasks(block_name VARCHAR);

-- CREATE OR REPLACE FUNCTION get_peers_completed_block_of_tasks(block_name VARCHAR)
--     RETURNS TABLE
--         (
--             "Peer" VARCHAR,
--             "Day" DATE
--         )
-- AS
-- $$
-- BEGIN
--     RETURN QUERY
--
--
-- END;
-- $$ LANGUAGE plpgsql;


-- 10) Determine the percentage of peers who have ever successfully passed a check on their birthday

SELECT nickname
FROM peers p
JOIN







