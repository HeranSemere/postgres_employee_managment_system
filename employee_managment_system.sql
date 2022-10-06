CREATE DATABASE employee_managment_system; 

CREATE TYPE employment_status AS ENUM ('active','paid_leave', 'unpaid_leave','halted','suspended');

CREATE TABLE employee(
    employee_id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    password VARCHAR(255) NOT NULL,
    address VARCHAR(255) NOT NULL,
    phone VARCHAR(255) NOT NULL,
    employee_status employment_status NOT NULL,
    UNIQUE(email)
);

-- creates employee, views complaints
CREATE TABLE hr_manager( 
    hr_id SERIAL PRIMARY KEY
)INHERITS(employee);

insert into engineer(name, address, phone, email, password, employee_status) values('abebe','addis abba', '09043232','example@gmail.com','12345', 'active');


CREATE TABLE engineer(
    emp_id SERIAL PRIMARY KEY,
    task_assigned BOOLEAN DEFAULT false
)INHERITS(employee);

CREATE TABLE marketing_rep(
    emp_id SERIAL PRIMARY KEY,
    task_assigned BOOLEAN DEFAULT false
)INHERITS(employee);

CREATE TABLE accountant(
    emp_id SERIAL PRIMARY KEY,
    task_assigned BOOLEAN DEFAULT false
)INHERITS(employee);

--- They will have methods like assign tasks to employees, notifying them what task they will be doing
CREATE TABLE engineering_department_manager(
    emp_id SERIAL PRIMARY KEY
)INHERITS(employee);

CREATE TABLE accounting_department_manager(
    emp_id SERIAL PRIMARY KEY
)INHERITS(employee);

CREATE TABLE marketing_department_manager(
    emp_id SERIAL PRIMARY KEY
)INHERITS(employee);

insert into salary(amount, employee_id) values(1,1);


--- Change ON DELETE, so even if they're deleted, their salary detail can be kept here for tax purposes
CREATE TABLE salary(
    salary_id SERIAL PRIMARY KEY,
    amount INT NOT NULL,
    employee_id INT NOT NULL,
    date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_employee_salary 
      FOREIGN KEY(employee_id) 
	  REFERENCES employee(employee_id)  
      ON DELETE SET NULL 
);



insert into salary_amount(amount, employee_type) values (30000,'engineer');

CREATE TABLE salary_amount( 
    amount_id SERIAL NOT NULL,
    amount NUMERIC,
    employee_type text NOT NULL
)PARTITION BY RANGE(amount);

CREATE TABLE small_paid
PARTITION OF salary_amount FOR VALUES FROM (MINVALUE) TO (10000);

CREATE TABLE medium_paid
PARTITION OF salary_amount FOR VALUES FROM (10000) TO (30000);

CREATE TABLE high_paid
PARTITION OF salary_amount FOR VALUES FROM (30000) TO (70000);

insert into salary_amount(amount, employee_type) values (20000,'engineer');
insert into salary_amount(amount, employee_type) values (7000,'accountant');
insert into salary_amount(amount, employee_type) values (60000,'hr_manager');

select * from medium_paid;


insert into engineering_task(assigned_employee,assigned,task_description,date_assigned) values(1,true,'Level ground',CURRENT_TIMESTAMP);


CREATE TABLE engineering_task(  
    task_id SERIAL PRIMARY KEY,
    assigned_employee INT,   
    assigned BOOLEAN NOT NULL DEFAULT false,
    task_description VARCHAR(255) NOT NULL,
    date_created TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    date_assigned TIMESTAMP,
    complete BOOLEAN NOT NULL DEFAULT false
);

-- maybe add some null constraints and foreign key constraints 
CREATE TABLE accounting_task(  
    task_id SERIAL PRIMARY KEY,
    assigned_employee INT,   
    assigned BOOLEAN NOT NULL DEFAULT false,
    task_description VARCHAR(255) NOT NULL,
    date_created TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    date_assigned TIMESTAMP,
    complete BOOLEAN NOT NULL DEFAULT false
);

-- maybe add some null constraints and foreign key constraints
CREATE TABLE marketing_task(   
    task_id SERIAL PRIMARY KEY,
    assigned_employee INT,   
    assigned BOOLEAN NOT NULL DEFAULT false,
    task_description VARCHAR(255) NOT NULL,
    date_created TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    date_assigned TIMESTAMP,
    complete BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE Leave_request(
    leave_id SERIAL PRIMARY KEY,
    employee_id INT NOT NULL,
    resolved BOOLEAN NOT NULL DEFAULT false,
    start_date DATE NOT NULL,
    end_date  DATE NOT NULL,
    CONSTRAINT fk_employee_leave
      FOREIGN KEY(employee_id) 
	  REFERENCES employee(employee_id)
      ON DELETE CASCADE
);



select payout_salary(Array[1,2,3], 'engineer');
-- use locks before updating salary 

CREATE or REPLACE FUNCTION payout_salary(employee_ids INT[], employee_type TEXT) RETURNS void AS
$$
DECLARE
    e_type alias for $2;
    amount INT;
    id INT;
BEGIN
    raise notice 'Paid employees';
    select sa.amount from salary_amount sa where sa.employee_type = e_type into amount;
    If amount > 0 THEN
        FOREACH id IN ARRAY employee_ids
        loop  
            insert into salary(amount,employee_id) values (amount,id);
        end loop; 
    END IF; 
end;
$$ language 'plpgsql';

 
CREATE or REPLACE FUNCTION payout_salary(employee_ids INT[], employee_type TEXT, bonus INT) RETURNS void AS
$$
DECLARE
    e_type alias for $2;
    amount INT;
    id INT;
BEGIN
    raise notice 'Paid employees with bonus';
    select sa.amount from salary_amount sa where sa.employee_type = e_type into amount;
    If amount > 0 THEN
        amount = amount + bonus;
        FOREACH id IN ARRAY employee_ids
        loop  
            insert into salary(amount,employee_id) values (amount,id);
        end loop; 
    END IF; 
end;
$$ language 'plpgsql';



CREATE or REPLACE FUNCTION assign_task(employee employee, taskID INT) RETURNS void AS  
$$
DECLARE
    emp alias for $1;
    taskID alias for $2;
BEGIN
    UPDATE employee_task SET assigned = true, date_assigned =  CURRENT_TIMESTAMP, assigned_employee = emp.emp_id WHERE task_id = taskID;
    UPDATE employee SET task_assigned = true where employee_id = emp.employee_id;
END;
$$ language 'plpgsql';

select assign_task(engineer, 1) from engineer; 
-- add lock when updating database 

CREATE or REPLACE FUNCTION assign_task(engineer engineer, taskID INT) RETURNS void AS
$$
DECLARE
    emp alias for $1;
    taskID alias for $2;
BEGIN
    UPDATE engineering_task SET assigned = true, date_assigned =  CURRENT_TIMESTAMP, assigned_employee = emp.emp_id WHERE task_id = taskID;
    UPDATE engineer SET task_assigned = true where emp_id = emp.emp_id;
END;
$$ language 'plpgsql';


-- add lock when updating database 
CREATE or REPLACE FUNCTION assign_task(accountant accountant, taskID INT) RETURNS void AS
$$
DECLARE
    emp alias for $1;
    taskID alias for $2;
BEGIN
    UPDATE accounting_task SET assigned = true, date_assigned =  CURRENT_TIMESTAMP, assigned_employee = emp.emp_id WHERE task_id = taskID;
    UPDATE accountant SET task_assigned = true where emp_id = emp.emp_id;
END;
$$ language 'plpgsql';

-- add lock when updating database 
CREATE or REPLACE FUNCTION assign_task(marketing_rep marketing_rep, taskID INT) RETURNS void AS
$$
DECLARE
    emp alias for $1;
    taskID alias for $2;
BEGIN
    UPDATE marketing_task SET assigned = true, date_assigned =  CURRENT_TIMESTAMP, assigned_employee = emp.emp_id WHERE task_id = taskID;
    UPDATE marketing_rep SET task_assigned = true where emp_id = emp.emp_id;
END;
$$ language 'plpgsql';

-- vertical partition task assignment 
CREATE or REPLACE FUNCTION vertical_partition_engineering_task() RETURNS void AS
$$
DECLARE
    et RECORD;
BEGIN
CREATE TABLE engineering_task_assignment(  
            task_id SERIAL PRIMARY KEY,
            assigned_employee INT,   
            assigned BOOLEAN NOT NULL DEFAULT false,
            date_created TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            date_assigned TIMESTAMP,
            complete BOOLEAN NOT NULL DEFAULT false
        
        );

    CREATE TABLE engineering_task_declration(  
            task_id SERIAL PRIMARY KEY,
            task_description VARCHAR(255) NOT NULL,
            complete BOOLEAN NOT NULL DEFAULT false
        );

    FOR et IN
       SELECT * FROM engineering_task
    LOOP
        insert into engineering_task_assignment(assigned_employee, assigned, date_created, date_assigned, complete) values (et.assigned_employee, et.assigned, et.date_created, et.date_assigned, et.complete);
        insert into engineering_task_declration(task_description, complete) values (et.task_description, et.complete);
    END LOOP;

END;
$$ language 'plpgsql';



CREATE or REPLACE FUNCTION vertical_partition_marketing_task() RETURNS void AS
$$
DECLARE
    et RECORD;
BEGIN
CREATE TABLE marketing_task_assignment(  
            task_id SERIAL PRIMARY KEY,
            assigned_employee INT,   
            assigned BOOLEAN NOT NULL DEFAULT false,
            date_created TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            date_assigned TIMESTAMP,
            complete BOOLEAN NOT NULL DEFAULT false
        );

    CREATE TABLE marketing_task_declration(  
            task_id SERIAL PRIMARY KEY,
            task_description VARCHAR(255) NOT NULL,
            complete BOOLEAN NOT NULL DEFAULT false
        );

    FOR et IN
       SELECT * FROM marketing_task
    LOOP
        insert into marketing_task_assignment(assigned_employee, assigned, date_created, date_assigned, complete) values (et.assigned_employee, et.assigned, et.date_created, et.date_assigned, et.complete);
        insert into marketing_task_declration(task_description, complete) values (et.task_description, et.complete);
    END LOOP;

END;
$$ language 'plpgsql';


CREATE or REPLACE FUNCTION vertical_partition_accountant_task() RETURNS void AS
$$
DECLARE
    et RECORD;
BEGIN
CREATE TABLE accountant_task_assignment(  
            task_id SERIAL PRIMARY KEY,
            assigned_employee INT,   
            assigned BOOLEAN NOT NULL DEFAULT false,
            date_created TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            date_assigned TIMESTAMP,
            complete BOOLEAN NOT NULL DEFAULT false
        );

    CREATE TABLE accountant_task_declration(  
            task_id SERIAL PRIMARY KEY,
            task_description VARCHAR(255) NOT NULL,
            complete BOOLEAN NOT NULL DEFAULT false
        );

    FOR et IN
       SELECT * FROM accountant_task
    LOOP
        insert into accountant_task_assignment(assigned_employee, assigned, date_created, date_assigned, complete) values (et.assigned_employee, et.assigned, et.date_created, et.date_assigned, et.complete);
        insert into accountant_task_declration(task_description, complete) values (et.task_description, et.complete);
    END LOOP;

END;
$$ language 'plpgsql';

    

CREATE or REPLACE FUNCTION remove_employee(id int) RETURNS void AS  
$$
DECLARE  
    e_type text;
BEGIN
    SELECT p.relname FROM employee e, pg_class p WHERE e.tableoid = p.oid AND employee_id = id into e_type;
    case e_type
		when 'engineer' then
			DELETE from engineer WHERE emp_id = id;
            raise notice 'Employee removed';
		when 'marketing_rep' then
            DELETE from marketing_rep WHERE emp_id = id;
            raise notice 'Employee removed';
        when 'accountant' then
            DELETE from accountant WHERE emp_id = id;
            raise notice 'Employee removed';
        when 'engineering_department_manager' then
           DELETE from engineering_department_manager WHERE emp_id = id;
            raise notice 'Employee removed';
        when 'marketing_department_manager' then
            DELETE from marketing_department_manager WHERE emp_id = id;
            raise notice 'Employee removed';
        when 'accounting_department_manager' then
            DELETE from accounting_department_manager WHERE emp_id = id;
            raise notice 'Employee removed'; 
        else
            raise notice 'Not found';
	end case;
END;	
$$
LANGUAGE plpgsql;

