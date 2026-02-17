/*======================================================================================================================
 Handling  JSON → Medallion (Bronze → Silver → Gold) in Fabric Warehouse 
 Author:  Rakesh Sharma
 
 OBJECTIVE
 ---------
 1) Bronze: Store raw JSON 
 2) Silver: Validate + Normalize + Cleanup + Traceability.
 3) Gold:  Clean, analytics-ready relational tables (fully flattened):
        - Customer_Gold           (1 row per customer)
        - Order_Gold              (1 row per order)
        - OrderItem_Gold          (1 row per item)
     Nested JSON Support (additional Gold tables):
        - CustomerAddress_Gold    (Nested Address + Geo)
        - OrderShipping_Gold      (Nested Shipping Object)
        - OrderCoupon_Gold        (Nested Coupons array)
        - OrderMeta_Gold          (Nested Meta Map/dictionary object -> key/value rows)
        - OrderItemAttr_Gold      (Nested item attrs object)
 =====================================================================================================================*/

------------------------------------------------------------------------------------------------------------------------
-- 0) CLEAN START — Recreate Bronze/Silver/Quarantine
------------------------------------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS dbo.Json_Bronze;
GO
CREATE TABLE dbo.Json_Bronze
(
    RowId         BIGINT,
    SourceSystem  VARCHAR(100),
    SourceFile    VARCHAR(500),
    IngestedAt    DATETIME2(6),
    RecordDetails VARCHAR(MAX)          -- Raw JSON text
);
GO

DROP TABLE IF EXISTS dbo.Json_Silver;
GO
CREATE TABLE dbo.Json_Silver
(
    RowId           BIGINT,
    SourceSystem    VARCHAR(100),
    SourceFile      VARCHAR(500),
    IngestedAt      DATETIME2(6),

    custId          INT,
    custName        VARCHAR(200),
    city            VARCHAR(100),
    zip             VARCHAR(20),
    geo_lat         FLOAT,
    geo_lon         FLOAT,

    
    RecordDetails   VARCHAR(MAX),

    
    IsValidJson     BIT,
    ValidationNote  VARCHAR(200)
);
GO

DROP TABLE IF EXISTS dbo.Json_Quarantine;
GO
CREATE TABLE dbo.Json_Quarantine
(
    RowId          BIGINT,
    SourceFile     VARCHAR(500),
    IngestedAt     DATETIME2(6),
    RecordDetails  VARCHAR(MAX),
    ValidationNote VARCHAR(200)
);
GO


------------------------------------------------------------------------------------------------------------------------
-- 1) LOAD BRONZE — Sample dataset (12 rows) including nested JSON structures + a few invalid JSON rows
------------------------------------------------------------------------------------------------------------------------

TRUNCATE TABLE dbo.Json_Bronze;

INSERT INTO dbo.Json_Bronze (RowId, SourceSystem, SourceFile, IngestedAt, RecordDetails)
VALUES
-- 1) Valid: nested address.geo, nested shipping object, coupons array, meta map, item attrs object
(1, 'CRM', 'crm_2026_02_16_nested.json', SYSDATETIME(),
'{
  "custId":123,
  "name":"Rakesh",
  "address":{"city":"Bengaluru","zip":"560001","geo":{"lat":12.9716,"lon":77.5946}},
  "tags":["vip","newsletter"],
  "orders":[
    {
      "orderId":9001,
      "amount":2500.5,
      "shipping":{"method":"EXPRESS","eta":"2026-02-20"},
      "coupons":["FEB10","WELCOME"],
      "meta":{"channel":"web","campaign":"FEB-2026"},
      "items":[
        {"sku":"A1","qty":2,"attrs":{"color":"red","size":"M"}},
        {"sku":"B9","qty":1,"attrs":{"color":"blue","size":"L"}}
      ]
    },
    {
      "orderId":9002,
      "amount":999.0,
      "shipping":{"method":"STANDARD","eta":"2026-02-25"},
      "coupons":[],
      "meta":{"channel":"store"},
      "items":[{"sku":"C3","qty":5,"attrs":{"color":"black","size":"S"}}]
    }
  ]
}'),

-- 2) Invalid JSON (bad syntax)
(2, 'CRM', 'crm_bad.json', SYSDATETIME(),
'{bad-json: true'),

-- 3) Valid: simple nested address + one order
(3, 'CRM', 'crm_2026_02_16.json', SYSDATETIME(),
'{"custId":124,"name":"Ananya","address":{"city":"Mumbai","zip":"400001","geo":{"lat":19.0760,"lon":72.8777}},"tags":["new"],"orders":[{"orderId":9003,"amount":120.75,"shipping":{"method":"STANDARD","eta":"2026-02-21"},"coupons":["NEW5"],"meta":{"channel":"app"},"items":[{"sku":"D4","qty":1,"attrs":{"color":"green","size":"M"}}]}]}'),

-- 4) Valid: multiple item attrs, no coupons key (schema drift)
(4, 'CRM', 'crm_2026_02_16.json', SYSDATETIME(),
'{"custId":125,"name":"Vikram","address":{"city":"Delhi","zip":"110001"},"tags":["vip"],"orders":[{"orderId":9004,"amount":5400.0,"shipping":{"method":"EXPRESS","eta":"2026-02-19"},"meta":{"channel":"web","campaign":"VIP"},"items":[{"sku":"X1","qty":1,"attrs":{"color":"white","size":"XL"}},{"sku":"X2","qty":2,"attrs":{"color":"white","size":"L"}},{"sku":"X3","qty":3,"attrs":{"color":"gray","size":"M"}}]}]}'),

-- 5) Valid: orders empty array
(5, 'CRM', 'crm_2026_02_16.json', SYSDATETIME(),
'{"custId":126,"name":"Neha","address":{"city":"Pune","zip":"411001"},"tags":["newsletter"],"orders":[]}'),

-- 6) Valid: missing tags, one order, coupons empty
(6, 'CRM', 'crm_2026_02_16.json', SYSDATETIME(),
'{"custId":127,"name":"Suresh","address":{"city":"Chennai","zip":"600001"},"orders":[{"orderId":9005,"amount":0.0,"shipping":{"method":"STANDARD","eta":"2026-02-22"},"coupons":[],"meta":{"channel":"store"},"items":[{"sku":"FREE1","qty":1,"attrs":{"color":"na","size":"na"}}]}]}'),

-- 7) Valid: zip missing, geo missing, 2 orders, meta keys vary
(7, 'CRM', 'crm_2026_02_16.json', SYSDATETIME(),
'{"custId":128,"name":"Meera","address":{"city":"Hyderabad"},"tags":["loyalty","vip"],"orders":[{"orderId":9006,"amount":799.99,"shipping":{"method":"STANDARD","eta":"2026-02-23"},"coupons":["LOYAL20"],"meta":{"channel":"web"},"items":[{"sku":"M1","qty":2,"attrs":{"color":"pink","size":"S"}}]},{"orderId":9007,"amount":199.50,"shipping":{"method":"STANDARD","eta":"2026-02-23"},"meta":{"channel":"app","campaign":"FLASH"},"items":[{"sku":"M2","qty":1,"attrs":{"color":"yellow","size":"M"}},{"sku":"M3","qty":1,"attrs":{"color":"yellow","size":"M"}}]}]}'),

-- 8) Valid: items empty array
(8, 'CRM', 'crm_2026_02_16.json', SYSDATETIME(),
'{"custId":129,"name":"Arjun","address":{"city":"Kolkata","zip":"700001"},"tags":["new","promo"],"orders":[{"orderId":9008,"amount":350.0,"shipping":{"method":"STANDARD","eta":"2026-02-24"},"coupons":["PROMO"],"meta":{"channel":"web"},"items":[]}]}'),

-- 9) Valid: multi orders, multi coupons
(9, 'CRM', 'crm_2026_02_16.json', SYSDATETIME(),
'{"custId":130,"name":"Priya","address":{"city":"Ahmedabad","zip":"380001"},"tags":["newsletter","promo","vip"],"orders":[{"orderId":9009,"amount":1499.0,"shipping":{"method":"EXPRESS","eta":"2026-02-20"},"coupons":["FEB10"],"meta":{"channel":"web","campaign":"FEB-2026"},"items":[{"sku":"P1","qty":1,"attrs":{"color":"red","size":"M"}},{"sku":"P2","qty":4,"attrs":{"color":"red","size":"S"}}]},{"orderId":9010,"amount":250.0,"shipping":{"method":"STANDARD","eta":"2026-02-26"},"coupons":["WELCOME"],"meta":{"channel":"app"},"items":[{"sku":"P3","qty":2,"attrs":{"color":"black","size":"L"}}]}]}'),

-- 10) Invalid JSON (trailing comma)
(10, 'CRM', 'crm_bad_trailing_comma.json', SYSDATETIME(),
'{"custId":131,"name":"Kiran","address":{"city":"Jaipur","zip":"302001"},"tags":["vip"],"orders":[{"orderId":9011,"amount":600.0,"items":[{"sku":"K1","qty":1}]}],}'),

-- 11) Valid: custId is string (tests TRY_CAST)
(11, 'CRM', 'crm_2026_02_16.json', SYSDATETIME(),
'{"custId":"132","name":"Nitin","address":{"city":"Lucknow","zip":"226001","geo":{"lat":26.8467,"lon":80.9462}},"tags":["newsletter"],"orders":[{"orderId":9012,"amount":999.99,"shipping":{"method":"STANDARD","eta":"2026-02-25"},"coupons":["NEW5"],"meta":{"channel":"web"},"items":[{"sku":"N1","qty":1,"attrs":{"color":"blue","size":"M"}}]}]}'),

-- 12) Valid: orderId string (tests TRY_CAST), nested attrs present
(12, 'CRM', 'crm_2026_02_16.json', SYSDATETIME(),
'{"custId":133,"name":"Divya","address":{"city":"Bengaluru","zip":"560103","geo":{"lat":12.9352,"lon":77.6245}},"tags":["vip","loyalty"],"orders":[{"orderId":"9013","amount":3250.25,"shipping":{"method":"EXPRESS","eta":"2026-02-21"},"coupons":["LOYAL20"],"meta":{"channel":"app","campaign":"FEB-2026"},"items":[{"sku":"DV1","qty":1,"attrs":{"color":"purple","size":"M"}},{"sku":"DV2","qty":2,"attrs":{"color":"purple","size":"S"}}]}]}');
GO


------------------------------------------------------------------------------------------------------------------------
-- 2) BRONZE VALIDATION — sanity checks
------------------------------------------------------------------------------------------------------------------------

-- Count valid/invalid JSON rows

SELECT
    * 
FROM dbo.Json_Bronze;

SELECT
    COUNT(*) AS TotalRows,
    SUM(CASE WHEN ISJSON(RecordDetails) = 1 THEN 1 ELSE 0 END) AS ValidJsonRows,
    SUM(CASE WHEN ISJSON(RecordDetails) = 0 THEN 1 ELSE 0 END) AS InvalidJsonRows
FROM dbo.Json_Bronze;

-- Show invalid JSON rows
SELECT TOP 50
    RowId, SourceFile, RecordDetails
FROM dbo.Json_Bronze
WHERE ISJSON(RecordDetails) <> 1 OR RecordDetails IS NULL;

-- Optional: confirm key paths exist for valid JSON (helps catch schema drift)
SELECT
    RowId,
    JSON_PATH_EXISTS(RecordDetails, '$.custId')       AS HasCustId,
    JSON_PATH_EXISTS(RecordDetails, '$.name')         AS HasName,
    JSON_PATH_EXISTS(RecordDetails, '$.address.city') AS HasCity,
    JSON_PATH_EXISTS(RecordDetails, '$.orders')       AS HasOrders
FROM dbo.Json_Bronze
WHERE ISJSON(RecordDetails) = 1;
GO


/*======================================================================================================================
 3) BRONZE → SILVER — normalize + quality gating (SAFE for bad JSON)
    Key idea:
      - Insert valid JSON rows with parsed columns
      - Insert invalid JSON rows without calling JSON_VALUE/JSON_PATH_EXISTS (prevents runtime errors)
======================================================================================================================*/

TRUNCATE TABLE dbo.Json_Silver;

----------------------------------------------------------------------------------------------------
--## 1) Insert VALID JSON rows (only here we call JSON_VALUE / JSON_PATH_EXISTS)
----------------------------------------------------------------------------------------------------
INSERT INTO dbo.Json_Silver
(
    RowId, SourceSystem, SourceFile, IngestedAt,
    custId, custName, city, zip, geo_lat, geo_lon,
    RecordDetails, IsValidJson, ValidationNote
)
SELECT
    b.RowId, b.SourceSystem, b.SourceFile, b.IngestedAt,

    
    TRY_CAST(JSON_VALUE(b.RecordDetails, '$.custId') AS INT)  AS custId,
    JSON_VALUE(b.RecordDetails, '$.name')                     AS custName,
    JSON_VALUE(b.RecordDetails, '$.address.city')             AS city,
    JSON_VALUE(b.RecordDetails, '$.address.zip')              AS zip,
    TRY_CAST(JSON_VALUE(b.RecordDetails, '$.address.geo.lat') AS FLOAT) AS geo_lat,
    TRY_CAST(JSON_VALUE(b.RecordDetails, '$.address.geo.lon') AS FLOAT) AS geo_lon,

    b.RecordDetails,
    CAST(1 AS BIT) AS IsValidJson,

    CASE
        WHEN JSON_VALUE(b.RecordDetails, '$.custId') IS NULL THEN 'Missing custId'
        WHEN TRY_CAST(JSON_VALUE(b.RecordDetails, '$.custId') AS INT) IS NULL THEN 'custId not numeric'
        WHEN JSON_VALUE(b.RecordDetails, '$.name') IS NULL THEN 'Missing name'
        WHEN JSON_VALUE(b.RecordDetails, '$.address.city') IS NULL THEN 'Missing city'
        WHEN JSON_PATH_EXISTS(b.RecordDetails, '$.orders') = 0 THEN 'Missing orders'
        ELSE 'OK'
    END AS ValidationNote
FROM dbo.Json_Bronze b
WHERE ISJSON(b.RecordDetails) = 1;
GO

----------------------------------------------------------------------------------------------------
--## 2) Insert JSON into Silver with Validation Checks (NO JSON_VALUE calls here)
-- * SELECT * FROM Json_Silver
----------------------------------------------------------------------------------------------------
INSERT INTO dbo.Json_Silver
(
    RowId, SourceSystem, SourceFile, IngestedAt,
    custId, custName, city, zip, geo_lat, geo_lon,
    RecordDetails, IsValidJson, ValidationNote
)
SELECT
    b.RowId, b.SourceSystem, b.SourceFile, b.IngestedAt,

    -- Parsed columns set to NULL because JSON is invalid
    NULL AS custId,
    NULL AS custName,
    NULL AS city,
    NULL AS zip,
    NULL AS geo_lat,
    NULL AS geo_lon,

    b.RecordDetails,
    CAST(0 AS BIT) AS IsValidJson,
    'Invalid JSON' AS ValidationNote
FROM dbo.Json_Bronze b
WHERE ISJSON(b.RecordDetails) <> 1 OR b.RecordDetails IS NULL;
GO

----------------------------------------------------------------------------------------------------
--## 3) Quarantine rejected rows for troubleshooting (optional best practice)
--## SELECT * FROM dbo.Json_Quarantine;
----------------------------------------------------------------------------------------------------
TRUNCATE TABLE dbo.Json_Quarantine;

INSERT INTO dbo.Json_Quarantine (RowId, SourceFile, IngestedAt, RecordDetails, ValidationNote)
SELECT
    RowId, SourceFile, IngestedAt, RecordDetails, ValidationNote
FROM dbo.Json_Silver
WHERE IsValidJson = 0 OR ValidationNote <> 'OK';
GO

-- Quick summary
SELECT
    COUNT(*) AS SilverRows,
    SUM(CASE WHEN ValidationNote = 'OK' THEN 1 ELSE 0 END) AS OkRows,
    SUM(CASE WHEN ValidationNote <> 'OK' THEN 1 ELSE 0 END) AS RejectedRows
FROM dbo.Json_Silver;

SELECT TOP 50 * FROM dbo.Json_Quarantine ORDER BY RowId;
GO

------------------------------------------------------------------------------------------------------------------------
-- 4) CREATE GOLD TABLES — base + nested support tables

--# SELECT * FROM Customer_Gold
--# SELECT * FROM Order_Gold
--# SELECT * FROM OrderItem_Gold
------------------------------------------------------------------------------------------------------------------------

-- Base Gold tables
DROP TABLE IF EXISTS dbo.Customer_Gold;
DROP TABLE IF EXISTS dbo.Order_Gold;
DROP TABLE IF EXISTS dbo.OrderItem_Gold;
GO

CREATE TABLE dbo.Customer_Gold
(
    custId   INT,
    custName VARCHAR(200),
    city     VARCHAR(100)
);

CREATE TABLE dbo.Order_Gold
(
    custId  INT,
    orderId INT,
    amount  FLOAT
);

CREATE TABLE dbo.OrderItem_Gold
(
    custId  INT,
    orderId INT,
    sku     VARCHAR(50),
    qty     INT
);
GO

-- Nested-support Gold tables
DROP TABLE IF EXISTS dbo.CustomerAddress_Gold;
DROP TABLE IF EXISTS dbo.OrderShipping_Gold;
DROP TABLE IF EXISTS dbo.OrderCoupon_Gold;
DROP TABLE IF EXISTS dbo.OrderMeta_Gold;
DROP TABLE IF EXISTS dbo.OrderItemAttr_Gold;
GO

CREATE TABLE dbo.CustomerAddress_Gold
(
    custId  INT,
    city    VARCHAR(100),
    zip     VARCHAR(20),
    geo_lat FLOAT,
    geo_lon FLOAT
);

CREATE TABLE dbo.OrderShipping_Gold
(
    custId   INT,
    orderId  INT,
    method   VARCHAR(50),
    eta      VARCHAR(30)
);

CREATE TABLE dbo.OrderCoupon_Gold
(
    custId   INT,
    orderId  INT,
    coupon   VARCHAR(50)
);

CREATE TABLE dbo.OrderMeta_Gold
(
    custId   INT,
    orderId  INT,
    meta_key VARCHAR(100),
    meta_val VARCHAR(500)
);

CREATE TABLE dbo.OrderItemAttr_Gold
(
    custId   INT,
    orderId  INT,
    sku      VARCHAR(50),
    color    VARCHAR(50),
    size     VARCHAR(50)
);
GO


------------------------------------------------------------------------------------------------------------------------
-- 5) SILVER → GOLD — base loads (clean & flattened)
-- IMPORTANT: Nested arrays/objects are parsed using OPENJSON(parentValue,'$.path') with parentValue = o.[value]/i.[value]
------------------------------------------------------------------------------------------------------------------------

-- 5A) Customer_Gold
TRUNCATE TABLE dbo.Customer_Gold;

INSERT INTO dbo.Customer_Gold (custId, custName, city)
SELECT DISTINCT
    s.custId, s.custName, s.city
FROM dbo.Json_Silver s
WHERE s.IsValidJson = 1
  AND s.ValidationNote = 'OK'
  AND s.custId IS NOT NULL;
GO

-- 5B) Order_Gold (explode orders[])
TRUNCATE TABLE dbo.Order_Gold;

INSERT INTO dbo.Order_Gold (custId, orderId, amount)
SELECT
    s.custId,
    TRY_CAST(JSON_VALUE(o.[value], '$.orderId') AS INT)  AS orderId,
    TRY_CAST(JSON_VALUE(o.[value], '$.amount')  AS FLOAT) AS amount
FROM dbo.Json_Silver s
CROSS APPLY OPENJSON(s.RecordDetails, '$.orders') AS o
WHERE s.IsValidJson = 1
  AND s.ValidationNote = 'OK'
  AND s.custId IS NOT NULL
  AND JSON_VALUE(o.[value], '$.orderId') IS NOT NULL;
GO

-- 5C) OrderItem_Gold (explode orders[].items[])
TRUNCATE TABLE dbo.OrderItem_Gold;

INSERT INTO dbo.OrderItem_Gold (custId, orderId, sku, qty)
SELECT
    s.custId,
    TRY_CAST(JSON_VALUE(o.[value], '$.orderId') AS INT) AS orderId,
    JSON_VALUE(i.[value], '$.sku')                      AS sku,
    TRY_CAST(JSON_VALUE(i.[value], '$.qty') AS INT)     AS qty
FROM dbo.Json_Silver s
CROSS APPLY OPENJSON(s.RecordDetails, '$.orders') AS o
CROSS APPLY OPENJSON(o.[value], '$.items')        AS i
WHERE s.IsValidJson = 1
  AND s.ValidationNote = 'OK'
  AND s.custId IS NOT NULL
  AND JSON_VALUE(o.[value], '$.orderId') IS NOT NULL
  AND JSON_VALUE(i.[value], '$.sku') IS NOT NULL;
GO


------------------------------------------------------------------------------------------------------------------------
-- 6) SILVER → GOLD — nested loads
------------------------------------------------------------------------------------------------------------------------

-- 6A) CustomerAddress_Gold (nested address + geo)
TRUNCATE TABLE dbo.CustomerAddress_Gold;

INSERT INTO dbo.CustomerAddress_Gold (custId, city, zip, geo_lat, geo_lon)
SELECT DISTINCT
    s.custId, s.city, s.zip, s.geo_lat, s.geo_lon
FROM dbo.Json_Silver s
WHERE s.IsValidJson = 1
  AND s.ValidationNote = 'OK'
  AND s.custId IS NOT NULL;
GO

-- 6B) OrderShipping_Gold (nested shipping object)
TRUNCATE TABLE dbo.OrderShipping_Gold;

INSERT INTO dbo.OrderShipping_Gold (custId, orderId, method, eta)
SELECT
    s.custId,
    TRY_CAST(JSON_VALUE(o.[value], '$.orderId') AS INT) AS orderId,
    JSON_VALUE(o.[value], '$.shipping.method')          AS method,
    JSON_VALUE(o.[value], '$.shipping.eta')             AS eta
FROM dbo.Json_Silver s
CROSS APPLY OPENJSON(s.RecordDetails, '$.orders') AS o
WHERE s.IsValidJson = 1
  AND s.ValidationNote = 'OK'
  AND s.custId IS NOT NULL
  AND JSON_VALUE(o.[value], '$.orderId') IS NOT NULL;
GO

-- 6C) OrderCoupon_Gold (coupons array of scalars)
TRUNCATE TABLE dbo.OrderCoupon_Gold;

INSERT INTO dbo.OrderCoupon_Gold (custId, orderId, coupon)
SELECT
    s.custId,
    TRY_CAST(JSON_VALUE(o.[value], '$.orderId') AS INT) AS orderId,
    c.[value]                                           AS coupon
FROM dbo.Json_Silver s
CROSS APPLY OPENJSON(s.RecordDetails, '$.orders') AS o
CROSS APPLY OPENJSON(o.[value], '$.coupons')      AS c
WHERE s.IsValidJson = 1
  AND s.ValidationNote = 'OK'
  AND s.custId IS NOT NULL
  AND JSON_VALUE(o.[value], '$.orderId') IS NOT NULL;
GO

-- 6D) OrderMeta_Gold (meta map/dictionary object -> key/value rows)
TRUNCATE TABLE dbo.OrderMeta_Gold;

INSERT INTO dbo.OrderMeta_Gold (custId, orderId, meta_key, meta_val)
SELECT
    s.custId,
    TRY_CAST(JSON_VALUE(o.[value], '$.orderId') AS INT) AS orderId,
    m.[key]                                             AS meta_key,
    m.[value]                                           AS meta_val
FROM dbo.Json_Silver s
CROSS APPLY OPENJSON(s.RecordDetails, '$.orders') AS o
CROSS APPLY OPENJSON(o.[value], '$.meta')         AS m
WHERE s.IsValidJson = 1
  AND s.ValidationNote = 'OK'
  AND s.custId IS NOT NULL
  AND JSON_VALUE(o.[value], '$.orderId') IS NOT NULL;
GO

-- 6E) OrderItemAttr_Gold (nested attrs object per item)
TRUNCATE TABLE dbo.OrderItemAttr_Gold;

INSERT INTO dbo.OrderItemAttr_Gold (custId, orderId, sku, color, size)
SELECT
    s.custId,
    TRY_CAST(JSON_VALUE(o.[value], '$.orderId') AS INT) AS orderId,
    JSON_VALUE(i.[value], '$.sku')                      AS sku,
    JSON_VALUE(i.[value], '$.attrs.color')              AS color,
    JSON_VALUE(i.[value], '$.attrs.size')               AS size
FROM dbo.Json_Silver s
CROSS APPLY OPENJSON(s.RecordDetails, '$.orders') AS o
CROSS APPLY OPENJSON(o.[value], '$.items')        AS i
WHERE s.IsValidJson = 1
  AND s.ValidationNote = 'OK'
  AND s.custId IS NOT NULL
  AND JSON_VALUE(o.[value], '$.orderId') IS NOT NULL
  AND JSON_VALUE(i.[value], '$.sku') IS NOT NULL;
GO


------------------------------------------------------------------------------------------------------------------------
-- 7) GOLD VALIDATION — counts + sample join check + optional "super-flat" view
------------------------------------------------------------------------------------------------------------------------

SELECT COUNT(*) AS CustomerRows        FROM dbo.Customer_Gold;
SELECT COUNT(*) AS OrderRows           FROM dbo.Order_Gold;
SELECT COUNT(*) AS ItemRows            FROM dbo.OrderItem_Gold;

SELECT COUNT(*) AS AddressRows         FROM dbo.CustomerAddress_Gold;
SELECT COUNT(*) AS ShippingRows        FROM dbo.OrderShipping_Gold;
SELECT COUNT(*) AS CouponRows          FROM dbo.OrderCoupon_Gold;
SELECT COUNT(*) AS MetaRows            FROM dbo.OrderMeta_Gold;
SELECT COUNT(*) AS ItemAttrRows        FROM dbo.OrderItemAttr_Gold;

-- Sample joined output (flat across entities)
SELECT TOP 200
    c.custId,
    c.custName,
    ca.city,
    ca.zip,
    ca.geo_lat,
    ca.geo_lon,
    o.orderId,
    o.amount,
    sh.method AS shipping_method,
    sh.eta    AS shipping_eta,
    oi.sku,
    oi.qty,
    ia.color,
    ia.size
FROM dbo.Customer_Gold c
LEFT JOIN dbo.CustomerAddress_Gold ca
    ON ca.custId = c.custId
LEFT JOIN dbo.Order_Gold o
    ON o.custId = c.custId
LEFT JOIN dbo.OrderItem_Gold oi
    ON oi.custId = o.custId AND oi.orderId = o.orderId
LEFT JOIN dbo.OrderShipping_Gold sh
    ON sh.custId = o.custId AND sh.orderId = o.orderId
LEFT JOIN dbo.OrderItemAttr_Gold ia
    ON ia.custId = oi.custId AND ia.orderId = oi.orderId AND ia.sku = oi.sku
ORDER BY c.custId, o.orderId, oi.sku;
GO


------------------------------------------------------------------------------------------------------------------------
-- 8) Output Gold as JSON (useful for demo/API style output)
------------------------------------------------------------------------------------------------------------------------

-- Customers as JSON
SELECT custId, custName, city
FROM dbo.Customer_Gold
FOR JSON PATH;
GO

-- Orders as JSON
SELECT custId, orderId, amount
FROM dbo.Order_Gold
FOR JSON PATH;
GO


DROP VIEW IF EXISTS dbo.vw_Gold_OrderItem_Fact;
GO

CREATE VIEW dbo.vw_Gold_OrderItem_Fact
AS
SELECT
    c.custId,
    c.custName,
    c.city,
    o.orderId,
    o.amount AS orderAmount,
    i.sku,
    i.qty
FROM dbo.Customer_Gold c
INNER JOIN dbo.Order_Gold o
    ON o.custId = c.custId
INNER JOIN dbo.OrderItem_Gold i
    ON i.custId = o.custId
   AND i.orderId = o.orderId;
GO




DROP VIEW IF EXISTS dbo.vw_Gold_Customer360;
GO

CREATE VIEW dbo.vw_Gold_Customer360
AS
SELECT
    c.custId,
    c.custName,
    c.city,
    COUNT(DISTINCT o.orderId) AS orderCount,
    SUM(o.amount)             AS totalSpend,
    AVG(o.amount)             AS avgOrderValue
FROM dbo.Customer_Gold c
LEFT JOIN dbo.Order_Gold o
    ON o.custId = c.custId
GROUP BY
    c.custId, c.custName, c.city;
GO



DROP VIEW IF EXISTS dbo.vw_Gold_SalesByCity;
GO

CREATE VIEW dbo.vw_Gold_SalesByCity
AS
SELECT
    c.city,
    COUNT(DISTINCT c.custId) AS customerCount,
    COUNT(DISTINCT o.orderId) AS orderCount,
    SUM(o.amount) AS totalRevenue,
    AVG(o.amount) AS avgOrderValue
FROM dbo.Customer_Gold c
LEFT JOIN dbo.Order_Gold o
    ON o.custId = c.custId
GROUP BY c.city;
GO


SELECT * FROM  dbo.vw_Gold_OrderItem_Fact
SELECT * FROM vw_Gold_Customer360
SELECT * FROM  dbo.vw_Gold_SalesByCity
