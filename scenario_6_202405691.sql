-- Scenario 6: University Event Seat Booking

CREATE TABLE events (
    event_id SERIAL PRIMARY KEY,
    event_name VARCHAR(100),
    available_seats INT
);

CREATE TABLE bookings (
    booking_id SERIAL PRIMARY KEY,
    student_number VARCHAR(50),
    event_id INT REFERENCES events(event_id),
    num_seats INT,
    status VARCHAR(50) DEFAULT 'BOOKED'
);

-- Add at least three events
INSERT INTO events (event_name, available_seats) VALUES 
('Graduation Ceremony', 1),
('Tech Symposium', 20),
('Annual Gala', 0);


-- 2. IF ELSIF ELSE to report event seat status
DO $$
DECLARE
    v_seats INT;
BEGIN
    SELECT available_seats INTO v_seats FROM events WHERE event_id = 1;
    
    IF v_seats = 0 THEN
        RAISE NOTICE 'Event is full.';
    ELSIF v_seats < 5 THEN
        RAISE NOTICE 'Event is nearly full.';
    ELSE
        RAISE NOTICE 'Event has plenty of seats.';
    END IF;
END $$;


-- 3. WHILE loop and Numeric FOR loop
DO $$
DECLARE
    v_counter INT := 1;
BEGIN
    WHILE v_counter <= 3 LOOP
        RAISE NOTICE 'Booking reminder day number %', v_counter;
        v_counter := v_counter + 1;
    END LOOP;

    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Entrance check number %', i;
    END LOOP;
END $$;


-- 4. Create book_seats procedure
CREATE OR REPLACE PROCEDURE book_seats(
    p_student_number VARCHAR,
    p_event_id INT,
    p_num_seats INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_seats INT;
BEGIN
    SELECT available_seats INTO v_seats 
    FROM events 
    WHERE event_id = p_event_id;

    IF v_seats < p_num_seats THEN
        RAISE EXCEPTION 'Booking failed: Requested seats exceed remaining availability.';
    END IF;

    UPDATE events 
    SET available_seats = available_seats - p_num_seats 
    WHERE event_id = p_event_id;

    INSERT INTO bookings (student_number, event_id, num_seats, status)
    VALUES (p_student_number, p_event_id, p_num_seats, 'BOOKED');
    
    RAISE NOTICE 'Seats booked successfully.';
END;
$$;


-- 5. Call for valid bookings
CALL book_seats('2026201', 2, 2);
CALL book_seats('2026202', 2, 3);


-- 6. Create cancel_booking procedure (Idempotent)
CREATE OR REPLACE PROCEDURE cancel_booking(p_booking_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_event_id INT;
    v_seats INT;
    v_status VARCHAR;
BEGIN
    SELECT event_id, num_seats, status 
    INTO v_event_id, v_seats, v_status 
    FROM bookings 
    WHERE booking_id = p_booking_id;

    IF v_status = 'CANCELLED' THEN
        RAISE NOTICE 'Booking % is already cancelled. Seats not released again.', p_booking_id;
        RETURN;
    END IF;

    UPDATE events 
    SET available_seats = available_seats + v_seats 
    WHERE event_id = v_event_id;

    UPDATE bookings 
    SET status = 'CANCELLED' 
    WHERE booking_id = p_booking_id;

    RAISE NOTICE 'Booking % cancelled and seats released.', p_booking_id;
END;
$$;

-- Call twice to test idempotency
CALL cancel_booking(1);
CALL cancel_booking(1);


-- 7. Explicit cursor for full or nearly full events
DO $$
DECLARE
    cur_events CURSOR FOR SELECT event_name, available_seats FROM events WHERE available_seats < 5;
    rec RECORD;
BEGIN
    OPEN cur_events;
    LOOP
        FETCH cur_events INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Full or nearly full event: %, Seats left: %', rec.event_name, rec.available_seats;
    END LOOP;
    CLOSE cur_events;
END $$;


-- 8. Try to book zero seats with EXCEPTION block
DO $$
DECLARE
    v_seats INT := 0;
BEGIN
    IF v_seats <= 0 THEN
        RAISE EXCEPTION 'Invalid quantity: Cannot book zero or negative seats.';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Caught Exception: %', SQLERRM;
END $$;


-- 9. Final Query
SELECT * FROM events;
SELECT * FROM bookings;
