// =============================================================================
// graph_queries.cypher
// Example Cypher queries for a Neo4j 5.x supply-chain graph.
//
// Node labels:   Supplier, Manufacturer, Product, Warehouse, Customer
// Relationships: SUPPLIES(quantity), PRODUCES, SHIPS_TO(lead_days),
//                ORDERS(amount, date), LOCATED_IN
// =============================================================================


// ---------------------------------------------------------------------------
// Query 1: Create nodes and relationships (sample data setup)
// ---------------------------------------------------------------------------
// Create two suppliers, a manufacturer, a product, and a customer;
// then wire them up with supply-chain relationships.

MERGE (s1:Supplier {id: "SUP-001", name: "Acme Components", country: "US"})
MERGE (s2:Supplier {id: "SUP-002", name: "Beta Materials", country: "DE"})
MERGE (m:Manufacturer {id: "MFG-001", name: "TechBuild Corp", country: "US"})
MERGE (p:Product {id: "PRD-001", name: "Industrial Sensor v2", sku: "IS-V2-001"})
MERGE (w:Warehouse {id: "WH-001", name: "Central Depot", city: "Chicago"})
MERGE (c:Customer {id: "CUST-001", name: "SmartFactory Inc", tier: "enterprise"})

MERGE (s1)-[:SUPPLIES {quantity: 5000, unit: "units/month"}]->(m)
MERGE (s2)-[:SUPPLIES {quantity: 2000, unit: "kg/month"}]->(m)
MERGE (m)-[:PRODUCES]->(p)
MERGE (m)-[:SHIPS_TO {lead_days: 3}]->(w)
MERGE (w)-[:SHIPS_TO {lead_days: 1}]->(c)
MERGE (c)-[:ORDERS {amount: 150000.00, date: date("2025-11-15"), units: 500}]->(p)

RETURN s1, s2, m, p, w, c;


// ---------------------------------------------------------------------------
// Query 2: Find shortest supply path from a supplier to a customer
// ---------------------------------------------------------------------------
MATCH (start:Supplier {id: "SUP-001"}), (end:Customer {id: "CUST-001"})
CALL apoc.algo.dijkstra(start, end, "SUPPLIES|PRODUCES|SHIPS_TO", "lead_days")
YIELD path, weight
RETURN
    [node IN nodes(path) | coalesce(node.name, node.id)] AS SupplyChainPath,
    weight AS TotalLeadDays;

// Without APOC — simple shortest path (unweighted):
MATCH path = shortestPath(
    (s:Supplier {id: "SUP-001"})-[*]-(c:Customer {id: "CUST-001"})
)
RETURN
    [node IN nodes(path) | coalesce(node.name, node.id)] AS Path,
    length(path) AS Hops;


// ---------------------------------------------------------------------------
// Query 3: Pattern match — Customers who ordered a product from a specific supplier
// (multi-hop traversal)
// ---------------------------------------------------------------------------
MATCH (sup:Supplier {country: "US"})
      -[:SUPPLIES]->(m:Manufacturer)
      -[:PRODUCES]->(p:Product)
      <-[:ORDERS]-(c:Customer)
WHERE sup.id = "SUP-001"
RETURN
    c.name        AS CustomerName,
    c.tier        AS CustomerTier,
    p.name        AS ProductOrdered,
    m.name        AS ManufacturedBy
ORDER BY c.name;


// ---------------------------------------------------------------------------
// Query 4: Aggregation — Top 5 suppliers by total units supplied
// ---------------------------------------------------------------------------
MATCH (s:Supplier)-[r:SUPPLIES]->(:Manufacturer)
RETURN
    s.name                    AS Supplier,
    s.country                 AS Country,
    sum(r.quantity)           AS TotalUnitsPerMonth,
    count(DISTINCT r)         AS ManufacturerCount
ORDER BY TotalUnitsPerMonth DESC
LIMIT 5;


// ---------------------------------------------------------------------------
// Query 5: Identify single-source risk — products with only one supplier
// ---------------------------------------------------------------------------
MATCH (s:Supplier)-[:SUPPLIES]->(m:Manufacturer)-[:PRODUCES]->(p:Product)
WITH p, collect(DISTINCT s) AS suppliers, m
WHERE size(suppliers) = 1
RETURN
    p.name        AS Product,
    p.sku         AS SKU,
    m.name        AS Manufacturer,
    suppliers[0].name AS SingleSupplier,
    suppliers[0].country AS SupplierCountry
ORDER BY Product;
