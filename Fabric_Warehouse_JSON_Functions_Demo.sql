/*
====================================================================================
File        : Fabric_Warehouse_JSON_Functions_Demo.sql
Purpose     : Section 1 — What you can do with JSON in Microsoft Fabric Warehouse
Dataset     : Based on JSON_SAMPLE_DATASET.csv (10 JSON documents; 1 per row)

Official reference (function list + applicability includes Fabric Warehouse):
- https://learn.microsoft.com/en-us/sql/t-sql/functions/json-functions-transact-sql?view=sql-server-ver17

How to use
1) Run this script in a Microsoft Fabric Warehouse (T-SQL endpoint).
2) It creates dbo.JsonDemo and loads 10 sample JSON rows.
3) Each section demonstrates one JSON function with a runnable example.

Notes
- JSON is stored as VARCHAR(MAX) (text) in this demo for simplicity/portability.
- JSON_ARRAYAGG / JSON_OBJECTAGG availability can vary by tenant/rollout.
  If they fail in your environment, keep the fallback examples provided.
====================================================================================
*/

/*===================================================================================
0) Setup: Create table + load sample JSON
===================================================================================*/
-- Purpose: Create a simple table that stores JSON as text.
-- Why: This mirrors how many ingestion pipelines land semi-structured payloads into a warehouse.

DROP TABLE IF EXISTS dbo.JsonDemo;
GO

CREATE TABLE dbo.JsonDemo
(
    RowId         INT          NOT NULL,
    RecordDetails VARCHAR(MAX) NOT NULL
);
GO

-- Load the 10 JSON rows (from JSON_SAMPLE_DATASET.csv)
TRUNCATE TABLE dbo.JsonDemo;

INSERT INTO dbo.JsonDemo (RowId, RecordDetails)
VALUES
(1,  '{"custId": 124, "name": "Rakesh_1", "address": {"city": "Bengaluru", "zip": "560001"}, "tags": ["vip", "newsletter", "Rakesh", "Sharma", "tag1"], "orders": [{"id": 1, "amount": 101.5}, {"id": 2, "amount": 202.0}]}'),
(2,  '{"custId": 125, "name": "Rakesh_2", "address": {"city": "Bengaluru", "zip": "560002"}, "tags": ["vip", "newsletter", "Rakesh", "Sharma", "tag2"], "orders": [{"id": 1, "amount": 102.5}, {"id": 2, "amount": 204.0}]}'),
(3,  '{"custId": 126, "name": "Rakesh_3", "address": {"city": "Bengaluru", "zip": "560003"}, "tags": ["vip", "newsletter", "Rakesh", "Sharma", "tag3"], "orders": [{"id": 1, "amount": 103.5}, {"id": 2, "amount": 206.0}]}'),
(4,  '{"custId": 127, "name": "Rakesh_4", "address": {"city": "Bengaluru", "zip": "560004"}, "tags": ["vip", "newsletter", "Rakesh", "Sharma", "tag4"], "orders": [{"id": 1, "amount": 104.5}, {"id": 2, "amount": 208.0}]}'),
(5,  '{"custId": 128, "name": "Rakesh_5", "address": {"city": "Bengaluru", "zip": "560005"}, "tags": ["vip", "newsletter", "Rakesh", "Sharma", "tag5"], "orders": [{"id": 1, "amount": 105.5}, {"id": 2, "amount": 210.0}]}'),
(6,  '{"custId": 129, "name": "Rakesh_6", "address": {"city": "Bengaluru", "zip": "560006"}, "tags": ["vip", "newsletter", "Rakesh", "Sharma", "tag6"], "orders": [{"id": 1, "amount": 106.5}, {"id": 2, "amount": 212.0}]}'),
(7,  '{"custId": 130, "name": "Rakesh_7", "address": {"city": "Bengaluru", "zip": "560007"}, "tags": ["vip", "newsletter", "Rakesh", "Sharma", "tag7"], "orders": [{"id": 1, "amount": 107.5}, {"id": 2, "amount": 214.0}]}'),
(8,  '{"custId": 131, "name": "Rakesh_8", "address": {"city": "Bengaluru", "zip": "560008"}, "tags": ["vip", "newsletter", "Rakesh", "Sharma", "tag8"], "orders": [{"id": 1, "amount": 108.5}, {"id": 2, "amount": 216.0}]}'),
(9,  '{"custId": 132, "name": "Rakesh_9", "address": {"city": "Bengaluru", "zip": "560009"}, "tags": ["vip", "newsletter", "Rakesh", "Sharma", "tag9"], "orders": [{"id": 1, "amount": 109.5}, {"id": 2, "amount": 218.0}]}'),
(10, '{"custId": 133, "name": "Rakesh_10", "address": {"city": "Bengaluru", "zip": "560010"}, "tags": ["vip", "newsletter", "Rakesh", "Sharma", "tag10"], "orders": [{"id": 1, "amount": 110.5}, {"id": 2, "amount": 220.0}]}');
GO

/*===================================================================================
1) ISJSON — Validate JSON - Tested OK
===================================================================================*/
-- What: Tests whether a string contains valid JSON.
-- Why: Use this as a guardrail before extracting values or shredding arrays.

SELECT
   RowId, RecordDetails as 'RecordDetailsCompleteJSON',
    ISJSON(RecordDetails) AS IsValidJson
FROM dbo.JsonDemo;
GO

/*===================================================================================
2) JSON_VALUE — Extract scalar values - Tested OK
===================================================================================*/
-- What: Extracts a single scalar (string/number/boolean) from a JSON document.
-- Why: Use it for IDs, names, and nested scalar properties you want as columns.

SELECT
     RowId, RecordDetails as 'RecordDetailsCompleteJSON',
    TRY_CAST(JSON_VALUE(RecordDetails, '$.custId') AS INT) AS custId,
    JSON_VALUE(RecordDetails, '$.name')                   AS custName,
    JSON_VALUE(RecordDetails, '$.address.city')           AS city,
    JSON_VALUE(RecordDetails, '$.address.zip')            AS zip
FROM dbo.JsonDemo;
GO

/*===================================================================================
3) JSON_QUERY — Extract objects/arrays - Tested OK
===================================================================================*/
-- What: Extracts a JSON object or array (returns JSON text).
-- Why: Use it when the path points to nested objects/arrays (tags/orders/address).

SELECT 
    RowId, RecordDetails as 'RecordDetailsCompleteJSON',
    JSON_QUERY(RecordDetails, '$.address') AS address_json,
    JSON_QUERY(RecordDetails, '$.tags')    AS tags_json,
    JSON_QUERY(RecordDetails, '$.orders')  AS orders_json
FROM dbo.JsonDemo;
GO

/*===================================================================================
4) JSON_PATH_EXISTS — Check if a path exists - Tested OK
===================================================================================*/
-- What: Tests whether a specified SQL/JSON path exists in the input JSON string.
-- Why: Great for schema drift (optional fields) without breaking downstream logic.

SELECT
     RowId, RecordDetails as 'RecordDetailsCompleteJSON',
    JSON_PATH_EXISTS(RecordDetails, '$.address.city')  AS HasCity,
    JSON_PATH_EXISTS(RecordDetails, '$.address.state') AS HasState
FROM dbo.JsonDemo;
GO

/*===================================================================================
5) JSON_MODIFY — Update a JSON property
===================================================================================*/
-- What: Updates a property value in a JSON string and returns updated JSON.
-- Why: Useful for patching, normalizing, or enriching JSON payloads.

DECLARE @j VARCHAR(MAX);
DECLARE @updated_json VARCHAR(MAX);

SELECT @j = RecordDetails
FROM dbo.JsonDemo
WHERE RowId = 1;

SET @updated_json = JSON_MODIFY(@j, '$.address.zip', '999999');

SELECT
    @j AS original_json,
    @updated_json AS updated_json,
    ISJSON(@updated_json) AS is_valid_json;



/*===================================================================================
6) OPENJSON — Expand an array to rows (tags)
===================================================================================*/
-- What: Parses JSON and returns objects/properties as rows and columns.
-- Why: This is the core pattern to turn JSON arrays into a relational rowset.

SELECT RowId, RecordDetails as 'RecordDetailsCompleteJSON',
    TRY_CAST(JSON_VALUE(d.RecordDetails, '$.custId') AS INT) AS custId,
    t.[value] AS tag
FROM dbo.JsonDemo d
CROSS APPLY OPENJSON(JSON_QUERY(d.RecordDetails, '$.tags')) AS t;
GO

/*===================================================================================
7) OPENJSON ... WITH — Expand array of objects (orders) into typed columns
===================================================================================*/
-- What: WITH clause projects JSON properties into typed columns.
-- Why: Ideal for arrays of objects such as order line items, events, attributes.

SELECT RowId, RecordDetails as 'RecordDetailsCompleteJSON',
    TRY_CAST(JSON_VALUE(d.RecordDetails, '$.custId') AS INT) AS custId,
    o.orderId,
    o.amount
FROM dbo.JsonDemo d
CROSS APPLY OPENJSON(JSON_QUERY(d.RecordDetails, '$.orders'))
WITH
(
    orderId INT           '$.id',
    amount  DECIMAL(10,2) '$.amount'
) AS o;
GO

/*===================================================================================
8) JSON_OBJECT — Construct JSON objects safely
===================================================================================*/
-- What: Constructs JSON object text from key-value pairs.
-- Why: Safer than manual CONCAT because it handles quoting/escaping correctly.

SELECT
    RowId,RecordDetails as 'RecordDetailsCompleteJSON',
    JSON_OBJECT(
        'custId': TRY_CAST(JSON_VALUE(RecordDetails, '$.custId') AS INT),
        'name'  : JSON_VALUE(RecordDetails, '$.name'),
        'city'  : JSON_VALUE(RecordDetails, '$.address.city'),
        'zip'   : JSON_VALUE(RecordDetails, '$.address.zip')
    ) AS customer_json
FROM dbo.JsonDemo;
GO

/*===================================================================================
9) JSON_ARRAY — Construct JSON arrays safely
===================================================================================*/
-- What: Constructs JSON array text from zero or more expressions.
-- Why: Useful for returning arrays to apps/APIs or for packaging values into JSON.

SELECT 
    JSON_ARRAY('vip', 'newsletter', 'tagX') AS sample_tags_array;
GO

/*===================================================================================
10) JSON_ARRAYAGG — Aggregate rows into a JSON array (tags per customer)
===================================================================================*/
-- What: Constructs a JSON array from an aggregation of SQL rows/values.
-- Why: Useful to re-package relational rows back into JSON arrays.
-- Note: If this is not enabled in your environment, use the STRING_AGG fallback below.

BEGIN TRY
    SELECT
        TRY_CAST(JSON_VALUE(d.RecordDetails, '$.custId') AS INT) AS custId,
        JSON_ARRAYAGG(t.[value] ORDER BY t.[value]) AS tags_json_array
    FROM dbo.JsonDemo d
    CROSS APPLY OPENJSON(JSON_QUERY(d.RecordDetails, '$.tags')) t
    GROUP BY TRY_CAST(JSON_VALUE(d.RecordDetails, '$.custId') AS INT);
END TRY
BEGIN CATCH
    SELECT
        'JSON_ARRAYAGG not available in this environment. Using STRING_AGG fallback.' AS Note,
        TRY_CAST(JSON_VALUE(d.RecordDetails, '$.custId') AS INT) AS custId,
        STRING_AGG(t.[value], ',') WITHIN GROUP (ORDER BY t.[value]) AS tags_csv
    FROM dbo.JsonDemo d
    CROSS APPLY OPENJSON(JSON_QUERY(d.RecordDetails, '$.tags')) t
    GROUP BY TRY_CAST(JSON_VALUE(d.RecordDetails, '$.custId') AS INT);
END CATCH;
GO

/*===================================================================================
11) JSON_OBJECTAGG — Aggregate key:value pairs into a JSON object (orderId -> amount)
===================================================================================*/
-- What: Constructs a JSON object from an aggregation of key/value pairs.
-- Why: Great for generating lookup-like JSON objects or pivoting child rows into JSON.
-- Note: If this is not enabled, use the manual STRING_AGG fallback below.

BEGIN TRY
    SELECT
        TRY_CAST(JSON_VALUE(d.RecordDetails, '$.custId') AS INT) AS custId,
        JSON_OBJECTAGG(CAST(o.orderId AS VARCHAR(20)) : o.amount) AS orders_amount_map
    FROM dbo.JsonDemo d
    CROSS APPLY OPENJSON(JSON_QUERY(d.RecordDetails, '$.orders'))
    WITH (orderId INT '$.id', amount DECIMAL(10,2) '$.amount') o
    GROUP BY TRY_CAST(JSON_VALUE(d.RecordDetails, '$.custId') AS INT);
END TRY
BEGIN CATCH
    -- Fallback: build a JSON object manually using STRING_AGG (works for simple maps)
    ;WITH kv AS
    (
        SELECT
            TRY_CAST(JSON_VALUE(d.RecordDetails, '$.custId') AS INT) AS custId,
            CAST(o.orderId AS VARCHAR(20)) AS k,
            CAST(o.amount AS VARCHAR(50))  AS v
        FROM dbo.JsonDemo d
        CROSS APPLY OPENJSON(JSON_QUERY(d.RecordDetails, '$.orders'))
        WITH (orderId INT '$.id', amount DECIMAL(10,2) '$.amount') o
    )
    SELECT
        'JSON_OBJECTAGG not available in this environment. Using STRING_AGG fallback.' AS Note,
        custId,
        '{' + STRING_AGG('"' + k + '":' + v, ',') WITHIN GROUP (ORDER BY k) + '}' AS orders_amount_map_json
    FROM kv
    GROUP BY custId;
END CATCH;
GO

/*===================================================================================
