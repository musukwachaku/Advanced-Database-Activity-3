-- Scenario 3: Student Hostel Room Allocation

CREATE TABLE hostel_rooms (
    room_id SERIAL PRIMARY KEY,
    room_number VARCHAR(50),
    available_spaces INT
);

CREATE TABLE allocations (
    allocation_id SERIAL PRIMARY KEY,
    student_number VARCHAR(50),
    room_id INT REFERENCES hostel_rooms(room_id),
    status VARCHAR(50) DEFAULT 'ALLOCATED'
);

-- Add at least three rooms
INSERT INTO hostel_rooms (room_number, available_spaces) VALUES 
('Block A-101', 0),
('Block A-102', 1),
('Block B-201', 4);


-- 2. IF ELSIF ELSE to report room status
DO $$
DECLARE
    v_spaces INT;
BEGIN
    SELECT available_spaces INTO v_spaces FROM hostel_rooms WHERE room_id = 2;
    
    IF v_spaces = 0 THEN
        RAISE NOTICE 'Room is full.';
    ELSIF v_spaces = 1 THEN
        RAISE NOTICE 'Room has one space left.';
    ELSE
        RAISE NOTICE 'Room has several spaces.';
    END IF;
END $$;


-- 3. WHILE loop and Numeric FOR loop
DO $$
DECLARE
    v_counter INT := 1;
BEGIN
    WHILE v_counter <= 3 LOOP
        RAISE NOTICE 'Hostel inspection day number %', v_counter;
        v_counter := v_counter + 1;
    END LOOP;

    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Performing room check number %', i;
    END LOOP;
END $$;


-- 4. Create allocate_room procedure
CREATE OR REPLACE PROCEDURE allocate_room(
    p_student_number VARCHAR,
    p_room_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_spaces INT;
BEGIN
    SELECT available_spaces INTO v_spaces 
    FROM hostel_rooms 
    WHERE room_id = p_room_id;

    IF v_spaces <= 0 THEN
        RAISE EXCEPTION 'Allocation failed: Room is full.';
    END IF;

    UPDATE hostel_rooms 
    SET available_spaces = available_spaces - 1 
    WHERE room_id = p_room_id;

    INSERT INTO allocations (student_number, room_id, status)
    VALUES (p_student_number, p_room_id, 'ALLOCATED');
    
    RAISE NOTICE 'Room allocated successfully to student %', p_student_number;
END;
$$;


-- 5. Call for valid and invalid allocations
CALL allocate_room('2026001', 2);
CALL allocate_room('2026002', 3);


-- 6. Create check_out procedure (Idempotent)
CREATE OR REPLACE PROCEDURE check_out(p_allocation_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_room_id INT;
    v_status VARCHAR;
BEGIN
    SELECT room_id, status INTO v_room_id, v_status 
    FROM allocations 
    WHERE allocation_id = p_allocation_id;

    IF v_status = 'CHECKED_OUT' THEN
        RAISE NOTICE 'Allocation % is already checked out. No space freed again.', p_allocation_id;
        RETURN;
    END IF;

    UPDATE hostel_rooms 
    SET available_spaces = available_spaces + 1 
    WHERE room_id = v_room_id;

    UPDATE allocations 
    SET status = 'CHECKED_OUT' 
    WHERE allocation_id = p_allocation_id;

    RAISE NOTICE 'Check out processed successfully for allocation %', p_allocation_id;
END;
$$;

-- Call twice for the same allocation
CALL check_out(1);
CALL check_out(1);


-- 7. Explicit cursor for full or nearly full rooms
DO $$
DECLARE
    cur_rooms CURSOR FOR SELECT room_number, available_spaces FROM hostel_rooms WHERE available_spaces <= 1;
    rec RECORD;
BEGIN
    OPEN cur_rooms;
    LOOP
        FETCH cur_rooms INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Full or nearly full room: %, Spaces left: %', rec.room_number, rec.available_spaces;
    END LOOP;
    CLOSE cur_rooms;
END $$;


-- 8. Attempt allocation using blank student number with EXCEPTION block
DO $$
DECLARE
    v_student VARCHAR := '';
BEGIN
    IF v_student IS NULL OR TRIM(v_student) = '' THEN
        RAISE EXCEPTION 'Invalid input: Student number cannot be blank.';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Caught Exception: %', SQLERRM;
END $$;


-- 9. Final Query
SELECT * FROM hostel_rooms;
SELECT * FROM allocations;
