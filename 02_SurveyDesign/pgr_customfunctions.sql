-------------------------------------------------------------------------------------------------------------------------------------
--PGROUTING: custom functions
--	     1. pgr_createnetwork(varchar): function to create a routable street network
--	     2. pgr_createroutestops(varchar, integer): function to create route stops from a set of sample points
--	     3. pgr_dijkstramulti(varchar, varchar): function to run dijkstra iteratively on a sequence of nodes
--DEPENDS:   pgrouting 2.4, postgis 2.0
--DESCR:     adds custom functions to the standard pgrouting functionality
-------------------------------------------------------------------------------------------------------------------------------------
--Author: M. Wieland
--Last modified: 08.05.2017
------------------------------------------------------------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgrouting;
CREATE SCHEMA routing;

----------------------------------------------------------------------------------------------------------------
--create routable streetnetwork (note: input table should have at least the following columns - gid, geom)--
----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION pgr_createnetwork(
		IN tbl_streets varchar,
		OUT pgr_network varchar
        )
        RETURNS varchar AS
$BODY$
BEGIN
	EXECUTE 
	'--add "source" and "target" column
	 ALTER TABLE ' || tbl_streets || ' ADD COLUMN "source" integer;
	 ALTER TABLE ' || tbl_streets || ' ADD COLUMN "target" integer;
	 --create cost column (defaults to length)
	 ALTER TABLE ' || tbl_streets || ' ADD COLUMN "cost" double precision;
	 UPDATE ' || tbl_streets || ' SET cost = ST_Length(geom);
	 --create pgr topology
	 SELECT pgr_createTopology(''' || tbl_streets || ''', 0.00001, ''geom'', ''gid'');
	 --create indices
	 CREATE INDEX source_idx ON ' || tbl_streets || ' ("source");
	 CREATE INDEX target_idx ON ' || tbl_streets || ' ("target");
	
	 --option1: analyse network topology (note: check messages for errors) - http://docs.pgrouting.org/2.0/en/doc/src/tutorial/analytics.html#analytics
	 SELECT pgr_analyzeGraph(''' || tbl_streets || ''', 0.00001, ''geom'', ''gid'');
	
	 --option2: define reverse travelling cost (only needed if specified in pgr function arguments)
	 ALTER TABLE ' || tbl_streets || ' ADD COLUMN reverse_cost double precision;
	 UPDATE ' || tbl_streets || ' SET reverse_cost = cost;
	';
END;
$BODY$
LANGUAGE 'plpgsql' VOLATILE STRICT;


------------------------------------------
--create route stops from sample points --
------------------------------------------
CREATE OR REPLACE FUNCTION pgr_createroutestops(
		IN tbl_streets_vertices varchar,
		IN tbl_samples varchar,
		IN nr_stops integer,
		OUT pgr_stops varchar
        )
        RETURNS varchar AS
$BODY$
BEGIN
	--create a random subset of a larger set of sample_points
	CREATE TABLE routing.sample_points (id serial, geom geometry);
	EXECUTE 'INSERT INTO routing.sample_points (geom) SELECT geom FROM ' || tbl_samples || ' ORDER BY random() limit ' || nr_stops || ';';
	--create table that holds the route stops
	DROP TABLE IF EXISTS routing.route_stops cascade;
	CREATE TABLE routing.route_stops (id serial, x double precision, y double precision, node integer, geom geometry);
	INSERT INTO routing.route_stops (id) select id from routing.sample_points;
	--get nearest network node to sample point and write its id as node to stops table
	EXECUTE 'UPDATE routing.route_stops SET node = c.node FROM(
		 SELECT DISTINCT ON (a.id) a.id as sample, b.id as node, ST_Distance(a.geom, b.geom) as distance
		 FROM routing.sample_points as a, ' || tbl_streets_vertices || ' as b group by sample, node, distance ORDER BY sample, distance asc) c
		 WHERE id = c.sample;';
	--delete duplicate nodes from stops table (it can happen that several stops have the same nearest node. in this case only use the node once as stop)
	DELETE FROM routing.route_stops
	WHERE id IN (SELECT id
		    FROM (SELECT id,
				 row_number() over (partition by node order by id) as rnum
		       FROM routing.route_stops) t
		WHERE t.rnum > 1);
	--clean id column
	ALTER TABLE routing.route_stops DROP column id;
	ALTER TABLE routing.route_stops ADD column id serial;
	--add also geom to the route stops and calculate x and y coordinates
	EXECUTE 'UPDATE routing.route_stops SET geom = ' || tbl_streets_vertices ||'.geom FROM ' || tbl_streets_vertices || ' WHERE routing.route_stops.node = ' || tbl_streets_vertices ||'.id;';
	UPDATE routing.route_stops SET x = st_x(geom), y = st_y(geom);
	--drop sample_points table
	DROP TABLE routing.sample_points;
END;
$BODY$
LANGUAGE 'plpgsql' VOLATILE STRICT;


-------------------------------------------------------------------------------------------------------------------
-- run dijkstra function multiple times to output shortest path through multiple stops (e.g. sorted points from TSP)
-------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION pgr_dijkstramulti(
		IN tbl_stops varchar,
		IN tbl_streets varchar,
		OUT route_dijkstramulti varchar
        )
        RETURNS varchar AS
$BODY$
DECLARE
        sql     text;
        rec 	record;
BEGIN
	DROP TABLE IF EXISTS routing.route_dijkstramulti;
	CREATE TABLE routing.route_dijkstramulti (seq integer, node integer, edge integer, cost double precision, agg_cost double precision, geom geometry);
        FOR rec IN EXECUTE 'SELECT seq FROM ' || tbl_stops || ';' LOOP
	    EXECUTE 'INSERT INTO routing.route_dijkstramulti 
			SELECT seq, node, edge, cost, agg_cost, geom FROM pgr_dijkstra(
				''SELECT id, source, target, cost, reverse_cost FROM ' || tbl_streets || ''', 
				(SELECT node FROM ' || tbl_stops || ' WHERE seq='|| rec.seq ||'), 
				(SELECT node FROM ' || tbl_stops || ' WHERE seq=' || rec.seq+1 || ')
			) a LEFT JOIN (SELECT id, geom FROM ' || tbl_streets || ') b ON (a.edge = b.id);';
	END LOOP;
        RETURN;
END;
$BODY$
LANGUAGE 'plpgsql' VOLATILE STRICT;
