/*
CREATE TABLE policies(
	policy_id INT PRIMARY KEY,
	state VARCHAR(5) NOT NULL,
	driver_age INT NOT NULL,
	vehicle_type VARCHAR(50) NOT NULL,
	claim_probability FLOAT NOT NULL,
	annual_premium FLOAT NOT NULL
);
*/

/*
CREATE TABLE claims(
	claim_id INT PRIMARY KEY,
	claim_date TIMESTAMP NOT NULL,
	policy_id INTEGER REFERENCES policies(policy_id),
	claim_amount FLOAT NOT NULL,
	peril_type VARCHAR(50) NOT NULL
);
*/

SELECT * FROM policies;

--UPDATE policies
--SET claim_probability = ROUND(claim_probability::numeric, 4);

--UPDATE policies
--SET annual_premium = ROUND(annual_premium::numeric, 2);

SELECT * FROM claims;

/*
CREATE OR REPLACE VIEW policy_claims AS
SELECT
	policies.policy_id,
	state,
	driver_age,
	vehicle_type,
	annual_premium,
	claim_date,
	claim_amount,
	peril_type
FROM policies
LEFT JOIN claims
ON policies.policy_id = claims.policy_id;
*/

SELECT * FROM policy_claims;

----------------------------- START HERE -----------------------------

---- BASIC METRICS
SELECT COUNT(*)
AS total_policies
FROM policies;

SELECT COUNT(*)
AS total_claims
FROM claims;

SELECT (SELECT COUNT(*) FROM claims)::float / (SELECT COUNT(*) FROM policies)
AS overall_claim_frequency;

SELECT AVG(claim_amount)
AS average_severity
FROM claims;

SELECT SUM(annual_premium)
AS total_premium
FROM policies;

SELECT SUM(claim_amount)
AS total_loss
FROM claims;

SELECT (SELECT SUM(claim_amount) FROM claims) /
	(SELECT SUM(annual_premium) FROM policies)
AS loss_ratio;

SELECT
	COUNT(policy_id) AS total_policies,
	COUNT(claim_amount) AS total_claims,
	COUNT(claim_amount)::float / COUNT(policy_id) AS claim_freq,
	ROUND(AVG(claim_amount)::numeric, 2) AS avg_severity,
	ROUND(SUM(annual_premium)::numeric, 2) AS total_premium,
	ROUND(SUM(claim_amount)::numeric, 2) AS total_loss,
	ROUND(SUM(claim_amount)::numeric / SUM(annual_premium)::numeric, 4) AS loss_ratio
FROM policy_claims;

---- SEGMENTED ANALYSIS

-- 1) by vehicle type

SELECT vehicle_type, COUNT(*) AS policy_count_vehicle
FROM policy_claims
GROUP BY vehicle_type
ORDER BY policy_count_vehicle DESC; -- pretty evenly distributed

SELECT vehicle_type, COUNT(claim_amount) AS claim_count_vehicle
FROM policy_claims
GROUP BY vehicle_type
ORDER BY claim_count_vehicle DESC; -- Sports cars have the highest frequency, sedans lowest

SELECT vehicle_type, AVG(claim_amount) AS avg_sev_vehicle
FROM policy_claims
GROUP BY vehicle_type
ORDER BY avg_sev_vehicle DESC; -- Sports cars have the highest average severity

SELECT vehicle_type, SUM(annual_premium) AS total_prem_vehicle
FROM policy_claims
GROUP BY vehicle_type
ORDER BY total_prem_vehicle DESC; -- Sports cars highest

SELECT vehicle_type, SUM(claim_amount) AS total_loss_vehicle
FROM policy_claims
GROUP BY vehicle_type
ORDER BY total_loss_vehicle DESC; -- Sports cars highest

SELECT vehicle_type, SUM(claim_amount) / SUM(annual_premium) AS loss_ratio_vehicle
FROM policy_claims
GROUP BY vehicle_type
ORDER BY loss_ratio_vehicle DESC; -- Hybrids 0.85 possibly underpriced
								  -- does not agree with Python setup (explained below)
								  -- Sports cars 0.61 good, maybe a little overpriced,
								  -- agrees with Python setup

SELECT
	vehicle_type,
	COUNT(*) AS policies,
	COUNT(claim_amount) AS claims,
	ROUND(COUNT(claim_amount)::numeric / COUNT(*), 4) AS frequency,
	ROUND(AVG(claim_amount)::numeric , 2) AS avg_severity,
	ROUND(SUM(annual_premium)::numeric, 2) AS total_prem,
	ROUND(SUM(claim_amount)::numeric, 2) AS total_loss,
	ROUND(SUM(claim_amount)::numeric / SUM(annual_premium)::numeric, 4) AS loss_ratio
FROM policy_claims
GROUP BY vehicle_type
ORDER BY vehicle_type; -- aggregate table

----- checking hybrids
SELECT vehicle_type, claim_amount
FROM policy_claims
WHERE vehicle_type = 'Hybrid'
ORDER BY claim_amount ASC; -- Likely that due to lognormal distribution,
						   -- there were a couple large claims
-----

-- 2) by age

SELECT
	CASE
		WHEN driver_age BETWEEN 18 AND 25 THEN '18-25'
		WHEN driver_age BETWEEN 26 AND 40 THEN '26-40'
		WHEN driver_age BETWEEN 41 AND 65 THEN '41-65'
		ELSE '65+'
	END AS age_groups,
	COUNT(*) AS policies,
	COUNT(claim_amount) AS claims,
	ROUND(COUNT(claim_amount)::numeric / COUNT(*), 4) AS frequency,
	ROUND(AVG(claim_amount)::numeric , 2) AS severity,
	ROUND(SUM(claim_amount)::numeric / SUM(annual_premium)::numeric, 4) AS loss_ratio
FROM policy_claims
GROUP BY age_groups
ORDER BY age_groups; -- young and old drivers higher frequency as expected
	
-- 3) by time of year

SELECT
	TO_CHAR(claim_date, 'Mon') AS month,
	COUNT(claim_amount) AS claims,
	ROUND(COUNT(claim_amount)::numeric / 10000, 4) AS frequency,
	ROUND(AVG(claim_amount)::numeric , 2) AS severity
	--,ROUND(SUM(claim_amount)::numeric / SUM(annual_premium)::numeric / 12, 4) AS loss_ratio
FROM policy_claims
GROUP BY month
ORDER BY MIN(claim_date)
LIMIT 12; -- High number of claims in Nov, Dec, Jan as expected due to snow
		  -- Small increase around August due to holidays