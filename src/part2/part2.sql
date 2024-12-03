-- 1) A procedure for adding P2P check
DROP PROCEDURE IF EXISTS add_p2p_check(character varying, character varying, character varying, status, time);
CREATE OR REPLACE PROCEDURE add_p2p_check(
    peer_nickname VARCHAR,
    checking_p2p_peer VARCHAR,
    task_name VARCHAR,
    check_status status,
    check_time TIME)
    LANGUAGE plpgsql
AS $$
BEGIN
    IF check_status = 'Start' THEN
        INSERT INTO checks(peer, task, date) VALUES (peer_nickname, task_name, CURRENT_DATE);
    END IF;
    INSERT INTO p2p(check_id, checking_peer, state, time)
    VALUES ((SELECT id FROM checks
             WHERE peer = peer_nickname AND task = task_name
             ORDER BY date DESC, id DESC LIMIT 1),
            checking_p2p_peer,
            check_status,
            check_time
           );
END;
$$;

CALL add_p2p_check('jlbpsacywv', 'iosfiypdje', 'DO6', 'Start', '10:00:00');
CALL add_p2p_check('jlbpsacywv', 'iosfiypdje', 'DO6', 'Success', '12:15:00');

-- 2) A procedure for adding checking by Verter
DROP PROCEDURE IF EXISTS add_verter_check(character varying, character varying, status, time);
CREATE OR REPLACE PROCEDURE add_verter_check(
    peer_nickname VARCHAR,
    task_name VARCHAR,
    check_status status,
    check_time TIME)
    LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO verter(check_id, state, time)
    VALUES ((SELECT check_id FROM p2p JOIN checks c ON c.id = p2p.check_id
             WHERE c.task = task_name and state = 'Success' AND c.peer = peer_nickname
             ORDER BY c.date DESC, time DESC LIMIT 1),
            check_status,
            check_time
           );
END;
$$;

CALL add_verter_check('mvazvelhwy', 'AP4', 'Start', '20:00:00');
CALL add_verter_check('mvazvelhwy', 'AP4', 'Success', '20:15:00');

-- 3) A trigger: after adding a record with the "start" status to the P2P table,
-- changes the corresponding record in the TransferredPoints table
CREATE OR REPLACE FUNCTION check_points_update() RETURNS trigger
AS $$
    BEGIN
        IF NEW.state = 'Start' THEN
            UPDATE transferredpoints SET points_amount = points_amount + 1
            WHERE checking_peer = NEW.checking_peer AND checked_peer = (SELECT peer FROM checks WHERE id = NEW.check_id LIMIT 1);

            IF NOT FOUND THEN
                INSERT INTO transferredpoints (checking_peer, checked_peer, points_amount)
                VALUES (NEW.checking_peer, (SELECT peer FROM checks WHERE id = NEW.check_id LIMIT 1),1);
            END IF;
        END IF;
    RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_peer_update_transferred_points
AFTER INSERT ON p2p
FOR EACH ROW EXECUTE FUNCTION check_points_update();

-- 4) A trigger: before adding a record to the XP table, check if it is correct
-- CREATE OR REPLACE FUNCTION check_xp_update() RETURNS trigger
-- AS $$
--     BEGIN
--         IF NEW.xp_amount <= (SELECT xp FROM tasks JOIN checks ON checks.id = NEW.check_id) THEN
--             UPDATE transferredpoints SET points_amount = points_amount + 1
--             WHERE checking_peer = NEW.checking_peer AND checked_peer = (SELECT peer FROM checks WHERE id = NEW.check_id LIMIT 1);
--
--             IF NOT FOUND THEN
--                 INSERT INTO transferredpoints (checking_peer, checked_peer, points_amount)
--                 VALUES (NEW.checking_peer, (SELECT peer FROM checks WHERE id = NEW.check_id LIMIT 1),1);
--             END IF;
--         END IF;
--     RETURN NEW;
--     END;
-- $$ LANGUAGE plpgsql;
--
-- CREATE OR REPLACE TRIGGER trg_xp_update_xp
-- BEFORE INSERT ON xp
-- FOR EACH ROW EXECUTE FUNCTION check_xp_update();
