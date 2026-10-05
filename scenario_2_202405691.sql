-- Scenario 2: Computer Laboratory Reservations

CREATE TABLE lab_sessions (
    session_id SERIAL PRIMARY KEY,
    session_name VARCHAR(100),
    available_workstations INT
);

CREATE TABLE reservations (
    reservation_id SERIAL PRIMARY KEY,
    session_id INT REFERENCES lab_sessions(session_id),
    lecturer VARCHAR(100),
    num_workstations INT,
    status VARCHAR(50) DEFAULT 'ACTIVE'
);

-- Add at least three sessions
INSERT INTO lab_sessions (session_name, available_workstations) VALUES 
('Databases Lab', 2),
('Networks Lab', 15),
('AI & Machine Learning Lab', 0);


-- 2. IF ELSIF ELSE to report status of a session
DO $$
DECLARE
    v_workstations INT;
BEGIN
    SELECT available_workstations INTO v_workstations FROM lab_sessions WHERE session_id = 1;
    
    IF v_workstations = 0 THEN
        RAISE NOTICE 'Session is full.';
    ELSIF v_workstations < 5 THEN
        RAISE NOTICE 'Session is nearly full.';
    ELSE
        RAISE NOTICE 'Session has enough workstations.';
    END IF;
END $$;


-- 3. WHILE loop and Numeric FOR loop
DO $$
DECLARE
    v_counter INT := 1;
BEGIN
    -- WHILE loop for preparation reminders
    WHILE v_counter <= 3 LOOP
        RAISE NOTICE 'Session preparation reminder day %', v_counter;
        v_counter := v_counter + 1;
    END LOOP;

    -- Numeric FOR loop for workstation checks
    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Performing workstation check number %', i;
    END LOOP;
END $$;


-- 4. Create reserve_workstations procedure
CREATE OR REPLACE PROCEDURE reserve_workstations(
    p_session_id INT,
    p_lecturer VARCHAR,
    p_num_workstations INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_avail INT;
BEGIN
    SELECT available_workstations INTO v_current_avail 
    FROM lab_sessions 
    WHERE session_id = p_session_id;

    IF v_current_avail < p_num_workstations THEN
        RAISE EXCEPTION 'Reservation failed: Requested workstations exceed available capacity.';
    END IF;

    -- Reduce availability
    UPDATE lab_sessions 
    SET available_workstations = available_workstations - p_num_workstations 
    WHERE session_id = p_session_id;

    -- Record reservation
    INSERT INTO reservations (session_id, lecturer, num_workstations, status)
    VALUES (p_session_id, p_lecturer, p_num_workstations, 'ACTIVE');
    
    RAISE NOTICE 'Reservation successful for %', p_lecturer;
END;
$$;


-- 5. Call procedure for two valid and one exceeding capacity
CALL reserve_workstations(2, 'Dr. Banda', 3);
CALL reserve_workstations(2, 'Dr. Phiri', 4);
-- This next call will fail due to capacity limits if tested individually, wrap in exception block if running sequentially:
-- CALL reserve_workstations(2, 'Prof. Mwewa', 50);

SELECT * FROM lab_sessions;
SELECT * FROM reservations;


-- 6. Create cancel_reservation procedure (Idempotent)
CREATE OR REPLACE PROCEDURE cancel_reservation(p_reservation_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_session_id INT;
    v_num_ws INT;
    v_status VARCHAR;
    v_rows_affected INT;
BEGIN
    SELECT session_id, num_workstations, status 
    INTO v_session_id, v_num_ws, v_status 
    FROM reservations 
    WHERE reservation_id = p_reservation_id;

    IF v_status = 'CANCELLED' THEN
        RAISE NOTICE 'Reservation % is already cancelled. No changes made.', p_reservation_id;
        RETURN;
    END IF;

    -- Release workstations
    UPDATE lab_sessions 
    SET available_workstations = available_workstations + v_num_ws 
    WHERE session_id = v_session_id;

    -- Mark cancelled
    UPDATE reservations 
    SET status = 'CANCELLED' 
    WHERE reservation_id = p_reservation_id;

    RAISE NOTICE 'Reservation % successfully cancelled.', p_reservation_id;
END;
$$;

-- Call twice to test idempotency
CALL cancel_reservation(1);
CALL cancel_reservation(1);


-- 7. Explicit cursor to display sessions with few workstations remaining
DO $$
DECLARE
    cur_sessions CURSOR FOR SELECT session_name, available_workstations FROM lab_sessions WHERE available_workstations < 5;
    rec RECORD;
BEGIN
    OPEN cur_sessions;
    LOOP
        FETCH cur_sessions INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low capacity session: %, Workstations left: %', rec.session_name, rec.available_workstations;
    END LOOP;
    CLOSE cur_sessions;
END $$;


-- 8. Request zero workstations with EXCEPTION block
DO $$
DECLARE
    v_ws INT := 0;
BEGIN
    IF v_ws <= 0 THEN
        RAISE EXCEPTION 'Invalid workstation quantity requested: %', v_ws;
    END IF;
    -- Call procedure logic here if valid
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Caught Exception: %', SQLERRM;
END $$;


-- 9. Final Query
SELECT * FROM lab_sessions;
SELECT * FROM reservations;