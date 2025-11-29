-- Q4. Scenario: Hospital Management Package with Bulk Processing 



-- 1. Create the DOCTORS table
CREATE TABLE doctors (
    doctor_id   NUMBER PRIMARY KEY,
    doctor_name VARCHAR2(100) NOT NULL,
    specialty   VARCHAR2(100)
);




-- 2. Create the PATIENTS table
CREATE TABLE patients (
    patient_id      NUMBER PRIMARY KEY,
    patient_name    VARCHAR2(100) NOT NULL,
    age             NUMBER,
    gender          VARCHAR2(10),
    admitted_status VARCHAR2(10) DEFAULT 'NO' NOT NULL -- 'YES' or 'NO'
);




-- 3. Package Specification: 

CREATE OR REPLACE PACKAGE hospital_mgmt IS

    -- 1. Define a Record Type for a single patient (for collection structure)
    TYPE patient_rec IS RECORD (
        p_id   patients.patient_id%TYPE,
        p_name patients.patient_name%TYPE,
        p_age  patients.age%TYPE,
        p_gender patients.gender%TYPE
    );

    -- 2. Define a Collection Type (Table of Records) for bulk processing
    TYPE patient_list_t IS TABLE OF patient_rec INDEX BY PLS_INTEGER;

    -- 3. Define a REF CURSOR type for returning result sets (like show_all_patients)
    TYPE patient_cursor_t IS REF CURSOR;

    -- 4. Procedure for Bulk Insertion (Requirement 2.a)
    PROCEDURE bulk_load_patients (
        p_patient_data IN patient_list_t
    );

    -- 5. Function to Display All Patients (Requirement 2.b)
    FUNCTION show_all_patients RETURN patient_cursor_t;

    -- 6. Function to Count Admitted Patients (Requirement 2.c)
    FUNCTION count_admitted RETURN NUMBER;

    -- 7. Procedure to Update Admitted Status (Requirement 2.d)
    PROCEDURE admit_patient (
        p_patient_id IN patients.patient_id%TYPE
    );

END hospital_mgmt;
/





CREATE OR REPLACE PACKAGE BODY hospital_mgmt IS

    -- Implementation of bulk_load_patients
    PROCEDURE bulk_load_patients (
        p_patient_data IN patient_list_t
    ) IS
    BEGIN
        -- Use FORALL for bulk DML (Data Manipulation Language) insertion
        -- This executes a single SQL INSERT statement for the entire collection, greatly improving performance.
        FORALL i IN p_patient_data.FIRST .. p_patient_data.LAST
            INSERT INTO patients (patient_id, patient_name, age, gender, admitted_status)
            VALUES (
                p_patient_data(i).p_id,
                p_patient_data(i).p_name,
                p_patient_data(i).p_age,
                p_patient_data(i).p_gender,
                'NO' -- Default status upon loading
            );
        
        -- Commit the transaction to make the new records permanent
        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            -- In a real application, you would log the error
            RAISE_APPLICATION_ERROR(-20001, 'Error loading patients: ' || SQLERRM);
            ROLLBACK;
    END bulk_load_patients;

    -- Implementation of show_all_patients
    FUNCTION show_all_patients RETURN patient_cursor_t IS
        v_cursor patient_cursor_t;
    BEGIN
        OPEN v_cursor FOR
            SELECT patient_id, patient_name, age, gender, admitted_status
            FROM patients
            ORDER BY patient_id;
            
        RETURN v_cursor;
    END show_all_patients;

    -- Implementation of count_admitted
    FUNCTION count_admitted RETURN NUMBER IS
        v_admitted_count NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO v_admitted_count
        FROM patients
        WHERE admitted_status = 'YES';
        
        RETURN v_admitted_count;
    END count_admitted;

    -- Implementation of admit_patient
    PROCEDURE admit_patient (
        p_patient_id IN patients.patient_id%TYPE
    ) IS
    BEGIN
        UPDATE patients
        SET admitted_status = 'YES'
        WHERE patient_id = p_patient_id;
        
        -- Commit the update
        COMMIT;
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20002, 'Patient ID ' || p_patient_id || ' not found.');
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20003, 'Error admitting patient: ' || SQLERRM);
            ROLLBACK;
    END admit_patient;

END hospital_mgmt;
/



-- ========================================================
-- TESSTING 
-- ========================================================


SET SERVEROUTPUT ON;

-- Clear tables before testing
DELETE FROM patients;
COMMIT;

DECLARE
    -- Declare a collection variable using the package type
    v_patient_data hospital_mgmt.patient_list_t;
    
    -- Declare a cursor variable to hold the results of the function
    v_patient_cursor hospital_mgmt.patient_cursor_t;
    
    -- Variables to read ALL columns from the cursor (CORRECTED DECLARATIONS)
    v_p_id          patients.patient_id%TYPE;
    v_p_name        patients.patient_name%TYPE;
    v_p_age         patients.age%TYPE;       -- New variable for age
    v_p_gender      patients.gender%TYPE;    -- New variable for gender
    v_p_status      patients.admitted_status%TYPE; -- Renamed for clarity
    
    v_admitted_count NUMBER;

BEGIN
    -- ====================================================================
    -- 1. TEST: bulk_load_patients
    -- ====================================================================
    DBMS_OUTPUT.PUT_LINE('--- 1. Testing Bulk Load ---');
    
    -- Populate the collection with multiple patient records
    v_patient_data(1).p_id := 1001;
    v_patient_data(1).p_name := 'Alice Smith';
    v_patient_data(1).p_age := 35;
    v_patient_data(1).p_gender := 'F';

    v_patient_data(2).p_id := 1002;
    v_patient_data(2).p_name := 'Bob Johnson';
    v_patient_data(2).p_age := 62;
    v_patient_data(2).p_gender := 'M';
    
    v_patient_data(3).p_id := 1003;
    v_patient_data(3).p_name := 'Charlie Brown';
    v_patient_data(3).p_age := 12;
    v_patient_data(3).p_gender := 'M';

    -- Call the bulk insertion procedure
    hospital_mgmt.bulk_load_patients(v_patient_data);
    
    -- The SQL%ROWCOUNT inside the procedure pertains to the FORALL statement. 
    -- We can verify the count by querying the table immediately afterwards.
    SELECT COUNT(*) INTO v_admitted_count FROM patients; 
    DBMS_OUTPUT.PUT_LINE('Inserted ' || v_admitted_count || ' patients using bulk processing.');
    
    -- ====================================================================
    -- 2. TEST: show_all_patients (Cursor Logic Correction)
    -- ====================================================================
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- 2. Testing Show All Patients ---');
    
    v_patient_cursor := hospital_mgmt.show_all_patients;
    
    -- Refined Header for clarity
    DBMS_OUTPUT.PUT_LINE(RPAD('ID', 5) || RPAD('NAME', 20) || RPAD('AGE', 5) || RPAD('GENDER', 8) || 'ADMITTED');
    DBMS_OUTPUT.PUT_LINE('----------------------------------------------------');
    
    LOOP
        -- CORRECTED: Fetching all 5 columns into dedicated variables
        FETCH v_patient_cursor 
        INTO v_p_id, v_p_name, v_p_age, v_p_gender, v_p_status;
        
        EXIT WHEN v_patient_cursor%NOTFOUND;
        
        -- Displaying all 5 columns
        DBMS_OUTPUT.PUT_LINE(
            RPAD(v_p_id, 5) || 
            RPAD(v_p_name, 20) || 
            RPAD(v_p_age, 5) || 
            RPAD(v_p_gender, 8) || 
            v_p_status
        );
    END LOOP;
    CLOSE v_patient_cursor;

    -- ====================================================================
    -- 3. TEST: admit_patient and count_admitted
    -- ====================================================================
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- 3. Testing Admission Status ---');

    -- Check initial count (should be 0)
    v_admitted_count := hospital_mgmt.count_admitted;
    DBMS_OUTPUT.PUT_LINE('Initial Admitted Count: ' || v_admitted_count); -- Expected: 0

    -- Admit two patients
    DBMS_OUTPUT.PUT_LINE('Admitting Patient 1001...');
    hospital_mgmt.admit_patient(1001);
    
    DBMS_OUTPUT.PUT_LINE('Admitting Patient 1003...');
    hospital_mgmt.admit_patient(1003);

    -- Check final count (should be 2)
    v_admitted_count := hospital_mgmt.count_admitted;
    DBMS_OUTPUT.PUT_LINE('Final Admitted Count: ' || v_admitted_count); -- Expected: 2
    
    -- Final check on the admitted status in the table (optional)
    SELECT admitted_status INTO v_p_status FROM patients WHERE patient_id = 1001;
    DBMS_OUTPUT.PUT_LINE('Patient 1001 Status Check: ' || v_p_status); -- Expected: YES

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Test failed with unhandled error: ' || SQLERRM);
        ROLLBACK;
END;
/