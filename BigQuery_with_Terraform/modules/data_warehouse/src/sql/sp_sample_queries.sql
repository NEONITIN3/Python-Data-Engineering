-- Copyright 2023 Google LLC
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

/*
Use Cases:
    - BigQuery supports full SQL syntax and many analytic functions that make complex queries of lots of data easy

Description:
    - Show joins, date functions, rank, partition, pivot

Reference:
    - Rank/Partition: https://cloud.google.com/bigquery/docs/reference/standard-sql/analytic-function-concepts
    - Pivot: https://cloud.google.com/bigquery/docs/reference/standard-sql/query-syntax#pivot_operator

Clean up / Reset script:
    n/a
*/

--Rank, Pivot, Json

-- Query: Get trips over $50 for each day of the week.
-- Shows: Date Functions, Joins, Group By, Having, Ordinal Group/Having
SELECT FORMAT_DATE("%w", Pickup_DateTime) AS WeekdayNumber,
       FORMAT_DATE("%A", Pickup_DateTime) AS WeekdayName,
       vendor.Vendor_Description,
       payment_type.Payment_Type_Description,
       SUM(taxi_trips.Total_Amount) AS high_value_trips
  FROM `${project_id}.ds_edw.taxi_trips` AS taxi_trips
       INNER JOIN `${project_id}.ds_edw.vendor` AS vendor
               ON cast(taxi_trips.Vendor_Id as INT64) = vendor.Vendor_Id
              AND taxi_trips.Pickup_DateTime BETWEEN '2022-01-01' AND '2022-02-01'
        LEFT JOIN `${project_id}.ds_edw.payment_type` AS payment_type
               ON cast(taxi_trips.payment_type as INT64) = payment_type.Payment_Type_Id
GROUP BY 1, 2, 3, 4
HAVING SUM(taxi_trips.Total_Amount) > 50
ORDER BY WeekdayNumber, 3, 4;


-- Query: amounts (Cash/Credit) by passenger type
WITH TaxiDataRanking AS
(
SELECT CAST(Pickup_DateTime AS DATE) AS Pickup_Date,
       cast(taxi_trips.payment_type as INT64) as Payment_Type_Id,
       taxi_trips.Passenger_Count,
       taxi_trips.Total_Amount,
       RANK() OVER (PARTITION BY CAST(Pickup_DateTime AS DATE),
                                 taxi_trips.payment_type
                        ORDER BY taxi_trips.Passenger_Count DESC,
                                 taxi_trips.Total_Amount DESC) AS Ranking
  FROM `${project_id}.ds_edw.taxi_trips` AS taxi_trips
 WHERE taxi_trips.Pickup_DateTime BETWEEN '2022-01-01' AND '2022-02-01'
   AND cast(taxi_trips.payment_type as INT64) IN (1,2)
)
SELECT Pickup_Date,
       Payment_Type_Description,
       Passenger_Count,
       Total_Amount
  FROM TaxiDataRanking
       INNER JOIN `${project_id}.ds_edw.payment_type` AS payment_type
               ON TaxiDataRanking.Payment_Type_Id = payment_type.Payment_Type_Id
WHERE Ranking = 1
ORDER BY Pickup_Date, Payment_Type_Description;


-- Query: data summed by payment type and passenger count, then pivoted based upon payment type
WITH MonthlyData AS
(
SELECT FORMAT_DATE("%B", taxi_trips.Pickup_DateTime) AS MonthName,
       FORMAT_DATE("%m", taxi_trips.Pickup_DateTime) AS MonthNumber,
       CASE WHEN cast(taxi_trips.payment_type as INT64) = 1 THEN 'Credit'
            WHEN cast(taxi_trips.payment_type as INT64) = 2 THEN 'Cash'
            WHEN cast(taxi_trips.payment_type as INT64) = 3 THEN 'NoCharge'
            WHEN cast(taxi_trips.payment_type as INT64) = 4 THEN 'Dispute'
         END AS PaymentDescription,
       taxi_trips.Passenger_Count,
       taxi_trips.Total_Amount
  FROM `${project_id}.ds_edw.taxi_trips` AS taxi_trips
 WHERE taxi_trips.Pickup_DateTime BETWEEN '2022-01-01' AND '2022-02-01'
   AND Passenger_Count IS NOT NULL
   AND cast(payment_type as INT64) IN (1,2,3,4)
)
SELECT MonthName,
       Passenger_Count,
       FORMAT("%'d", CAST(Credit   AS INTEGER)) AS Credit,
       FORMAT("%'d", CAST(Cash     AS INTEGER)) AS Cash,
       FORMAT("%'d", CAST(NoCharge AS INTEGER)) AS NoCharge,
       FORMAT("%'d", CAST(Dispute  AS INTEGER)) AS Dispute
  FROM MonthlyData
 PIVOT(SUM(Total_Amount) FOR PaymentDescription IN ('Credit', 'Cash', 'NoCharge', 'Dispute'))
ORDER BY MonthNumber, Passenger_Count;


-- Query: data pivoted by payment type
WITH MonthlyData AS
(
SELECT FORMAT_DATE("%B", taxi_trips.Pickup_DateTime) AS MonthName,
       FORMAT_DATE("%m", taxi_trips.Pickup_DateTime) AS MonthNumber,
       CASE WHEN cast(taxi_trips.payment_type as INT64) = 1 THEN 'Credit'
            WHEN cast(taxi_trips.payment_type as INT64) = 2 THEN 'Cash'
            WHEN cast(taxi_trips.payment_type as INT64) = 3 THEN 'NoCharge'
            WHEN cast(taxi_trips.payment_type as INT64) = 4 THEN 'Dispute'
         END AS PaymentDescription,
       SUM(taxi_trips.Total_Amount) AS Total_Amount
  FROM `${project_id}.ds_edw.taxi_trips` AS taxi_trips
 WHERE taxi_trips.Pickup_DateTime BETWEEN '2022-01-01' AND '2022-02-01'
   AND Passenger_Count IS NOT NULL
   AND cast(taxi_trips.payment_type as INT64) IN (1,2,3,4)
 GROUP BY 1, 2, 3
)
SELECT MonthName,
       FORMAT("%'d", CAST(Credit   AS INTEGER)) AS Credit,
       FORMAT("%'d", CAST(Cash     AS INTEGER)) AS Cash,
       FORMAT("%'d", CAST(NoCharge AS INTEGER)) AS NoCharge,
       FORMAT("%'d", CAST(Dispute  AS INTEGER)) AS Dispute
  FROM MonthlyData
 PIVOT(SUM(Total_Amount) FOR PaymentDescription IN ('Credit', 'Cash', 'NoCharge', 'Dispute'))
ORDER BY MonthNumber;


-- Query: See what day of the week in each month has the greatest amount (that's the month/day to work)
WITH WeekdayData AS
(
SELECT FORMAT_DATE("%B", Pickup_DateTime) AS MonthName,
       FORMAT_DATE("%m", Pickup_DateTime) AS MonthNumber,
       FORMAT_DATE("%A", Pickup_DateTime) AS WeekdayName,
       SUM(taxi_trips.Total_Amount) AS Total_Amount
  FROM `${project_id}.ds_edw.taxi_trips` AS taxi_trips
 WHERE taxi_trips.Pickup_DateTime BETWEEN '2022-01-01' AND '2022-02-01'
   AND cast(taxi_trips.payment_type as INT64) IN (1,2,3,4)
 GROUP BY 1, 2, 3
)
SELECT MonthName,
       FORMAT("%'d", CAST(Sunday    AS INTEGER)) AS Sunday,
       FORMAT("%'d", CAST(Monday    AS INTEGER)) AS Monday,
       FORMAT("%'d", CAST(Tuesday   AS INTEGER)) AS Tuesday,
       FORMAT("%'d", CAST(Wednesday AS INTEGER)) AS Wednesday,
       FORMAT("%'d", CAST(Thursday  AS INTEGER)) AS Thursday,
       FORMAT("%'d", CAST(Friday    AS INTEGER)) AS Friday,
       FORMAT("%'d", CAST(Saturday  AS INTEGER)) AS Saturday,
  FROM WeekdayData
 PIVOT(SUM(Total_Amount) FOR WeekdayName IN ('Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'))
ORDER BY MonthNumber;
