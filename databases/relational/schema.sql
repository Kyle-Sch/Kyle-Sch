-- =============================================================================
-- schema.sql
-- E-commerce order management schema
-- Compatible with: SQL Server 2019+ and PostgreSQL 15+ (notes where dialects differ)
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

CREATE TABLE customers (
    customer_id     INT             NOT NULL,   -- GENERATED ALWAYS AS IDENTITY in PG
    email           VARCHAR(255)    NOT NULL,
    first_name      VARCHAR(100)    NOT NULL,
    last_name       VARCHAR(100)    NOT NULL,
    phone           VARCHAR(30)     NULL,
    created_at      DATETIME        NOT NULL DEFAULT GETDATE(),  -- NOW() in PG
    updated_at      DATETIME        NOT NULL DEFAULT GETDATE(),
    is_active       BIT             NOT NULL DEFAULT 1,

    CONSTRAINT pk_customers PRIMARY KEY (customer_id),
    CONSTRAINT uq_customers_email UNIQUE (email)
);

CREATE TABLE products (
    product_id      INT             NOT NULL,
    sku             VARCHAR(50)     NOT NULL,
    name            VARCHAR(255)    NOT NULL,
    description     NVARCHAR(MAX)   NULL,       -- TEXT in PG
    unit_price      DECIMAL(10, 2)  NOT NULL,
    stock_qty       INT             NOT NULL DEFAULT 0,
    category        VARCHAR(100)    NOT NULL,
    is_active       BIT             NOT NULL DEFAULT 1,
    created_at      DATETIME        NOT NULL DEFAULT GETDATE(),

    CONSTRAINT pk_products       PRIMARY KEY (product_id),
    CONSTRAINT uq_products_sku   UNIQUE (sku),
    CONSTRAINT chk_price_positive CHECK (unit_price >= 0),
    CONSTRAINT chk_stock_positive CHECK (stock_qty  >= 0)
);

CREATE TABLE orders (
    order_id        INT             NOT NULL,
    customer_id     INT             NOT NULL,
    status          VARCHAR(30)     NOT NULL DEFAULT 'pending',
    shipping_addr   NVARCHAR(500)   NULL,
    subtotal        DECIMAL(12, 2)  NOT NULL DEFAULT 0,
    tax_amount      DECIMAL(12, 2)  NOT NULL DEFAULT 0,
    total_amount    DECIMAL(12, 2)  NOT NULL DEFAULT 0,
    placed_at       DATETIME        NOT NULL DEFAULT GETDATE(),
    updated_at      DATETIME        NOT NULL DEFAULT GETDATE(),
    notes           NVARCHAR(1000)  NULL,

    CONSTRAINT pk_orders            PRIMARY KEY (order_id),
    CONSTRAINT fk_orders_customer   FOREIGN KEY (customer_id)
        REFERENCES customers (customer_id),
    CONSTRAINT chk_order_status CHECK (
        status IN ('pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded')
    )
);

CREATE TABLE order_items (
    item_id         INT             NOT NULL,
    order_id        INT             NOT NULL,
    product_id      INT             NOT NULL,
    quantity        INT             NOT NULL,
    unit_price      DECIMAL(10, 2)  NOT NULL,   -- snapshot price at time of order
    line_total      DECIMAL(12, 2)  NOT NULL,

    CONSTRAINT pk_order_items           PRIMARY KEY (item_id),
    CONSTRAINT fk_order_items_order     FOREIGN KEY (order_id)
        REFERENCES orders (order_id) ON DELETE CASCADE,
    CONSTRAINT fk_order_items_product   FOREIGN KEY (product_id)
        REFERENCES products (product_id),
    CONSTRAINT chk_quantity_positive    CHECK (quantity > 0),
    CONSTRAINT chk_line_total           CHECK (line_total >= 0)
);

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------

-- Customer lookups by email (covered by UQ, but explicit for readability)
CREATE INDEX ix_customers_email
    ON customers (email)
    WHERE is_active = 1;                -- Filtered index; omit WHERE clause in PG

-- Orders by customer — common query pattern
CREATE INDEX ix_orders_customer_id
    ON orders (customer_id)
    INCLUDE (status, total_amount, placed_at);

-- Orders by status — for fulfilment dashboards
CREATE INDEX ix_orders_status_placed
    ON orders (status, placed_at DESC);

-- Order items by product — for inventory and sales reporting
CREATE INDEX ix_order_items_product
    ON order_items (product_id)
    INCLUDE (quantity, line_total);

-- Product catalogue by category
CREATE INDEX ix_products_category
    ON products (category, is_active)
    INCLUDE (sku, name, unit_price);

-- ---------------------------------------------------------------------------
-- Stored Procedure: usp_PlaceOrder
-- Creates an order with its items inside a transaction.
-- Validates stock, decrements inventory, and calculates totals.
--
-- SQL Server syntax; adapt BEGIN/EXCEPTION blocks for PostgreSQL.
-- ---------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE usp_PlaceOrder
    @customer_id    INT,
    @shipping_addr  NVARCHAR(500),
    @items          NVARCHAR(MAX),      -- JSON: [{"product_id":1,"quantity":2}, ...]
    @new_order_id   INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Parse the items JSON array
        -- Requires SQL Server 2016+ (OPENJSON)
        DECLARE @parsed TABLE (
            product_id  INT  NOT NULL,
            quantity    INT  NOT NULL
        );

        INSERT INTO @parsed (product_id, quantity)
        SELECT
            CAST(j.[product_id] AS INT),
            CAST(j.[quantity]   AS INT)
        FROM OPENJSON(@items)
        WITH (
            product_id  INT '$.product_id',
            quantity    INT '$.quantity'
        ) AS j;

        -- Validate stock for all items up front (avoids partial failures)
        IF EXISTS (
            SELECT 1
            FROM @parsed p
            JOIN products pr ON pr.product_id = p.product_id
            WHERE pr.stock_qty < p.quantity OR pr.is_active = 0
        )
        BEGIN
            RAISERROR('One or more products are out of stock or inactive.', 16, 1);
        END;

        -- Create the order header
        INSERT INTO orders (customer_id, shipping_addr, status)
        VALUES (@customer_id, @shipping_addr, 'pending');

        SET @new_order_id = SCOPE_IDENTITY();

        -- Insert line items and decrement stock
        INSERT INTO order_items (order_id, product_id, quantity, unit_price, line_total)
        SELECT
            @new_order_id,
            p.product_id,
            p.quantity,
            pr.unit_price,
            p.quantity * pr.unit_price
        FROM @parsed p
        JOIN products pr ON pr.product_id = p.product_id;

        -- Decrement stock
        UPDATE pr
        SET pr.stock_qty = pr.stock_qty - p.quantity
        FROM products pr
        JOIN @parsed p ON pr.product_id = p.product_id;

        -- Recalculate order totals (8% tax)
        UPDATE orders
        SET
            subtotal     = (SELECT SUM(line_total) FROM order_items WHERE order_id = @new_order_id),
            tax_amount   = (SELECT SUM(line_total) * 0.08 FROM order_items WHERE order_id = @new_order_id),
            total_amount = (SELECT SUM(line_total) * 1.08 FROM order_items WHERE order_id = @new_order_id),
            updated_at   = GETDATE()
        WHERE order_id = @new_order_id;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;  -- Re-raise to the caller
    END CATCH;
END;
GO
