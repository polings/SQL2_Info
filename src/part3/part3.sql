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

SELECT * FROM get_human_readable_transferred_points() AS MyReadableTable;



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

SELECT * FROM get_peers_xp_from_task();



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

SELECT * FROM get_peers_not_left_campus_whole_day('2021-06-26');



-- 4) Calculate the change in the number of peer points of each peer using the TransferredPoints table
DROP FUNCTION IF EXISTS get_peers_transferring_points();
CREATE OR REPLACE FUNCTION get_peers_transferring_points()
    RETURNS TABLE
            (
                "Peer" VARCHAR(255),
                "PointsChange" NUMERIC
            )
AS
$$
BEGIN
    RETURN QUERY
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
END;
$$ LANGUAGE plpgsql;

SELECT * FROM get_peers_transferring_points();



-- 5) Calculate the change in the number of peer points of each peer using the table returned by the first function from Part 3
DROP FUNCTION IF EXISTS get_peers_transferring_points_with_call_previous_function();
CREATE OR REPLACE FUNCTION get_peers_transferring_points_with_call_previous_function()
    RETURNS TABLE
            (
                "Peer" VARCHAR(255),
                "PointsChange" NUMERIC
            )
AS
$$
BEGIN
    RETURN QUERY
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
END;
$$ LANGUAGE plpgsql;

SELECT * FROM get_peers_transferring_points_with_call_previous_function();



-- 6) Find the most frequently checked task for each day
DROP FUNCTION IF EXISTS get_most_frequently_checked_task_for_each_day();
CREATE OR REPLACE FUNCTION get_most_frequently_checked_task_for_each_day()
RETURNS TABLE
            (
                "Date" DATE,
                "Task" VARCHAR(255)
            )
AS
$$
BEGIN
    RETURN QUERY
        WITH cte AS(
            SELECT date,
                   task,
                   DENSE_RANK() over (PARTITION BY date ORDER BY count(task) DESC) AS rank
            FROM checks
            GROUP BY date, task)
        SELECT date, task
        FROM cte
        WHERE rank = 1
        ORDER BY date;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM get_most_frequently_checked_task_for_each_day();



-- 7) Find all peers who have completed the whole given block of tasks and the completion date of the last task
DROP FUNCTION IF EXISTS get_peers_completed_block_of_tasks(block_name VARCHAR);
CREATE OR REPLACE FUNCTION get_peers_completed_block_of_tasks(block_name VARCHAR)
    RETURNS TABLE
        (
            "Peer" VARCHAR,
            "Day" DATE
        )
AS
$$
BEGIN
    block_name := block_name || '_';
    RETURN QUERY
        WITH task_count AS (
        select COUNT(*) AS task_count
          from tasks
          where title LIKE block_name
        ), peer_task_count AS (
            SELECT c.peer, COUNT(distinct task) AS peer_task_count
            FROM checks c
            join xp x on c.id = x.check_id
            WHERE task LIKE block_name
            GROUP BY peer
        ), last_task AS (
            SELECT title
            from tasks
            where title LIKE block_name
            ORDER BY title DESC
            LIMIT 1
        )
        SELECT ptc.peer, (SELECT date FROM checks, last_task lt WHERE peer = ptc.peer AND task = lt.title ORDER BY 1 LIMIT 1) d
        FROM task_count tc, peer_task_count ptc
        WHERE ptc.peer_task_count = tc.task_count;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM get_peers_completed_block_of_tasks('A');



-- 8) Determine which peer each student should go to for a check.
DROP FUNCTION IF EXISTS get_recommended_peer_for_each_student();
CREATE OR REPLACE FUNCTION get_recommended_peer_for_each_student()
RETURNS TABLE
            (
                "Peer" VARCHAR(255),
                "RecommendedPeer" VARCHAR(255)
            )
AS
$$
BEGIN
    RETURN QUERY
        WITH FriendRecommendations AS (
            SELECT r1.peer AS original_peer,
                   r2.recommended_peer AS recommended_by_friends
            FROM Recommendations r1
            JOIN Recommendations r2 ON r1.recommended_peer = r2.peer
            ),
            RecommendationCounts AS (
            SELECT original_peer,
                   recommended_by_friends,
                   COUNT(*) AS recommendation_count
            FROM FriendRecommendations
            GROUP BY original_peer, recommended_by_friends
            ),
            BestRecommendation AS (
            SELECT original_peer,
                   recommended_by_friends AS chosen_peer,
                   recommendation_count,
                   RANK() OVER (PARTITION BY original_peer ORDER BY recommendation_count DESC, recommended_by_friends) AS rank
            FROM RecommendationCounts
            )
        SELECT original_peer AS "Peer", chosen_peer AS "RecommendedPeer"
        FROM BestRecommendation
        WHERE rank = 1
        ORDER BY "Peer";
END;
$$ LANGUAGE plpgsql;

SELECT * FROM get_recommended_peer_for_each_student();



-- 9) Determine the percentage of peers who: started Block 1 only, started Block 2 only, both started, started neither.
DROP FUNCTION IF EXISTS get_percentage_of_peers(block1_name VARCHAR, block2_name VARCHAR);
CREATE OR REPLACE FUNCTION get_percentage_of_peers(block1_name VARCHAR, block2_name VARCHAR)
RETURNS TABLE
            (
                "StartedBlock1" NUMERIC,
                "StartedBlock2" NUMERIC,
                "StartedBothBlocks" NUMERIC,
                "DidntStartAnyBlock" NUMERIC
            )
AS
$$
BEGIN
    block1_name := block1_name || '_';
    block2_name := block2_name || '_';
    RETURN QUERY
        WITH all_peers AS (
                SELECT COUNT(DISTINCT nickname) AS all_p
                FROM peers c),
            block1 AS (
                SELECT COUNT(DISTINCT c.peer) AS count1
                from checks c
                WHERE c.task LIKE block1_name),
            block2 AS (
                SELECT COUNT(DISTINCT c.peer) AS count2
                from checks c
                WHERE c.task LIKE block2_name),
            intersection AS (
                SELECT COUNT(peer) AS count_inter
                FROM (
                SELECT DISTINCT c.peer
                from checks c
                WHERE c.task LIKE block1_name
                INTERSECT
                SELECT DISTINCT c.peer
                from checks c
                WHERE c.task LIKE block2_name) intersection
            )
        SELECT ROUND(block1.count1::numeric / all_peers.all_p * 100),
               ROUND(block2.count2::numeric / all_peers.all_p * 100),
               ROUND(intersection.count_inter::numeric / all_peers.all_p * 100),
               100 - ROUND((block1.count1 + block2.count2 + intersection.count_inter)::numeric / all_peers.all_p * 100)
        FROM all_peers, block1, block2, intersection;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM get_percentage_of_peers('SQL', 'AP');



-- 10) Determine the percentage of peers who have ever successfully passed a check on their birthday.
DROP FUNCTION IF EXISTS get_peers_successfully_passed_check_their_birthday();
CREATE OR REPLACE FUNCTION get_peers_successfully_passed_check_their_birthday()
RETURNS TABLE
            (
                "SuccessfulChecks" NUMERIC,
                "UnsuccessfulChecks" NUMERIC
            )
AS
$$
BEGIN
    RETURN QUERY
        WITH s AS (SELECT count(distinct c.peer) AS success_peers
                   FROM checks c
                            JOIN peers pr ON c.peer = pr.nickname AND TO_CHAR(c.date, 'MM-dd') = TO_CHAR(pr.birthday, 'MM-dd')
                            JOIN p2p p ON c.id = p.check_id
                            JOIN verter v ON c.id = v.check_id
                   WHERE p.state = 'Success'
                      OR v.state = 'Success'),
             f AS (SELECT count(distinct c.peer) AS unsuccess_peers
                   FROM checks c
                            JOIN peers pr ON c.peer = pr.nickname AND TO_CHAR(c.date, 'MM-dd') = TO_CHAR(pr.birthday, 'MM-dd')
                            JOIN p2p p ON c.id = p.check_id
                            JOIN verter v ON c.id = v.check_id
                   WHERE p.state = 'Failure'
                      OR v.state = 'Failure')
        SELECT s.success_peers / (s.success_peers + f.unsuccess_peers)::numeric * 100   AS "SuccessfulChecks",
               f.unsuccess_peers / (s.success_peers + f.unsuccess_peers)::numeric * 100 AS "UnsuccessfulChecks"
        FROM s,
             f;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM get_peers_successfully_passed_check_their_birthday();



-- 11) Determine all peers who did the given tasks 1 and 2, but did not do task 3.
DROP FUNCTION IF EXISTS get_peers_completed_first_second_but_third_task(task1 VARCHAR, task2 VARCHAR, task3 VARCHAR);
CREATE OR REPLACE FUNCTION get_peers_completed_first_second_but_third_task(task1 VARCHAR, task2 VARCHAR, task3 VARCHAR)
    RETURNS TABLE
        (
            "Peer" VARCHAR
        )
AS
$$
BEGIN
    RETURN QUERY
        SELECT DISTINCT c.peer
        FROM checks c
        JOIN xp x ON c.id = x.check_id
        JOIN (SELECT c.peer FROM checks c JOIN xp x ON c.id = x.check_id WHERE task LIKE task1) ch ON c.peer = ch.peer
        WHERE task LIKE task2
        GROUP BY c.peer
        EXCEPT
        SELECT c.peer
        FROM checks c
        WHERE task LIKE task3 AND c.id NOT IN (SELECT check_id FROM xp);
END;
$$ LANGUAGE plpgsql;

SELECT * FROM get_peers_completed_first_second_but_third_task('C5', 'CPP5', 'SQL1');



-- 12) Using recursive common table expression, output the number of preceding tasks for each task
DROP FUNCTION IF EXISTS get_number_of_preceding_tasks_for_each_task();
CREATE OR REPLACE FUNCTION get_number_of_preceding_tasks_for_each_task()
RETURNS TABLE
            (
                "Task" VARCHAR(255),
                "PrevCount" INT
            )
AS
$$
BEGIN
    RETURN QUERY
        WITH RECURSIVE TaskHierarchy AS (
            SELECT title, parent_task, 0 AS predecessors_count
            FROM Tasks
            WHERE parent_task IS NULL

            UNION ALL

            SELECT t.title, t.parent_task, th.predecessors_count + 1 AS predecessors_count
            FROM Tasks t
            INNER JOIN TaskHierarchy th ON t.parent_task = th.title
            )
        SELECT title AS "Task", MAX(predecessors_count) AS "PrevCount"
        FROM TaskHierarchy
        GROUP BY title
        ORDER BY "PrevCount";
END;
$$ LANGUAGE plpgsql;

SELECT * FROM get_number_of_preceding_tasks_for_each_task();



-- 13) Find "lucky" days for checks. A day is considered "lucky" if it has at least N consecutive successful checks
DROP PROCEDURE IF EXISTS get_lucky_days(N_checks INT, OUT result_days VARCHAR);
CREATE OR REPLACE PROCEDURE get_lucky_days(N_checks INT, OUT result_days TEXT)
AS
$$
DECLARE
    temp_days VARCHAR;
BEGIN
    SELECT string_agg(day::TEXT, E'\n')
    INTO temp_days
    FROM (
        WITH  total_checks AS (
			SELECT c.id, c.date, p2p.time, p2p.state, xp.xp_amount
			FROM checks c, p2p, xp
			WHERE c.id = p2p.check_id AND (p2p.state = 'Success' OR p2p.state = 'Failure')
				AND c.id = xp.check_id AND xp_amount >= (SELECT tasks.xp
														 FROM tasks
														 WHERE tasks.title = c.task) * 0.8
			ORDER BY c.date, p2p.time),
		 succes_in_a_row AS (
			SELECT id, date, time, state,
			(CASE WHEN state = 'Success' THEN row_number() over (partition by state, date) ELSE 0 END) AS amount
												 FROM total_checks ORDER BY date
		 ),
		 max_in_day AS (SELECT s.date, MAX(amount) amount FROM succes_in_a_row s GROUP BY date)

		 SELECT date AS day FROM max_in_day WHERE amount >= N_checks
    ) final_result;

    result_days := COALESCE(temp_days, 'No days found');
END;
$$ LANGUAGE plpgsql;

CALL get_lucky_days( 5, '');



-- 14) Find the peer with the highest amount of XP
DROP FUNCTION IF EXISTS get_peer_highest_xp();
CREATE OR REPLACE FUNCTION get_peer_highest_xp()
RETURNS TABLE
            (
                "Peer" VARCHAR(255),
                "XP" BIGINT
            )
AS
$$
BEGIN
    RETURN QUERY
        SELECT peer, sum(xp_amount) AS "XP"
        FROM checks
        JOIN xp x ON checks.id = x.check_id
        GROUP BY peer
        ORDER BY "XP" DESC
        LIMIT 1;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM get_peer_highest_xp();



-- 15) Determine the peers that came before the given time at least N times during the entire time
DROP PROCEDURE IF EXISTS get_peers_came_before_given_time(given_time TIME, N_times INT, OUT result_peers VARCHAR);
CREATE OR REPLACE PROCEDURE get_peers_came_before_given_time(given_time TIME, N_times INT, OUT result_peers TEXT)
AS
$$
DECLARE
    temp_peers VARCHAR;
BEGIN
    SELECT string_agg(peer, E'\n')
    INTO temp_peers
    FROM (
        SELECT peer
        FROM (
            SELECT peer, count(time) AS times_count
            FROM timetracking
            WHERE time <= given_time AND presence = 1
            GROUP BY peer
        ) cte
        WHERE times_count >= N_times
        ORDER BY peer
    ) final_result;

    result_peers := COALESCE(temp_peers, 'No peers found');
END;
$$ LANGUAGE plpgsql;

CALL get_peers_came_before_given_time('12:00:00'::time, 3, '');



-- 16) Determine the peers who left the campus more than M times during the last N days
DROP PROCEDURE IF EXISTS get_peers_left_campus_more_than_M_times(M_times INT, N_days INT, OUT result_peers VARCHAR);
CREATE OR REPLACE PROCEDURE get_peers_left_campus_more_than_M_times(M_times INT, N_days INT, OUT result_peers TEXT)
AS
$$
DECLARE
    temp_peers VARCHAR;
BEGIN
    SELECT string_agg(peer, E'\n')
    INTO temp_peers
    FROM (
            SELECT peer
            FROM (SELECT peer, count(presence) AS times_count
                  FROM timetracking
                  WHERE date > (CURRENT_DATE - N_days)
                    AND presence = 2
                  GROUP BY peer
                  ORDER BY peer
                  ) cte
            WHERE times_count >= M_times
            ORDER BY peer
    ) final_result;

    result_peers := COALESCE(temp_peers, 'No peers found');
END;
$$ LANGUAGE plpgsql;

-- INSERT INTO timetracking (id, peer, date, time, presence) VALUES (20611,'aaarswhfom', '2024-12-10', '10:01:21',1);
-- INSERT INTO timetracking (id, peer, date, time, presence) VALUES (20612,'aaarswhfom', '2024-12-10', '12:01:21',2);
-- INSERT INTO timetracking (id, peer, date, time, presence) VALUES (20613,'aaarswhfom', '2024-12-10', '13:01:21',1);
-- INSERT INTO timetracking (id, peer, date, time, presence) VALUES (20614,'aaarswhfom', '2024-12-10', '15:01:21',2);

CALL get_peers_left_campus_more_than_M_times(2, 2, '');



-- 17) Determine for each month the percentage of early entries
DROP FUNCTION IF EXISTS get_early_entries_birthday_month();
CREATE OR REPLACE FUNCTION get_early_entries_birthday_month()
RETURNS TABLE
            (
                "Month" TEXT,
                "EarlyEntries" NUMERIC
            )
AS
$$
BEGIN
    RETURN QUERY
        WITH birthday_presence AS (
            SELECT p.nickname,
                   TO_CHAR(p.birthday, 'Month') AS birth_month,
                   EXTRACT(MONTH FROM p.birthday) AS month_count,
                   COUNT(tt.date) AS birthday_month_presences,
                   MIN(tt.time),
                   CASE WHEN MIN(tt.time) < '12:00:00' THEN 1 END AS early_presences
            FROM Peers p
            JOIN TimeTracking tt ON p.nickname = tt.peer
            WHERE EXTRACT(MONTH FROM tt.date) = EXTRACT(MONTH FROM p.birthday)
            GROUP BY tt.date, TO_CHAR(p.birthday, 'Month'), p.nickname
            )
        SELECT bp.birth_month, ROUND(SUM(bp.early_presences)::numeric / COUNT(bp.birthday_month_presences) * 100)
        FROM birthday_presence bp
        GROUP BY bp.birth_month, bp.month_count
        ORDER BY bp.month_count;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM get_early_entries_birthday_month();