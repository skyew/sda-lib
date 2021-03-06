---SOC
---Soil organic carbon stock estimate (SOC) in total soil profile (0 cm to the reported depth of the soil profile). The concentration of organic carbon present in the soil expressed in grams C per square meter for the total reported soil profile depth. NULL values are presented where data are incomplete or not available.

---Uses all components with horizon data.
---Does not calculate component SOC below the following component restrictions:
---Lithic bedrock, Paralithic bedrock, Densic bedrock, Fragipan, Duripan, Sulfuric
---
----soc =  ( (hzT * ( ( om / 1.724 ) * db3 )) / 100.0 ) * ((100.0 - fragvol) / 100.0) 

--  soc      = ( (H2 * ( ( L2 / 1.724 ) * J2 )) / 100.0 ) * ((100.0 - K2) / 100.0) 


SELECT areasymbol, areaname, mapunit.mukey, mapunit.mukey AS mulink, mapunit.musym, nationalmusym, mapunit.muname, mukind, muacres
INTO #main
FROM legend
INNER JOIN mapunit on legend.lkey=mapunit.lkey --AND mapunit.mukey = 2809839 For Testing
INNER JOIN muaggatt AS mt1 on mapunit.mukey=mt1.mukey
AND legend.areasymbol <> 'US' -- SSURGO
--AND legend.areasymbol = 'US' -- STATSGO

SELECT
-- grab survey area data
LEFT((areasymbol), 2) AS state,
 l.areasymbol,
 l.areaname,
(SELECT SUM (DISTINCT comppct_r) FROM mapunit  AS mui3  INNER JOIN component AS cint3 ON cint3.mukey=mui3.mukey INNER JOIN chorizon AS chint3 ON chint3.cokey=cint3.cokey AND cint3.cokey = c.cokey GROUP BY chint3.cokey) AS sum_comp,
--grab map unit level information

 mu.mukey,
 mu.musym,

--grab component level information

 c.majcompflag,
 c.comppct_r,
 c.compname,
 compkind,
 localphase,
 slope_l,
 slope_r,
 slope_h,
(SELECT CAST(MIN(resdept_r) AS INTEGER) FROM component LEFT OUTER JOIN corestrictions ON component.cokey = corestrictions.cokey WHERE component.cokey = c.cokey AND reskind  IS NOT NULL) AS restrictiondepth,
(SELECT CASE WHEN MIN (resdept_r) IS NULL THEN 200 ELSE CAST (MIN (resdept_r) AS INT) END FROM component LEFT OUTER JOIN corestrictions ON component.cokey = corestrictions.cokey WHERE component.cokey = c.cokey AND reskind IS NOT NULL) AS restrictiodepth,
(SELECT TOP 1  reskind  FROM component LEFT OUTER JOIN corestrictions ON component.cokey = corestrictions.cokey WHERE component.cokey = c.cokey AND corestrictions.reskind IN ('Lithic bedrock','Duripan', 'Densic bedrock', 'Paralithic bedrock', 'Fragipan', 'Natric', 'Ortstein', 'Permafrost', 'Petrocalcic', 'Petrogypsic')
AND reskind IS NOT NULL ORDER BY resdept_r) AS TOPrestriction, c.cokey,

---begin selection of horizon properties
 hzname,
 hzdept_r,
 hzdepb_r,
 CASE WHEN (hzdepb_r-hzdept_r) IS NULL THEN 0 ELSE CAST((hzdepb_r-hzdept_r) AS INT) END AS thickness,  

  om_r, dbthirdbar_r, 
  (SELECT CASE WHEN SUM (cf.fragvol_r) IS NULL THEN 0 ELSE CAST (SUM(cf.fragvol_r) AS INT) END FROM chfrags cf WHERE cf.chkey = ch.chkey) as fragvol,
brockdepmin,
  texture,
  ch.chkey
INTO #acpf
FROM legend  AS l
INNER JOIN mapunit AS mu ON mu.lkey = l.lkey 
--AND l.areasymbol like 'WI025'
---AND mu.mukey = 2809839 For testing
AND l.areasymbol <> 'US' -- SSURGO
--AND l.areasymbol = 'US' -- STATSGO
INNER JOIN muaggatt AS  mt on mu.mukey=mt.mukey
INNER JOIN component AS  c ON c.mukey = mu.mukey 
INNER JOIN chorizon AS ch ON ch.cokey = c.cokey and CASE WHEN hzdept_r IS NULL THEN 2 
WHEN om_r IS NULL THEN 2 
WHEN om_r = 0 THEN 2 
WHEN dbthirdbar_r IS NULL THEN 2
WHEN dbthirdbar_r = 0 THEN 2
ELSE 1 END = 1
INNER JOIN chtexturegrp ct ON ch.chkey=ct.chkey and ct.rvindicator = 'yes'
ORDER by l.areasymbol, mu.musym, hzdept_r 

---Sums the Component Percent and eliminate duplicate values by cokey
SELECT mukey, cokey,  SUM (DISTINCT sum_comp) AS sum_comp2
INTO #muacpf
FROM #acpf AS acpf2
WHERE acpf2.cokey=cokey
GROUP BY mukey, cokey

---Sums the component percent in a map unit
SELECT mukey, cokey, sum_comp2,  SUM (sum_comp2) over(partition by #muacpf.mukey ) AS sum_comp3 --, SUM (sum_comp2) AS sum_comp3
INTO #muacpf2
FROM #muacpf
GROUP BY mukey, cokey, sum_comp2

---Gets the Weighted component percent. Example from "Column F" up top 
SELECT mukey, cokey,  CASE WHEN sum_comp2 = sum_comp3 THEN 1 
ELSE CAST (CAST (sum_comp2 AS  decimal (5,2)) / CAST (sum_comp3 AS decimal (5,2)) AS decimal (5,2)) END AS WEIGHTED_COMP_PCT 
INTO #muacpf3
FROM #muacpf2





---grab top depth for the mineral soil and will use it later to get mineral surface properties

SELECT compname, cokey, MIN(hzdept_r) AS min_t
INTO #hortopdepth
FROM #acpf
WHERE texture NOT LIKE '%PM%' and texture NOT LIKE '%DOM' and texture NOT LIKE '%MPT%' AND texture NOT LIKE '%MUCK' AND texture NOT LIKE '%PEAT%'
GROUP BY compname, cokey

---combine the mineral surface to grab surface mineral properties

SELECT #hortopdepth.cokey,
hzname,
hzdept_r,
hzdepb_r,
thickness,
texture AS texture_surf,
om_r AS om_surf,
dbthirdbar_r AS db_surf, 
fragvol AS frag_surf, 
chkey
INTO #acpf2
FROM #hortopdepth
INNER JOIN #acpf on #hortopdepth.cokey=#acpf.cokey AND #hortopdepth.min_t = #acpf.hzdept_r
ORDER BY #hortopdepth.cokey, hzname




SELECT
mukey,
cokey,
hzname,
restrictiodepth, 
hzdept_r,
hzdepb_r,
CASE WHEN (hzdepb_r-hzdept_r) IS NULL THEN 0 ELSE CAST ((hzdepb_r-hzdept_r) AS INT) END AS thickness,
texture,
CASE WHEN dbthirdbar_r IS NULL THEN 0 ELSE dbthirdbar_r  END AS dbthirdbar_r, 
CASE WHEN fragvol IS NULL THEN 0 ELSE fragvol  END AS fragvol, 
CASE when om_r IS NULL THEN 0 ELSE om_r END AS om_r,
chkey
INTO #acpfhzn
FROM #acpf


--- depth ranges for SOC ----
SELECT hzname, chkey, comppct_r, hzdept_r, hzdepb_r, thickness,
CASE  WHEN hzdept_r < 150 then hzdept_r ELSE 0 END AS InRangeTop_0_150, 
CASE  WHEN hzdepb_r <= 150 THEN hzdepb_r WHEN hzdepb_r > 150 and hzdept_r < 150 THEN 150 ELSE 0 END AS InRangeBot_0_150,


CASE  WHEN hzdept_r < 30 then hzdept_r ELSE 0 END AS InRangeTop_0_30, 
CASE  WHEN hzdepb_r <= 30  THEN hzdepb_r WHEN hzdepb_r > 30  and hzdept_r < 30 THEN 30  ELSE 0 END AS InRangeBot_0_30,



CASE    WHEN hzdepb_r < 20 THEN 0
WHEN hzdept_r >50 THEN 0 
WHEN hzdepb_r >= 20 AND hzdept_r < 20 THEN 20 
WHEN hzdept_r < 20 THEN 0
		WHEN hzdept_r < 50 then hzdept_r ELSE 20 END AS InRangeTop_20_50 ,
		
	
CASE   WHEN hzdept_r > 50 THEN 0
WHEN hzdepb_r < 20 THEN 0
WHEN hzdepb_r <= 50 THEN hzdepb_r  WHEN hzdepb_r > 50 and hzdept_r < 50 THEN 50 ELSE 20 END AS InRangeBot_20_50,



CASE    WHEN hzdepb_r < 50 THEN 0
WHEN hzdept_r >100 THEN 0 
WHEN hzdepb_r >= 50 AND hzdept_r < 50 THEN 50 
WHEN hzdept_r < 50 THEN 0
		WHEN hzdept_r < 100 then hzdept_r ELSE 50 END AS InRangeTop_50_100 ,
		
	
CASE   WHEN hzdept_r > 100 THEN 0
WHEN hzdepb_r < 50 THEN 0
WHEN hzdepb_r <= 100 THEN hzdepb_r  WHEN hzdepb_r > 100 and hzdept_r < 100 THEN 100 ELSE 50 END AS InRangeBot_50_100,
--CASE    WHEN hzdept_r < 50 THEN 50
--		WHEN hzdept_r < 100 then hzdept_r ELSE 50 END AS InRangeTop_50_100,
		
--CASE    WHEN hzdepb_r < 50 THEN 50
--WHEN hzdepb_r <= 100 THEN hzdepb_r  WHEN hzdepb_r > 100 and hzdept_r < 100 THEN 100 ELSE 50 END AS InRangeBot_50_100,

om_r, fragvol, dbthirdbar_r, cokey, mukey, 100.0 - fragvol AS frag_main
INTO #SOC
FROM #acpf
ORDER BY cokey, hzdept_r ASC, hzdepb_r ASC, chkey


SELECT mukey, cokey, hzname, chkey, comppct_r, hzdept_r, hzdepb_r, thickness,
InRangeTop_0_150, 
InRangeBot_0_150, 
 
InRangeTop_0_30, 
InRangeBot_0_30, 

InRangeTop_20_50, 
InRangeBot_20_50, 

InRangeTop_50_100 ,
InRangeBot_50_100,
(( ((InRangeBot_0_150 - InRangeTop_0_150) * ( ( om_r / 1.724 ) * dbthirdbar_r )) / 100.0 ) * ((100.0 - fragvol) / 100.0))  AS HZ_SOC_0_150,

(( ((InRangeBot_0_30 - InRangeTop_0_30) * ( ( om_r / 1.724 ) * dbthirdbar_r )) / 100.0 ) * ((100.0 - fragvol) / 100.0))  AS HZ_SOC_0_30,
---Removed * ( comppct_r * 100 ) 
((((InRangeBot_20_50 - InRangeTop_20_50) * ( ( om_r / 1.724 ) * dbthirdbar_r )) / 100.0 ) * ((100.0 - fragvol) / 100.0))  AS HZ_SOC_20_50,
---Removed * ( comppct_r * 100 ) 
((((InRangeBot_50_100 - InRangeTop_50_100) * ( ( om_r / 1.724 ) * dbthirdbar_r )) / 100.0 ) * ((100.0 - fragvol) / 100.0))  AS HZ_SOC_50_100
---Removed * ( comppct_r * 100 ) 
INTO #SOC2
FROM #SOC
ORDER BY  mukey ,cokey, comppct_r DESC, hzdept_r ASC, hzdepb_r ASC, chkey

---Aggregates and sum it by component. 
SELECT DISTINCT cokey, mukey,  
ROUND (SUM (HZ_SOC_0_150) over(PARTITION BY cokey) ,4) AS CO_SOC_0_150, 
ROUND (SUM (HZ_SOC_0_30) over(PARTITION BY cokey) ,4) AS CO_SOC_0_30, 
ROUND (SUM (HZ_SOC_20_50) over(PARTITION BY cokey),4) AS CO_SOC_20_50, 
ROUND (SUM (HZ_SOC_50_100) over(PARTITION BY cokey),4)  AS CO_SOC_50_100 
INTO #SOC3
FROM #SOC2

SELECT DISTINCT #SOC3.cokey, #SOC3.mukey,  WEIGHTED_COMP_PCT, 
CO_SOC_0_30, CO_SOC_0_30 * WEIGHTED_COMP_PCT AS WEIGHTED_CO_SOC_0_30,
CO_SOC_20_50, CO_SOC_20_50 * WEIGHTED_COMP_PCT AS WEIGHTED_CO_SOC_20_50,
CO_SOC_50_100, CO_SOC_50_100 * WEIGHTED_COMP_PCT AS WEIGHTED_CO_SOC_50_100,
CO_SOC_0_150, CO_SOC_0_150 * WEIGHTED_COMP_PCT AS WEIGHTED_CO_SOC_0_150,
INTO #SOC4
FROM #SOC3
INNER JOIN #muacpf3 ON #muacpf3.cokey=#SOC3.cokey

--Unit Conversion *100
SELECT DISTINCT #main.mukey, ROUND (SUM (WEIGHTED_CO_SOC_0_30) over(PARTITION BY #SOC4.mukey) ,4) *100  AS SOCSTOCK_0_30 , 
ROUND (SUM (WEIGHTED_CO_SOC_20_50) over(PARTITION BY #SOC4.mukey) ,4) *100  AS SOCSTOCK_20_50 , 
ROUND (SUM (WEIGHTED_CO_SOC_50_100) over(PARTITION BY #SOC4.mukey) ,4) *100  AS SOCSTOCK_50_100,

ROUND (SUM (WEIGHTED_CO_SOC_0_150) over(PARTITION BY #SOC4.mukey) ,4) *100  AS SOCSTOCK_0_150
FROM #SOC4
RIGHT OUTER JOIN #main ON #main.mukey=#SOC4.mukey


