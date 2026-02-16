--##################################################################
--A) json_extract_scalar ? JSON_VALUE
--##################################################################

SELECT TRY_CAST(JSON_VALUE(RecordDetails, '$.custId') AS INT) AS custId
FROM dbo.Json_Bronze
WHERE ISJSON(RecordDetails) = 1;

--##################################################################
--B) json_extract ? JSON_QUERY
--##################################################################

SELECT JSON_QUERY(RecordDetails, '$.orders') AS orders_json
FROM dbo.Json_Bronze
WHERE ISJSON(RecordDetails) = 1;
--##################################################################
--C) json_parse ? (Fabric pattern)
--##################################################################

SELECT
    b.RowId,
    x.custId,
    x.custName
FROM dbo.Json_Bronze b
CROSS APPLY OPENJSON(b.RecordDetails)
WITH
(
    custId   INT          '$.custId',
    custName VARCHAR(200) '$.name'
) AS x
WHERE ISJSON(b.RecordDetails) = 1;

--##################################################################
--D) UNNEST ? OPENJSON(json, '$.array')
--##################################################################

SELECT
    b.RowId,
    o.[value] AS tag
FROM dbo.Json_Bronze b
CROSS APPLY OPENJSON(b.RecordDetails, '$.tags') o
WHERE ISJSON(b.RecordDetails) = 1;

SELECT
    b.RowId,
    t.[value] AS first_tag
FROM dbo.Json_Bronze b
CROSS APPLY OPENJSON(b.RecordDetails, '$.tags') t
WHERE ISJSON(b.RecordDetails) = 1
  AND t.[key] = 0;

--##################################################################
--E) json_array_get / element_at ? OPENJSON + filter by [key]
--##################################################################
SELECT
    b.RowId,
    t.[value] AS first_tag
FROM dbo.Json_Bronze b
CROSS APPLY OPENJSON(b.RecordDetails, '$.tags') t
WHERE ISJSON(b.RecordDetails) = 1
  AND t.[key] = 0;

--##################################################################
--F) array_join ? STRING_AGG after OPENJSON
--##################################################################
SELECT
    b.RowId,
    STRING_AGG(t.[value], ',') AS tags_csv
FROM dbo.Json_Bronze b
CROSS APPLY OPENJSON(b.RecordDetails, '$.tags') t
WHERE ISJSON(b.RecordDetails) = 1
GROUP BY b.RowId;

--##################################################################
--G) CARDINALITY ? COUNT(*) after OPENJSON
--##################################################################

SELECT
    b.RowId,
    COUNT(*) AS tag_count
FROM dbo.Json_Bronze b
CROSS APPLY OPENJSON(b.RecordDetails, '$.tags') t
WHERE ISJSON(b.RecordDetails) = 1
GROUP BY b.RowId;