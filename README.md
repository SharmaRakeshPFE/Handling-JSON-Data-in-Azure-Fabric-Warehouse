# Handling-JSON-Data-in-Azure-Fabric-Warehouse
This repository contains sample data, scripts, and practical approaches for storing, querying, and handling JSON data in Microsoft Fabric Warehouse.

It demonstrates:

- ✅ Recommended patterns to store JSON data
- ✅ How to validate and inspect JSON using Fabric Warehouse built‑in functions
- ✅ Techniques to extract scalars, objects, and arrays from JSON
- ✅ Methods to flatten nested JSON and arrays using OPENJSON
- ✅ JSON construction and output patterns using JSON_OBJECT, JSON_ARRAY, and FOR JSON
- ✅ Function equivalence and migration guidance for teams moving from AWS Athena to Fabric Warehouse
- ✅ Athena patterns translattion to Fabric

The repository is intended for Learning and to showcase capabilities of Azure Fabric Warehouse in handling JSON data and intended for:

1) Data engineers and architects evaluating JSON support in Fabric Warehouse
2) Customers migrating from Athena / Presto / Trino
3) Demo and PoC scenarios showcasing semi‑structured data handling in Fabric Warehouse

 <h1> 🧱 Architecture Covered (Medallion Pattern) </h1>
 
<h2>🥉 Bronze Layer – Raw JSON</h2>

- Stores JSON exactly as received
- No transformations applied
- Preserves data for audit, replay, and troubleshooting
- Accepts both valid and invalid JSON

<h2>🥈 Silver Layer – Clean & Validated</h2>

Acts as a data quality gate
- Separates valid vs invalid JSON
- Normalizes frequently used fields (e.g., custId, city)
- Handles schema drift and type inconsistencies
- Invalid records are captured in a Quarantine table
- Ensures Gold never sees bad JSON

<h2>🥇 Gold Layer – Analytics Ready</h2>

- Fully flattened relational tables
**One row per:**
- Customer
- Order
- Order Item


<h2> Athena → Microsoft Fabric Warehouse: JSON Function Mapping (with alternatives) </h2>
This repo includes migration-friendly patterns for teams moving JSON workloads from AWS Athena (Presto/Trino functions) to Microsoft Fabric Warehouse (T‑SQL JSON functions)
