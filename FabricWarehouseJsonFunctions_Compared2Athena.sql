/*-----------------------------------------------------------------------------------
  A) SETUP DEMO TABLE + 10 RECORDS
-----------------------------------------------------------------------------------*/

IF OBJECT_ID('dbo.JsonNestedArrayStage', 'U') IS NOT NULL
    DROP TABLE dbo.JsonNestedArrayStage;
GO

CREATE TABLE dbo.JsonNestedArrayStage
(
    RecordId      int           NOT NULL,
    RecordDetails nvarchar(max) NOT NULL
);
GO

/*
JSON Shape used (nested arrays):
{
  "custId": 124,
  "name": "Rakesh_1",
  "address": { "city": "Bengaluru", "zip": "560001" },
  "tags": ["vip","newsletter",...],
  "orders": [
     {
        "id": 1,
        "amount": 101.5,
        "items": [
            {"sku":"A1","qty":2,"price":10.0,"discounts":[5,10]},
            {"sku":"B2","qty":1,"price":20.0,"discounts":[0]}
        ]
     }
  ],
  "matrix": [[1,2,3],[4,5,6]]
}
*/

INSERT INTO dbo.JsonNestedArrayStage (RecordId, RecordDetails)
VALUES
(1,  N'{"custId":124,"name":"Rakesh_1","address":{"city":"Bengaluru","zip":"560001"},"tags":["vip","newsletter","Rakesh","Sharma","tag1"],"orders":[{"id":1,"amount":101.5,"items":[{"sku":"A1","qty":2,"price":10.0,"discounts":[5,10]},{"sku":"B2","qty":1,"price":20.0,"discounts":[0]}]},{"id":2,"amount":202.0,"items":[{"sku":"C3","qty":3,"price":15.0,"discounts":[2]}]}],"matrix":[[1,2,3],[4,5,6]]}'),
(2,  N'{"custId":125,"name":"Rakesh_2","address":{"city":"Bengaluru","zip":"560002"},"tags":["standard","promo"],"orders":[{"id":10,"amount":50.0,"items":[]}],"matrix":[[7,8],[9,10]]}'),
(3,  N'{"custId":126,"name":"Rakesh_3","address":{"city":"Mysuru","zip":"570001"},"tags":["vip"],"orders":[{"id":11,"amount":75.25,"items":[{"sku":"D4","qty":1,"price":75.25,"discounts":[]}]}]}'),
(4,  N'{"custId":127,"name":"Rakesh_4","address":{"city":"Chennai","zip":"600001"},"tags":["newsletter","tagX"],"orders":[{"id":12,"amount":0,"items":[{"sku":"E5","qty":0,"price":0,"discounts":[0,0]}]}],"matrix":[]}'),
(5,  N'{"custId":128,"name":"Rakesh_5","address":{"city":"Hyderabad","zip":"500001"},"tags":[],"orders":[],"matrix":[[100]]}'),
(6,  N'{"custId":129,"name":"Rakesh_6","address":{"city":"Pune","zip":"411001"},"tags":["vip","priority"],"orders":[{"id":13,"amount":999.99,"items":[{"sku":"F6","qty":5,"price":100.0,"discounts":[5,5,5]},{"sku":"G7","qty":2,"price":249.995,"discounts":[10]}]}]}'),
(7,  N'{"custId":130,"name":"Rakesh_7","address":{"city":"Delhi","zip":"110001"},"tags":["standard"],"orders":[{"id":14,"amount":300.0,"items":[{"sku":"H8","qty":3,"price":100.0,"discounts":[15]}]}],"matrix":[[1],[2],[3]]}'),
(8,  N'{"custId":131,"name":"Rakesh_8","address":{"city":"Kochi","zip":"682001"},"tags":["vip","newsletter"],"orders":[{"id":15,"amount":120.0,"items":[{"sku":"I9","qty":2,"price":60.0,"discounts":[5]},{"sku":"J10","qty":1,"price":60.0,"discounts":[5,10]}]},{"id":16,"amount":10.0,"items":[{"sku":"K11","qty":1,"price":10.0,"discounts":[0]}]}]}'),
(9,  N'{"custId":132,"name":"Rakesh_9","address":{"city":"Mumbai","zip":"400001"},"tags":["promo","sale","vip"],"orders":[{"id":17,"amount":450.0,"items":[{"sku":"L12","qty":9,"price":50.0,"discounts":[0,5]},{"sku":"M13","qty":1,"price":0.0,"discounts":[100]}]}],"matrix":[[11,12,13,14]]}'),
(10, N'{"custId":133,"name":"Rakesh_10","address":{"city":"Bengaluru","zip":"560003"},"tags":["edgecase"],"orders":[{"id":18,"amount":1.0,"items":[{"sku":"N14","qty":1,"price":1.0,"discounts":[0]}]}]}');
GO

/*-----------------------------------------------------------------------------------
  B) SIDE-BY-SIDE: ATHENA vs FABRIC WAREHOUSE
-----------------------------------------------------------------------------------*/

/*-----------------------------------------------------------------------------------
  0) Baseline check: view JSON + validate
-----------------------------------------------------------------------------------*/

-- [Athena] Example baseline
-- SELECT recordid, recorddetails, json_parse(recorddetails) FROM JsonNestedArrayStage;
-- (In Athena, json_parse returns a JSON typed value if the string is valid.)

-- [Fabric] Baseline: JSON text is stored as NVARCHAR; validate with ISJSON
-- ISJSON(expression) returns 1 if expression contains valid JSON, else 0.
SELECT TOP (10)
    RecordId,
    RecordDetails,
    ISJSON(RecordDetails) AS IsValidJson
FROM dbo.JsonNestedArrayStage;


/*-----------------------------------------------------------------------------------
  1) json_extract_scalar  (Athena)  ->  JSON_VALUE (Fabric)
     Purpose: Extract scalar (string/number/bool) from JSON by JSONPath.
-----------------------------------------------------------------------------------*/

-- [Athena]
-- SELECT recordid,
--        json_extract_scalar(recorddetails, '$.custId') AS custId,
--        json_extract_scalar(recorddetails, '$.name')   AS name,
--        json_extract_scalar(recorddetails, '$.address.city') AS city
-- FROM JsonNestedArrayStage;

-- [Fabric]
-- JSON_VALUE extracts a scalar at a given path.
SELECT
    RecordId,
    JSON_VALUE(RecordDetails, '$.custId')        AS custId,
    JSON_VALUE(RecordDetails, '$.name')          AS name,
    JSON_VALUE(RecordDetails, '$.address.city')  AS city
FROM dbo.JsonNestedArrayStage;


/*-----------------------------------------------------------------------------------
  2) json_extract (Athena)  ->  JSON_QUERY (Fabric)
     Purpose: Extract JSON object/array text at a JSONPath.
-----------------------------------------------------------------------------------*/

-- [Athena]
-- SELECT recordid,
--        json_extract(recorddetails, '$.address') AS address_json,
--        json_extract(recorddetails, '$.orders')  AS orders_json
-- FROM JsonNestedArrayStage;

-- [Fabric]
-- JSON_QUERY returns JSON (object/array) text at a given path.
SELECT
    RecordId,
    JSON_QUERY(RecordDetails, '$.address') AS address_json,
    JSON_QUERY(RecordDetails, '$.orders')  AS orders_json
FROM dbo.JsonNestedArrayStage;


/*-----------------------------------------------------------------------------------
  3) json_parse (Athena)  ->  ISJSON + direct JSON functions (Fabric)
     Purpose: Ensure JSON is valid before extracting; avoid errors/bad rows.
-----------------------------------------------------------------------------------*/

-- [Athena]
-- SELECT recordid
-- FROM JsonNestedArrayStage
-- WHERE json_parse(recorddetails) IS NOT NULL;

-- [Fabric]
-- Filter valid JSON rows
SELECT
    RecordId,
    JSON_VALUE(RecordDetails, '$.name') AS name
FROM dbo.JsonNestedArrayStage
WHERE ISJSON(RecordDetails) = 1;


/*-----------------------------------------------------------------------------------
  4) json_array_get (Athena)  ->  JSON_VALUE/JSON_QUERY with [index] (Fabric)
     Purpose: Fetch element at index from an array.
     Note: JSON path indexes are 0-based in T-SQL JSON path.
-----------------------------------------------------------------------------------*/

-- [Athena]
-- SELECT recordid,
--        json_array_get(json_extract(recorddetails,'$.tags'), 0) AS first_tag_json,
--        json_extract_scalar(recorddetails, '$.tags[0]') AS first_tag_scalar
-- FROM JsonNestedArrayStage;

-- [Fabric]
-- Use JSON_VALUE for scalar array element; JSON_QUERY for object/array element.
SELECT
    RecordId,
    JSON_VALUE(RecordDetails, '$.tags[0]')                  AS first_tag,
    JSON_VALUE(RecordDetails, '$.orders[0].items[1].sku')   AS nested_array_indexing_demo
FROM dbo.JsonNestedArrayStage;


/*-----------------------------------------------------------------------------------
  5) json_format (Athena)  ->  already text / JSON_OBJECT / JSON_ARRAY (Fabric)
     Purpose: Convert JSON to string, or build JSON text from SQL values.
-----------------------------------------------------------------------------------*/

-- [Athena]
-- SELECT recordid,
--        json_format(json_parse(recorddetails)) AS json_text
-- FROM JsonNestedArrayStage;

-- [Fabric]
-- RecordDetails is already JSON text. If you need to construct JSON, use JSON_OBJECT/JSON_ARRAY.
SELECT
    RecordId,
    RecordDetails AS json_text,
    JSON_OBJECT(
        'custId': JSON_VALUE(RecordDetails, '$.custId'),
        'name'  : JSON_VALUE(RecordDetails, '$.name'),
        'zip'   : JSON_VALUE(RecordDetails, '$.address.zip')
    ) AS constructed_customer_json
FROM dbo.JsonNestedArrayStage;


/*-----------------------------------------------------------------------------------
  6) CAST(... AS ARRAY(type)) (Athena)  ->  OPENJSON ... WITH (typed schema) (Fabric)
     Purpose: Convert JSON array to typed relational rows/columns.
-----------------------------------------------------------------------------------*/

-- [Athena]
-- WITH t AS (
--   SELECT recordid,
--          CAST(json_extract(recorddetails,'$.orders') AS ARRAY(JSON)) AS orders
--   FROM JsonNestedArrayStage
-- )
-- SELECT recordid, orders
-- FROM t;

-- [Fabric]
-- OPENJSON + WITH defines typed columns and paths; AS JSON keeps nested JSON for further shredding.
SELECT
    s.RecordId,
    o.order_id,
    o.order_amount,
    o.items_json
FROM dbo.JsonNestedArrayStage s
CROSS APPLY OPENJSON(s.RecordDetails, '$.orders')
WITH (
    order_id     int            '$.id',
    order_amount decimal(18,2)  '$.amount',
    items_json   nvarchar(max)  '$.items' AS JSON
) o;


/*-----------------------------------------------------------------------------------
  7) UNNEST (Athena)  ->  CROSS APPLY / OUTER APPLY OPENJSON (Fabric)
     Purpose: Expand arrays into rows. Works for nested arrays with multiple APPLY levels.
-----------------------------------------------------------------------------------*/

-- [Athena] UNNEST tags
-- SELECT recordid, tag
-- FROM JsonNestedArrayStage
-- CROSS JOIN UNNEST(CAST(json_extract(recorddetails,'$.tags') AS ARRAY(VARCHAR))) AS u(tag);

-- [Fabric] UNNEST tags
SELECT
    s.RecordId,
    CAST(t.[value] AS nvarchar(200)) AS tag
FROM dbo.JsonNestedArrayStage s
CROSS APPLY OPENJSON(s.RecordDetails, '$.tags') t;

-- [Athena] NESTED UNNEST orders -> items
-- SELECT recordid, o.id AS order_id, i.sku, i.qty, i.price
-- FROM JsonNestedArrayStage
-- CROSS JOIN UNNEST(CAST(json_extract(recorddetails,'$.orders') AS ARRAY(JSON))) AS ord(o)
-- CROSS JOIN UNNEST(CAST(json_extract(o, '$.items') AS ARRAY(JSON))) AS itm(i);

-- [Fabric] NESTED UNNEST orders -> items
SELECT
    s.RecordId,
    o.order_id,
    i.sku,
    i.qty,
    i.price,
    CAST(i.qty * i.price AS decimal(18,2)) AS line_total
FROM dbo.JsonNestedArrayStage s
CROSS APPLY OPENJSON(s.RecordDetails, '$.orders')
WITH (
    order_id   int           '$.id',
    items_json nvarchar(max) '$.items' AS JSON
) o
OUTER APPLY OPENJSON(o.items_json)
WITH (
    sku   nvarchar(50) '$.sku',
    qty   int          '$.qty',
    price decimal(18,2)'$.price'
) i;

-- [Athena] 3-level nested UNNEST orders -> items -> discounts
-- SELECT recordid, o.id, i.sku, d
-- FROM JsonNestedArrayStage
-- CROSS JOIN UNNEST(CAST(json_extract(recorddetails,'$.orders') AS ARRAY(JSON))) AS ord(o)
-- CROSS JOIN UNNEST(CAST(json_extract(o,'$.items') AS ARRAY(JSON))) AS itm(i)
-- CROSS JOIN UNNEST(CAST(json_extract(i,'$.discounts') AS ARRAY(INTEGER))) AS dis(d);

-- [Fabric] 3-level nested UNNEST orders -> items -> discounts
SELECT
    s.RecordId,
    o.order_id,
    it.sku,
    d.[key] AS discount_index,
    TRY_CONVERT(decimal(18,2), d.[value]) AS discount_value
FROM dbo.JsonNestedArrayStage s
CROSS APPLY OPENJSON(s.RecordDetails, '$.orders')
WITH (
    order_id   int           '$.id',
    items_json nvarchar(max) '$.items' AS JSON
) o
CROSS APPLY OPENJSON(o.items_json)
WITH (
    sku            nvarchar(50) '$.sku',
    discounts_json nvarchar(max) '$.discounts' AS JSON
) it
OUTER APPLY OPENJSON(it.discounts_json) d;


/*-----------------------------------------------------------------------------------
  8) TRANSFORM (Athena)  ->  OPENJSON + expression + JSON_ARRAYAGG (Fabric)
     Purpose: Apply a transformation per array element and rebuild an array.
-----------------------------------------------------------------------------------*/

-- [Athena] upper-case tags
-- SELECT recordid,
--        transform(CAST(json_extract(recorddetails,'$.tags') AS ARRAY(VARCHAR)), x -> upper(x)) AS upper_tags
-- FROM JsonNestedArrayStage;

-- [Fabric] upper-case tags + rebuild JSON array
SELECT
    s.RecordId,
    JSON_ARRAYAGG(UPPER(CAST(t.[value] AS nvarchar(200)))) AS upper_tags_json
FROM dbo.JsonNestedArrayStage s
CROSS APPLY OPENJSON(s.RecordDetails, '$.tags') t
GROUP BY s.RecordId;

-- [Athena] transform nested items into line totals
-- SELECT recordid, o.id AS order_id,
--        transform(CAST(json_extract(o,'$.items') AS ARRAY(JSON)), i -> (json_extract_scalar(i,'$.qty') * json_extract_scalar(i,'$.price'))) AS line_totals
-- FROM JsonNestedArrayStage
-- CROSS JOIN UNNEST(CAST(json_extract(recorddetails,'$.orders') AS ARRAY(JSON))) AS ord(o);

-- [Fabric] transform nested items into line totals (rebuild JSON array)
SELECT
    s.RecordId,
    o.order_id,
    JSON_ARRAYAGG(CAST(i.qty * i.price AS decimal(18,2))) AS line_totals_json
FROM dbo.JsonNestedArrayStage s
CROSS APPLY OPENJSON(s.RecordDetails, '$.orders')
WITH (
    order_id   int           '$.id',
    items_json nvarchar(max) '$.items' AS JSON
) o
CROSS APPLY OPENJSON(o.items_json)
WITH (
    qty   int          '$.qty',
    price decimal(18,2)'$.price'
) i
GROUP BY s.RecordId, o.order_id;


/*-----------------------------------------------------------------------------------
  9) REDUCE (Athena)  ->  OPENJSON + aggregate (Fabric)
     Purpose: Reduce an array to a single value (SUM/COUNT/MIN/MAX/etc.).
-----------------------------------------------------------------------------------*/

-- [Athena] Sum order amounts per record
-- SELECT recordid,
--        reduce(CAST(json_extract(recorddetails,'$.orders') AS ARRAY(JSON)),
--               CAST(0 AS DOUBLE),
--               (s, o) -> s + CAST(json_extract_scalar(o,'$.amount') AS DOUBLE),
--               s -> s) AS total_order_amount
-- FROM JsonNestedArrayStage;

-- [Fabric] Sum order amounts per record
SELECT
    s.RecordId,
    SUM(o.amount) AS total_order_amount
FROM dbo.JsonNestedArrayStage s
CROSS APPLY OPENJSON(s.RecordDetails, '$.orders')
WITH (amount decimal(18,2) '$.amount') o
GROUP BY s.RecordId;

-- [Athena] Sum nested line totals (orders -> items)
-- SELECT recordid,
--        reduce(all_items, 0.0, (s,x) -> s + x, s -> s) AS total_cart_value
-- FROM (
--   SELECT recordid,
--          transform(flatten(transform(orders, o -> CAST(json_extract(o,'$.items') AS ARRAY(JSON)))),
--                    i -> CAST(json_extract_scalar(i,'$.qty') AS DOUBLE) * CAST(json_extract_scalar(i,'$.price') AS DOUBLE)) AS all_items
--   FROM (
--     SELECT recordid, CAST(json_extract(recorddetails,'$.orders') AS ARRAY(JSON)) AS orders
--     FROM JsonNestedArrayStage
--   )
-- );

-- [Fabric] Sum nested line totals (orders -> items)
SELECT
    s.RecordId,
    SUM(CAST(i.qty * i.price AS decimal(18,2))) AS total_cart_value
FROM dbo.JsonNestedArrayStage s
CROSS APPLY OPENJSON(s.RecordDetails, '$.orders')
WITH (items_json nvarchar(max) '$.items' AS JSON) o
CROSS APPLY OPENJSON(o.items_json)
WITH (qty int '$.qty', price decimal(18,2) '$.price') i
GROUP BY s.RecordId;


/*-----------------------------------------------------------------------------------
  10) element_at (Athena)  ->  JSON path [index] / OPENJSON ordering (Fabric)
      Purpose: Get element by position.
      Note: Athena arrays often use 1-based for element_at; JSON path is 0-based.
-----------------------------------------------------------------------------------*/

-- [Athena]
-- SELECT recordid,
--        element_at(CAST(json_extract(recorddetails,'$.tags') AS ARRAY(VARCHAR)), 1) AS first_tag
-- FROM JsonNestedArrayStage;

-- [Fabric]
SELECT
    RecordId,
    JSON_VALUE(RecordDetails, '$.tags[0]') AS first_tag
FROM dbo.JsonNestedArrayStage;

-- [Athena] last element sometimes achieved with element_at(arr, cardinality(arr))
-- SELECT recordid,
--        element_at(arr, cardinality(arr)) AS last_tag
-- FROM (...);

-- [Fabric] last tag using OPENJSON ordering by index
SELECT
    s.RecordId,
    x.last_tag
FROM dbo.JsonNestedArrayStage s
CROSS APPLY (
    SELECT TOP (1) CAST(t.[value] AS nvarchar(200)) AS last_tag
    FROM OPENJSON(s.RecordDetails, '$.tags') t
    ORDER BY TRY_CONVERT(int, t.[key]) DESC
) x;


/*-----------------------------------------------------------------------------------
  11) array_join (Athena)  ->  STRING_AGG over OPENJSON (Fabric)
      Purpose: Join array elements into a delimited string.
-----------------------------------------------------------------------------------*/

-- [Athena]
-- SELECT recordid,
--        array_join(CAST(json_extract(recorddetails,'$.tags') AS ARRAY(VARCHAR)), '|') AS tags_pipe
-- FROM JsonNestedArrayStage;

-- [Fabric]
SELECT
    s.RecordId,
    STRING_AGG(CAST(t.[value] AS nvarchar(200)), '|')
        WITHIN GROUP (ORDER BY TRY_CONVERT(int, t.[key])) AS tags_pipe
FROM dbo.JsonNestedArrayStage s
CROSS APPLY OPENJSON(s.RecordDetails, '$.tags') t
GROUP BY s.RecordId;


/*-----------------------------------------------------------------------------------
  12) CARDINALITY (Athena)  ->  COUNT(*) over OPENJSON (Fabric)
      Purpose: Count elements in an array.
-----------------------------------------------------------------------------------*/

-- [Athena]
-- SELECT recordid,
--        cardinality(CAST(json_extract(recorddetails,'$.tags') AS ARRAY(VARCHAR))) AS tag_count
-- FROM JsonNestedArrayStage;

-- [Fabric]
SELECT
    s.RecordId,
    (SELECT COUNT(*) FROM OPENJSON(s.RecordDetails, '$.tags')) AS tag_count
FROM dbo.JsonNestedArrayStage s;

-- Nested cardinality: items per order
SELECT
    s.RecordId,
    o.order_id,
    (SELECT COUNT(*) FROM OPENJSON(o.items_json)) AS items_count
FROM dbo.JsonNestedArrayStage s
CROSS APPLY OPENJSON(s.RecordDetails, '$.orders')
WITH (
    order_id   int           '$.id',
    items_json nvarchar(max) '$.items' AS JSON
) o;


/*-----------------------------------------------------------------------------------
  13) Array-of-arrays (matrix[][]) flattening
      Purpose: Prove handling of nested arrays even without objects.
-----------------------------------------------------------------------------------*/

-- [Athena]
-- SELECT recordid, r AS row_index, c AS col_index, val
-- FROM JsonNestedArrayStage
-- CROSS JOIN UNNEST(CAST(json_extract(recorddetails,'$.matrix') AS ARRAY(ARRAY(INTEGER)))) WITH ORDINALITY AS t(row, r)
-- CROSS JOIN UNNEST(row) WITH ORDINALITY AS u(val, c);

-- [Fabric]
SELECT
    s.RecordId,
    outerArr.[key] AS row_index,
    innerArr.[key] AS col_index,
    TRY_CONVERT(int, innerArr.[value]) AS cell_value
FROM dbo.JsonNestedArrayStage s
CROSS APPLY OPENJSON(s.RecordDetails, '$.matrix') outerArr
CROSS APPLY OPENJSON(outerArr.[value]) innerArr;


/*-----------------------------------------------------------------------------------
  14) Path existence checks (optional properties / safer branching)
-----------------------------------------------------------------------------------*/

-- [Athena]
-- SELECT recordid,
--        json_extract(recorddetails,'$.orders[0].items[0].discounts[0]') IS NOT NULL AS has_any_discount
-- FROM JsonNestedArrayStage;

-- [Fabric]
SELECT
    RecordId,
    JSON_PATH_EXISTS(RecordDetails, '$.orders[0].items[0].discounts[0]') AS has_any_discount,
    JSON_PATH_EXISTS(RecordDetails, '$.matrix[0][0]')                    AS has_matrix
FROM dbo.JsonNestedArrayStage;

-- END OF FILE
