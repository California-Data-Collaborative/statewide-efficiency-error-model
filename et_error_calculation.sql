WITH
	-- average daily et for each station and month
	avg_daily_et AS (
		SELECT stn_id, et_month, avg(et_reference_eto) AS avg_et 
		FROM cimis_et_reading 
		WHERE et_reference_eto IS NOT NULL
		GROUP BY stn_id, et_month
		ORDER BY stn_id, et_month
	),
	
	-- join average daily column onto cimis_et_reading table
	cimis_readings_with_avg AS (
		SELECT c.*, a.avg_et 
		FROM cimis_et_reading c, avg_daily_et a
		WHERE c.stn_id = a.stn_id
			AND c.et_month = a.et_month
	),
	-- fill in gaps in ET readings with the average values for that station and month
	cimis_readings_gapfilled AS (
		SELECT et_reading_id, stn_id, et_date, et_year, et_month, et_reference_eto, avg_et,
			CASE WHEN et_reference_eto IS NULL THEN avg_et
			     ELSE et_reference_eto 
			END AS estimated_et
		FROM cimis_readings_with_avg
	),
	-- get the nearest neighborr stations for each agency
	stns_with_nn AS (
		SELECT
		stns.stn_name,
		stns.stn_num,
		(fn_get_nearest_cimis_stns_3310_excude_id(stns.geom_3310, 10, '2013-01-01', stns.stn_num)).stn_num nn_stn_num,
		ST_Distance((fn_get_nearest_cimis_stns_3310_excude_id(stns.geom_3310, 10, '2013-01-01', stns.stn_num)).geom_3310, 
				ST_Centroid(stns.geom_3310)) AS dist
		FROM (SELECT * FROM cimis_stations_list ) stns 
	),
	-- aggregate ET by month
	montly_et AS (
		SELECT stn_id as et_reading_stn_id, et_year, et_month, SUM(estimated_et) AS et_amount, 
			COUNT(estimated_et) AS num_et_readings
		FROM cimis_readings_gapfilled
		WHERE et_year >= 2013
		GROUP BY stn_id, et_year, et_month
	),
	-- weight the ET readings by distance to agency boundary
	stns_with_et_and_dist AS (
		SELECT
		*,
		1/(1+dist) weight,
		et_amount/(1+dist) weighted_eto
		FROM montly_et et, stns_with_nn
		WHERE et.et_reading_stn_id = stns_with_nn.nn_stn_num
	),
	-- calculate inverse distance-weighted average of ET readings from nearest stations
	stn_avg_monthly_eto AS (
		SELECT
		stn_num,
		max(stn_name) as stn_name,
		et_year,
		et_month,
		SUM(weighted_eto)/SUM(weight) weighted_avg_eto 
		FROM stns_with_et_and_dist
		WHERE et_amount IS NOT NULL
			AND num_et_readings >= 28
	GROUP BY stn_num, et_year, et_month
	),
	-- join the approximate ET for each ET station with the actual ET reading from that station 
	stn_monthly_avg_with_true_et AS (
		SELECT stn_avg_monthly_eto.*, montly_et.et_amount, 
			 stn_avg_monthly_eto.weighted_avg_eto / montly_et.et_amount AS accuracy_ratio
		FROM stn_avg_monthly_eto, montly_et
		WHERE stn_avg_monthly_eto.stn_num = montly_et.et_reading_stn_id
			AND stn_avg_monthly_eto.et_year = montly_et.et_year
			AND stn_avg_monthly_eto.et_month = montly_et.et_month
	)
	
select * from stn_monthly_avg_with_true_et