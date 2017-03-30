
-- Function to get n nearest neighbor CIMIS stations
CREATE OR REPLACE FUNCTION public.fn_get_nearest_cimis_stns_3310_excude_id(
    geom1 geometry,
    numnn integer,
    start_date date,
    stn_id numeric)
  RETURNS SETOF cimis_stations_list AS
$BODY$
    SELECT csl.*  
        FROM cimis_stations_list As csl
        WHERE csl.stn_num != stn_id
			AND (csl.stn_off_date IS NULL 
					OR csl.stn_off_date >= $3)
        ORDER BY ST_Distance(csl.geom_3310, $1) LIMIT $2  
    $BODY$
  LANGUAGE sql VOLATILE
  COST 100
  ROWS 10; --estimated number of return rows