
-- 1) Write a function that returns the TransferredPoints table in a more human-readable form
CREATE OR REPLACE FUNCTION get_human_readable_transferred_points()
    RETURNS TABLE
            (
                peer1        VARCHAR(255),
                peer2        VARCHAR(255),
                pointsamount INT
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


-- 2) Write a function that returns a table of the following form: user name, name of the checked task, number of XP received