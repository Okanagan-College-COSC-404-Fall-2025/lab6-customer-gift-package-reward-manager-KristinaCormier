-- Part A

CREATE OR REPLACE TYPE gift_item_list AS TABLE OF VARCHAR2(100);
/


CREATE TABLE gift_catalog (
    gift_id       NUMBER PRIMARY KEY,
    min_purchase  NUMBER,
    gifts         gift_item_list
)
NESTED TABLE gifts STORE AS gift_catalog_gifts_nt;


INSERT INTO gift_catalog
VALUES (1, 100, gift_item_list('Stickers', 'Pen Set'));

INSERT INTO gift_catalog
VALUES (2, 1000, gift_item_list('Teddy Bear', 'Mug', 'Perfume Sample'));

INSERT INTO gift_catalog
VALUES (3, 10000, gift_item_list('Backpack', 'Thermos Bottle', 'Chocolate Collection'));

COMMIT;


-- Part B

CREATE TABLE customer_rewards (
    reward_id        NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_email   VARCHAR2(255) NOT NULL,
    gift_id          NUMBER NOT NULL,
    reward_date      DATE DEFAULT SYSDATE,
    CONSTRAINT fk_customer_rewards_gift
        FOREIGN KEY (gift_id)
        REFERENCES gift_catalog (gift_id),
    CONSTRAINT fk_customer_rewards_customer
        FOREIGN KEY (customer_email)
        REFERENCES customers (email_address)
);
/


-- Part C

CREATE OR REPLACE PACKAGE customer_manager AS

    FUNCTION get_total_purchase(p_customer_id IN NUMBER)
        RETURN NUMBER;

    PROCEDURE assign_gifts_to_all;

END customer_manager;
/


CREATE OR REPLACE PACKAGE BODY customer_manager AS

    ------------------------------------------------------------------
    -- PRIVATE FUNCTION: choose gift package
    ------------------------------------------------------------------
    FUNCTION choose_gift_package(p_total_purchase IN NUMBER)
        RETURN NUMBER
    IS
        v_gift_id NUMBER;
    BEGIN
        CASE
            WHEN p_total_purchase > 0 THEN
                BEGIN
                    SELECT gift_id
                    INTO v_gift_id
                    FROM gift_catalog
                    WHERE min_purchase <= p_total_purchase
                    ORDER BY min_purchase DESC
                    FETCH FIRST 1 ROW ONLY;

                    RETURN v_gift_id;

                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        RETURN NULL;
                END;
            ELSE
                RETURN NULL;
        END CASE;
    END choose_gift_package;


    ------------------------------------------------------------------
    -- PUBLIC FUNCTION: compute total purchase for a customer
    ------------------------------------------------------------------
    FUNCTION get_total_purchase(p_customer_id IN NUMBER)
        RETURN NUMBER
    IS
        v_total NUMBER := 0;
    BEGIN
        SELECT NVL(SUM(oi.quantity * oi.unit_price), 0)
        INTO v_total
        FROM orders o
        JOIN order_items oi
            ON o.order_id = oi.order_id
        WHERE o.customer_id = p_customer_id;

        RETURN v_total;
    END get_total_purchase;


    ------------------------------------------------------------------
    -- PUBLIC PROCEDURE: assign gifts to all customers
    ------------------------------------------------------------------
    PROCEDURE assign_gifts_to_all
    IS
        v_total   NUMBER;
        v_gift_id NUMBER;
    BEGIN
        FOR cust IN (SELECT customer_id, email_address FROM customers) LOOP

            v_total := get_total_purchase(cust.customer_id);
            v_gift_id := choose_gift_package(v_total);

            IF v_gift_id IS NOT NULL THEN
                INSERT INTO customer_rewards (customer_email, gift_id)
                VALUES (cust.email_address, v_gift_id);
            END IF;

        END LOOP;

        COMMIT;
    END assign_gifts_to_all;

END customer_manager;
/


-- Part D

SET SERVEROUTPUT ON;

CREATE OR REPLACE PROCEDURE show_first_five_rewards AS
    v_items      VARCHAR2(1000);
    v_gift_items gift_item_list;  -- local variable of the VARRAY type
BEGIN
    FOR cust_rec IN (
        SELECT cr.customer_email, cr.gift_id
        FROM customer_rewards cr
        WHERE ROWNUM <= 5
    ) LOOP

        -- Fetch gifts into local VARRAY variable using table alias
        SELECT gc.gifts
        INTO v_gift_items
        FROM gift_catalog gc
        WHERE gc.gift_id = cust_rec.gift_id;

        -- Build comma-separated string
        v_items := '';
        IF v_gift_items IS NOT NULL THEN
            FOR i IN 1 .. v_gift_items.COUNT LOOP
                IF i > 1 THEN
                    v_items := v_items || ', ';
                END IF;
                v_items := v_items || v_gift_items(i);
            END LOOP;
        ELSE
            v_items := 'No items';
        END IF;

        -- Display result
        DBMS_OUTPUT.PUT_LINE(
            'Customer: ' || cust_rec.customer_email ||
            ', Gift ID: ' || cust_rec.gift_id ||
            ', Items: ' || v_items
        );

    END LOOP;
END show_first_five_rewards;
/










