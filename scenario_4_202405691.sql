-- Scenario 4: Campus Clinic Medicine Dispensing

CREATE TABLE medicines (
    medicine_id SERIAL PRIMARY KEY,
    medicine_name VARCHAR(100),
    stock_quantity INT
);

CREATE TABLE dispensing_records (
    record_id SERIAL PRIMARY KEY,
    student_number VARCHAR(50),
    medicine_id INT REFERENCES medicines(medicine_id),
    quantity INT,
    status VARCHAR(50) DEFAULT 'DISPENSED'
);

-- Add at least three medicines
INSERT INTO medicines (medicine_name, stock_quantity) VALUES 
('Paracetamol', 0),
('Ibuprofen', 4),
('Amoxicillin', 50);


-- 2. IF ELSIF ELSE to report stock status
DO $$
DECLARE
    v_stock INT;
BEGIN
    SELECT stock_quantity INTO v_stock FROM medicines WHERE medicine_id = 1;
    
    IF v_stock = 0 THEN
        RAISE NOTICE 'Medicine is out of stock.';
    ELSIF v_stock < 10 THEN
        RAISE NOTICE 'Medicine is low on stock.';
    ELSE
        RAISE NOTICE 'Medicine is sufficiently stocked.';
    END IF;
END $$;


-- 3. WHILE loop and Numeric FOR loop
DO $$
DECLARE
    v_counter INT := 1;
BEGIN
    WHILE v_counter <= 3 LOOP
        RAISE NOTICE 'Stock review day number %', v_counter;
        v_counter := v_counter + 1;
    END LOOP;

    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Shelf inspection number %', i;
    END LOOP;
END $$;


-- 4. Create dispense_medicine procedure
CREATE OR REPLACE PROCEDURE dispense_medicine(
    p_student_number VARCHAR,
    p_medicine_id INT,
    p_quantity INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_stock INT;
BEGIN
    SELECT stock_quantity INTO v_stock 
    FROM medicines 
    WHERE medicine_id = p_medicine_id;

    IF v_stock < p_quantity THEN
        RAISE EXCEPTION 'Dispensing failed: Requested quantity exceeds available stock.';
    END IF;

    UPDATE medicines 
    SET stock_quantity = stock_quantity - p_quantity 
    WHERE medicine_id = p_medicine_id;

    INSERT INTO dispensing_records (student_number, medicine_id, quantity, status)
    VALUES (p_student_number, p_medicine_id, p_quantity, 'DISPENSED');
    
    RAISE NOTICE 'Medicine dispensed successfully.';
END;
$$;


-- 5. Call for valid quantities
CALL dispense_medicine('2026101', 2, 2);
CALL dispense_medicine('2026102', 3, 5);


-- 6. Create reverse_dispensing procedure (Idempotent)
CREATE OR REPLACE PROCEDURE reverse_dispensing(p_record_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_med_id INT;
    v_qty INT;
    v_status VARCHAR;
BEGIN
    SELECT medicine_id, quantity, status 
    INTO v_med_id, v_qty, v_status 
    FROM dispensing_records 
    WHERE record_id = p_record_id;

    IF v_status = 'REVERSED' THEN
        RAISE NOTICE 'Record % is already reversed. Stock not restored again.', p_record_id;
        RETURN;
    END IF;

    UPDATE medicines 
    SET stock_quantity = stock_quantity + v_qty 
    WHERE medicine_id = v_med_id;

    UPDATE dispensing_records 
    SET status = 'REVERSED' 
    WHERE record_id = p_record_id;

    RAISE NOTICE 'Dispensing record % reversed and stock restored.', p_record_id;
END;
$$;

-- Call twice for idempotency
CALL reverse_dispensing(1);
CALL reverse_dispensing(1);


-- 7. Explicit cursor for low stock threshold (< 10)
DO $$
DECLARE
    cur_meds CURSOR FOR SELECT medicine_name, stock_quantity FROM medicines WHERE stock_quantity < 10;
    rec RECORD;
BEGIN
    OPEN cur_meds;
    LOOP
        FETCH cur_meds INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low stock medicine: %, Quantity remaining: %', rec.medicine_name, rec.stock_quantity;
    END LOOP;
    CLOSE cur_meds;
END $$;


-- 8. Negative quantity check with EXCEPTION block
DO $$
DECLARE
    v_qty INT := -5;
BEGIN
    IF v_qty < 0 THEN
        RAISE EXCEPTION 'Invalid input: Dispensing quantity cannot be negative.';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Caught Exception: %', SQLERRM;
END $$;


-- 9. Final Query
SELECT * FROM medicines;
SELECT * FROM dispensing_records;