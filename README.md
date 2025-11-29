# PL-SQL-Last-Group-Work
## System security by monitoring suspicious login  behavior And  Hospital Management Package with Bulk Processing



### 1: Security Monitoring Trigger Implementation

1. Project Overview and Goal 

The goal of this assignment was to implement a system security policy within an Oracle database to monitor and alert on suspicious login behavior. Specifically, the system must detect when a user has three or more failed login attempts on the same day and record the event in a dedicated alerts table.


2. Implementation Details

A. Data Structure (Tables)

Two tables were created to support the policy:
<pre>
Table Name	               Purpose	                                                   Key Columns
login_audit                Stores every single login attempt (success or failure).     username, attempt_time, status (FAILED/SUCCESS).
security_alerts	Stores     Records only when the three-strike policy is breached.      username, failed_count, alert_message.
</pre>


B. Core Logic (The Trigger)

The central piece of the solution is the TRG_DETECT_SUSPICIOUS_LOGIN trigger.
<pre>
Trigger Attribute	  Implementation Detail                 Rationale
  
Event               AFTER INSERT ON login_audit           Fires after a new attempt is recorded.
Condition           WHEN (NEW.status = 'FAILED')          Restricts execution only to failed attempts.
PL/SQL Directive    PRAGMA AUTONOMOUS_TRANSACTION         Crucial. This bypasses Oracle's Mutating Table error, 
                                                          allowing the trigger to query the login_audit table during the insert transaction.
Logic               Counts previous failed attempts       Uses TRUNC() to enforce the "same day" policy. 
                    for the :NEW.username where 
                    TRUNC(attempt_time) = TRUNC(SYSDATE).	
Alert Action        IF v_fail_count >= 2 THEN INSERT      If the autonomous query finds 2 previous failures, the current insert is the 3rd, triggering the alert.
                    INTO security_alerts...	
</pre>


3. Testing and Verification

The policy was verified by running three sequential INSERT statements for a single user (hacker_bob):

    Insert 1 & 2: Only records are added to login_audit. security_alerts remains empty.

    Insert 3: The trigger executes the alert logic, resulting in a new record in security_alerts with failed_count = 3.




### 2: Hospital Management Package Implementation

1. Project Overview and Goal 

The objective was to create a robust PL/SQL package, HOSPITAL_MGMT, to manage patient data, focusing on efficiency through bulk processing and encapsulating core business logic (patient admission, querying status).

2. Implementation Details

A. Data Structure

Standard tables were created for patient and doctor data:

    patients: Stores patient details, including admitted_status (YES/NO).

    doctors: Stores doctor details. (This table was created but not used in the package procedures, as requested by the prompt's focus on patient management).

B. Package Specification

The specification defined the structure and public interface, including necessary types for bulk data handling:

    TYPE patient_rec: A PL/SQL record mapping to patient data columns.

    TYPE patient_list_t: A Collection Type (TABLE OF patient_rec) used to pass multiple patient records into the bulk processing procedure.

    TYPE patient_cursor_t: A REF CURSOR used by the show_all_patients function to return a result set efficiently.


C. Package Body (Logic Implementation)
<pre>
Component            Implementation Detail        Bulk              Rationale
                                                  Processing
                                                  Technique             
bulk_load_patients   Accepts patient_list_t       FORALL            Executes a single SQL INSERT statement for the entire collection, 
                     and inserts all rows.                          drastically reducing context switching between the PL/SQL and SQL engines for superior performance.
                     

show_all_patients    Uses OPEN v_cursor FOR       N/A (Data 	 
                     SELECT...	                 retrieval)        Returns a pointer to the result set, allowing the calling 
                                                                    environment (like SQL Developer) to fetch rows iteratively.

count_admitted       Uses SELECT COUNT(*) WHERE   N/A	             Simple function to track the hospital's capacity status.
                     admitted_status = 'YES'.	
admit_patient        Uses a standard UPDATE .     N/A               Updates a single record based on the patient_id parameter.
                     statement to set 
                     admitted_status = 'YES'
</pre>

3. Testing and Verification

A comprehensive test script was created to validate every component:

    Bulk Load Test: A collection of three patients was populated and passed to bulk_load_patients. Verification confirmed 3 rows were inserted.

    Admission Test: admit_patient was called for two patients (1001 and 1003).

    Counting Test: count_admitted was called before and after admissions, confirming the count changed from 0 to 2.

    Display Test: show_all_patients was called, and the returned cursor was iterated through using a LOOP and FETCH, displaying all patient details, including the updated admitted_status.
