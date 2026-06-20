// SupplyLens Neo4j constraints and indexes
// Run via: cypher-shell -u neo4j -p PASSWORD < 03_neo4j_init.cypher
// Or paste into Neo4j Browser at http://10.0.1.114:7474

CREATE CONSTRAINT company_id IF NOT EXISTS FOR (c:Company) REQUIRE c.id IS UNIQUE;
CREATE CONSTRAINT product_id IF NOT EXISTS FOR (p:Product) REQUIRE p.id IS UNIQUE;
CREATE CONSTRAINT facility_id IF NOT EXISTS FOR (f:Facility) REQUIRE f.id IS UNIQUE;
CREATE CONSTRAINT risk_id IF NOT EXISTS FOR (r:Risk) REQUIRE r.id IS UNIQUE;
CREATE CONSTRAINT cert_id IF NOT EXISTS FOR (c:Cert) REQUIRE c.id IS UNIQUE;

CREATE INDEX company_name IF NOT EXISTS FOR (c:Company) ON (c.name);
CREATE INDEX company_country IF NOT EXISTS FOR (c:Company) ON (c.country);
CREATE INDEX company_confidence IF NOT EXISTS FOR (c:Company) ON (c.confidence);
CREATE INDEX risk_type IF NOT EXISTS FOR (r:Risk) ON (r.type);
