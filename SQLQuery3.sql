USE AdventureWorks;

--InsertOrderDetails Procedure

GO

IF OBJECT_ID('Sales.SalesOrderDetail', 'U') IS NULL      --checks whether SalesOrderDetails table is already in schema or not (U :userdefined)
BEGIN
    PRINT 'The table SalesOrderDetails does not exist. Please create respective table first.';
    RETURN;
END;
GO

IF OBJECT_ID('dbo.InsertOrderDetails', 'P') IS NOT NULL
DROP PROCEDURE dbo.InsertOrderDetails;
GO

CREATE PROCEDURE dbo.InsertOrderDetails
    @OrderID INT,
    @ProductID INT,
    @UnitPrice DECIMAL(19, 4) = NULL,   --default NULL 
    @Quantity INT,
    @Discount DECIMAL(4, 2) = 0      --default 0
AS
BEGIN
    SET NOCOUNT ON; --controls sending of DONE_IN_PROC message to client for each statement in stored procedure
	--setting NOCOUNT to ON means that SQL server wont send count of affected rows after each operation

    DECLARE @ProductUnitPrice DECIMAL(19, 4);
    --DECLARE @ProductDiscount DECIMAL(4, 2) = 0;
    DECLARE @UnitsInStock INT;
    DECLARE @ReorderLevel INT;

    -- Get the unit price from the product table if not provided
    IF @UnitPrice IS NULL
    BEGIN
        SELECT @ProductUnitPrice = ListPrice
        FROM Production.Product
        WHERE ProductID = @ProductID;
        
        IF @ProductUnitPrice IS NULL
        BEGIN
            PRINT 'Product not found. Failed to place the order. Please try again.';
            RETURN;
        END
    END
    ELSE
    BEGIN
        SET @ProductUnitPrice = @UnitPrice;
    END

    -- Get the current stock and reorder level of the product
    SELECT @UnitsInStock = Quantity, @ReorderLevel = @ReorderLevel
    FROM Production.ProductInventory
    WHERE ProductID = @ProductID;

    -- Check if there is enough stock
    IF @UnitsInStock IS NULL OR @UnitsInStock < @Quantity
    BEGIN
        PRINT 'Not enough product in stock. Failed to place the order. Please try again.';
        RETURN;
    END

    -- Insert the order details
    BEGIN TRANSACTION;
    BEGIN TRY
        INSERT INTO Sales.SalesOrderDetail (SalesOrderID, ProductID, UnitPrice, OrderQty, UnitPriceDiscount)
        VALUES (@OrderID, @ProductID, @ProductUnitPrice, @Quantity, @Discount);

        -- Check if the order was inserted
        IF @@ROWCOUNT = 0
        BEGIN
            PRINT 'Failed to place the order. Please try again.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Update the inventory
        UPDATE Production.ProductInventory
        SET @UnitsInStock = @UnitsInStock - @Quantity
        WHERE ProductID = @ProductID;

        -- Check if the stock level dropped below the reorder level
        IF (@UnitsInStock - @Quantity) < @ReorderLevel
        BEGIN
            PRINT 'Quantity in stock of the product has dropped below its reorder level.';
        END

        COMMIT TRANSACTION;
        PRINT 'Order details have been successfully inserted.';
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        PRINT 'Failed to place the order. Please try again.';
    END CATCH
END;
GO


--executed for ProductID=2, OrderID = 1
EXEC dbo.InsertOrderDetails @OrderID = 1, @ProductID = 2, @UnitPrice = 19.99, @Quantity =200;



 --UpdateOrderDetails procedure

GO

-- Drop the procedure if it already exists
IF OBJECT_ID('dbo.UpdateDetails', 'P') IS NOT NULL
DROP PROCEDURE dbo.UpdateDetails;
GO

-- Create the UpdateDetails stored procedure
CREATE PROCEDURE dbo.UpdateDetails
    @OrderID INT,
    @ProductID INT,
    @UnitPrice DECIMAL(19, 4) = NULL,
    @Quantity INT = NULL,
    @Discount DECIMAL(4, 2) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CurrentUnitPrice DECIMAL(19, 4);
    DECLARE @CurrentQuantity INT;
    DECLARE @CurrentDiscount DECIMAL(4, 2);

    -- Retrieve the current values
    SELECT 
        @CurrentUnitPrice = UnitPrice,
        @CurrentQuantity = OrderQty,
        @CurrentDiscount = UnitPriceDiscount
    FROM Sales.SalesOrderDetail
    WHERE SalesOrderID = @OrderID AND ProductID = @ProductID;

    -- Check if the order detail exists
    IF @CurrentUnitPrice IS NULL
    BEGIN
        PRINT 'Order detail not found. Please check OrderID and ProductID.';
        RETURN;
    END

    -- Update the order details with provided values or retain the original if NULL
    UPDATE Sales.SalesOrderDetail
    SET 
        UnitPrice = ISNULL(@UnitPrice, @CurrentUnitPrice),
        OrderQty = ISNULL(@Quantity, @CurrentQuantity),
        UnitPriceDiscount = ISNULL(@Discount, @CurrentDiscount)
    WHERE SalesOrderID = @OrderID AND ProductID = @ProductID;

    -- Check if the update was successful
    IF @@ROWCOUNT = 0
    BEGIN
        PRINT 'Failed to update the order details. Please try again.';
        RETURN;
    END

    PRINT 'Order details have been successfully updated.';
END;
GO


DECLARE @OrderID INT = 43659;  -- Replace with a valid SalesOrderID
DECLARE @ProductID INT = 776;  -- Replace with a valid ProductID
DECLARE @UnitPrice DECIMAL(19, 4) = 25.00;  -- New unit price (or NULL to retain old value)
DECLARE @Quantity INT = 5;  -- New quantity (or NULL to retain old value)
DECLARE @Discount DECIMAL(4, 2) = 0.10;  -- New discount (or NULL to retain old value)

EXEC dbo.UpdateDetails @OrderID, @ProductID, @UnitPrice, @Quantity, @Discount;

select * from Sales.SalesOrderDetail

--GetOrderDetails procedure

GO

-- Drop the procedure if it already exists
IF OBJECT_ID('dbo.GetOrderDetails', 'P') IS NOT NULL
DROP PROCEDURE dbo.GetOrderDetails;
GO

-- Create the GetOrderDetails stored procedure
CREATE PROCEDURE dbo.GetOrderDetails
    @OrderID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Check if any records exist for the given OrderID
    IF NOT EXISTS (SELECT 1 FROM Sales.SalesOrderDetail WHERE SalesOrderID = @OrderID)
    BEGIN
        PRINT 'The OrderID ' + CAST(@OrderID AS VARCHAR(10)) + ' does not exist.';
        RETURN 1;
    END

    -- Return all records for the given OrderID
    SELECT SalesOrderID, ProductID, UnitPrice, OrderQty, UnitPriceDiscount, ModifiedDate
    FROM Sales.SalesOrderDetail
    WHERE SalesOrderID = @OrderID;

    RETURN 0;
END;
GO


DECLARE @OrderID INT = 43659;  -- Replace with a valid SalesOrderID

EXEC dbo.GetOrderDetails @OrderID;


--deleteOrderDetails procedure
GO

-- Drop the procedure if it already exists
IF OBJECT_ID('dbo.DeleteOrderDetails', 'P') IS NOT NULL
DROP PROCEDURE dbo.DeleteOrderDetails;
GO

-- Create the DeleteOrderDetails stored procedure
CREATE PROCEDURE dbo.DeleteOrderDetails
    @OrderID INT,
    @ProductID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Check if the order ID exists
    IF NOT EXISTS (SELECT 1 FROM Sales.SalesOrderDetail WHERE SalesOrderID = @OrderID)
    BEGIN
        PRINT 'Invalid OrderID: ' + CAST(@OrderID AS VARCHAR(10));
        RETURN -1;
    END

    -- Check if the product ID exists for the given order ID
    IF NOT EXISTS (SELECT 1 FROM Sales.SalesOrderDetail WHERE SalesOrderID = @OrderID AND ProductID = @ProductID)
    BEGIN
        PRINT 'Invalid ProductID: ' + CAST(@ProductID AS VARCHAR(10)) + ' for OrderID: ' + CAST(@OrderID AS VARCHAR(10));
        RETURN -1;
    END

    -- Delete the record from the Order Details table
    DELETE FROM Sales.SalesOrderDetail
    WHERE SalesOrderID = @OrderID AND ProductID = @ProductID;

    -- Check if the delete operation was successful
    IF @@ROWCOUNT = 0
    BEGIN
        PRINT 'Failed to delete the order detail. Please try again.';
        RETURN -1;
    END

    PRINT 'Order detail has been successfully deleted.';
    RETURN 0;
END;
GO


DECLARE @OrderID INT = 43659; 
DECLARE @ProductID INT = 776;  

EXEC dbo.DeleteOrderDetails @OrderID, @ProductID;

SELECT * FROM Sales.SalesOrderDetail




--functions
--format of date:MM/DD/YYYY

GO

-- Drop the function if it already exists
IF OBJECT_ID('dbo.FormatDate', 'FN') IS NOT NULL
DROP FUNCTION dbo.FormatDate;
GO

-- Create the FormatDate function
CREATE FUNCTION dbo.FormatDate (@InputDate DATETIME)
RETURNS VARCHAR(10)
AS
BEGIN
    -- Return the date in MM/DD/YYYY format
    RETURN FORMAT(@InputDate, 'MM/dd/yyyy');
END;
GO

--input
DECLARE @TestDate DATETIME = GETDATE();

SELECT dbo.FormatDate(@TestDate) AS FormattedDate;


--function for format of YYYYMMDD
GO

-- Drop the function if it already exists
IF OBJECT_ID('dbo.FormatDateYYYYMMDD', 'FN') IS NOT NULL
DROP FUNCTION dbo.FormatDateYYYYMMDD;
GO

-- Create the FormatDateYYYYMMDD function
CREATE FUNCTION dbo.FormatDateYYYYMMDD (@InputDate DATETIME)
RETURNS VARCHAR(8)
AS
BEGIN
    -- Return the date in YYYYMMDD format
    RETURN CONVERT(VARCHAR(8), @InputDate, 112);
END;
GO

--input
-- Example: Use the FormatDateYYYYMMDD function
DECLARE @TestDate DATETIME = GETDATE();

SELECT dbo.FormatDateYYYYMMDD(@TestDate) AS FormattedDate;



--view for customerOrderes
USE AdventureWorks;
GO

-- Drop the view if it already exists
IF OBJECT_ID('dbo.vwCustomerOrders', 'V') IS NOT NULL
DROP VIEW dbo.vwCustomerOrders;
GO

-- Create the vwCustomerOrders view
CREATE VIEW dbo.vwCustomerOrders
AS
SELECT 
   -- c.Title,
    o.SalesOrderID,
    o.OrderDate,
    od.ProductID,
    p.Name,
    od.OrderQty,
    od.UnitPrice,
    (od.OrderQty * od.UnitPrice) AS TotalPrice
FROM 
    Sales.Customer c
JOIN 
    Sales.SalesOrderHeader o ON c.CustomerID = o.SalesOrderID
JOIN 
    Sales.SalesOrderDetail od ON o.SalesOrderID = od.SalesOrderID
JOIN 
    Production.Product p ON od.ProductID = p.ProductID;
GO

USE AdventureWorks;
GO

-- Drop the view if it already exists
IF OBJECT_ID('dbo.vwCustomerOrders_Yesterday', 'V') IS NOT NULL
DROP VIEW dbo.vwCustomerOrders_Yesterday;
GO

-- Create the vwCustomerOrders_Yesterday view

CREATE VIEW dbo.vwCustomerOrders_Yesterday
AS
SELECT 
    --c.CompanyName,
    o.SalesOrderID,
    o.OrderDate,
    od.ProductID,
    p.Name,
    od.OrderQty,
    od.UnitPrice,
    (od.OrderQty * od.UnitPrice) AS TotalPrice
FROM 
    Sales.Customer c
JOIN 
    Sales.SalesOrderHeader o ON c.CustomerID = o.CustomerID
JOIN 
    Sales.SalesOrderDetail od ON o.SalesOrderID = od.SalesOrderID
JOIN 
     Production.Product p ON od.ProductID = p.ProductID;
WHERE 
    o.OrderDate = CAST(GETDATE() - 1 AS DATE);
GO

--USE AdventureWorks;
GO

-- Drop the view if it already exists
--IF OBJECT_ID('dbo.MyProducts', 'V') IS NOT NULL
--DROP VIEW dbo.MyProducts;
--GO

-- Create the MyProducts view
--CREATE VIEW dbo.MyProducts
--AS
--SELECT 
--    o.SalesOrderID,
--    o.OrderDate,
--    od.ProductID,
--    p.Name,
--    od.OrderQty,
--    od.UnitPrice,
--    (od.OrderQty * od.UnitPrice) AS TotalPrice
--FROM 
--    Production.Product p
--JOIN 
--    Suppliers s ON p.SupplierID = s.SupplierID
--JOIN 
--    Categories c ON p.CategoryID = c.CategoryID
--WHERE 
--    p.Discontinued = 0;
--GO




--Trigger
--delete trigger

GO

-- Drop the trigger if it already exists
IF OBJECT_ID('dbo.trgDeleteOrder', 'TR') IS NOT NULL
DROP TRIGGER dbo.trgDeleteOrder;
GO

-- Create the DELETE trigger on Orders table
CREATE TRIGGER Sales.trgDeleteOrder
ON Sales.SalesOrderdetail
FOR DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- Delete corresponding entries in the Order Details table
    DELETE od
    FROM Sales.SalesOrderDetail od
    INNER JOIN deleted d ON od.SalesOrderID = d.SalesOrderID;

END;
GO

--insert trigger on order details table
GO

-- Drop the trigger if it already exists
IF OBJECT_ID('dbo.trgInsertOrderDetails', 'TR') IS NOT NULL
DROP TRIGGER dbo.trgInsertOrderDetails;
GO

-- Create the INSERT trigger on Order Details table
CREATE TRIGGER Sales.trgInsertOrderDetails
ON Sales.SalesOrderDetail
FOR INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ProductID INT;
    DECLARE @OrderQty INT;
    DECLARE @UnitsInStock INT;

    -- Get the ProductID and Quantity of the inserted order
    SELECT @ProductID = i.ProductID, @OrderQty = i.Quantity
    FROM inserted i;

    -- Get the UnitsInStock for the product
    SELECT @UnitsInStock = p.UnitsInStock
    FROM Production.Product p
    WHERE p.ProductID = @ProductID;

    -- Check if there is sufficient stock
    IF @UnitsInStock < @OrderQty
    BEGIN
        -- Rollback the transaction and raise an error
        ROLLBACK;
        RAISERROR ('Order could not be filled because of insufficient stock.', 16, 1);
    END
    ELSE
    BEGIN
        -- Decrement the stock
        UPDATE Production.Product
        SET UnitsInStock = UnitsInStock - @OrderQty
        WHERE ProductID = @ProductID;
    END;
END;
GO

