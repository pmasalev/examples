# PosrgreSQL

Задания выполнены в базе https://github.com/pmasalev/examples/blob/main/sql%20db.md

  
-- 1. Сколько суммарно каждый тип самолета провел в воздухе, если брать завершенные перелеты.

SELECT 
    f.aircraft_code,
    a.model,
    SUM(f.actual_arrival - f.actual_departure) AS total_flight_time
FROM 
    flights f
LEFT JOIN 
    aircrafts a ON f.aircraft_code = a.aircraft_code
WHERE 
    f.status = 'Arrived'
GROUP BY 
    f.aircraft_code, a.model;

-- 2. Сколько было получено посадочных талонов по каждой брони

SELECT 
    b.book_ref,
    COUNT(bp.boarding_no) AS boarding_pass_count
FROM 
    bookings b
JOIN 
    tickets t ON t.book_ref = b.book_ref
LEFT JOIN 
    boarding_passes bp ON t.ticket_no = bp.ticket_no
GROUP BY 
    b.book_ref;

-- 3. Вывести общую сумму продаж по каждому классу перелета

SELECT 
    tf.fare_conditions,
    SUM(tf.amount) AS total_sales
FROM 
    ticket_flights tf
GROUP BY 
    tf.fare_conditions;

-- 4. Найти маршрут с наибольшим финансовым оборотом

SELECT 
    r.departure_airport_name,
    r.arrival_airport_name,
    SUM(tf.amount) AS total_revenue
FROM 
    flights f
JOIN 
    ticket_flights tf ON f.flight_id = tf.flight_id
LEFT JOIN 
    routes r ON f.flight_no = r.flight_no
GROUP BY 
    r.departure_airport_name, r.arrival_airport_name
ORDER BY 
    total_revenue DESC
LIMIT 1;

-- 5. Найти наилучший и наихудший месяц по бронированию билетов (количество и сумма)

WITH w AS (
    SELECT 
        DATE_PART('year', book_date) AS yr,
        DATE_PART('month', book_date) AS mnth,
        COUNT(book_ref) AS bk_rf,
        SUM(total_amount) AS amnt
    FROM 
        bookings b
    GROUP BY 
        yr, mnth
),
d AS (
    SELECT 
        MAX(bk_rf) AS max_bk_rf,
        MAX(amnt) AS max_amnt,
        MIN(bk_rf) AS min_bk_rf,
        MIN(amnt) AS min_amnt
    FROM (
        SELECT 
            DATE_PART('year', book_date) AS yr,
            DATE_PART('month', book_date) AS mnth,
            COUNT(book_ref) AS bk_rf,
            SUM(total_amount) AS amnt
        FROM 
            bookings b
        GROUP BY 
            yr, mnth
    ) AS subquery
)
SELECT 
    w.yr,
    w.mnth,
    w.bk_rf,
    w.amnt,
    'наилучший' AS class
FROM 
    w
WHERE 
    w.bk_rf = (SELECT max_bk_rf FROM d) AND w.amnt = (SELECT max_amnt FROM d)
UNION
SELECT 
    w.yr,
    w.mnth,
    w.bk_rf,
    w.amnt,
    'наихудший' AS class
FROM 
    w
WHERE 
    w.bk_rf = (SELECT min_bk_rf FROM d) AND w.amnt = (SELECT min_amnt FROM d);

-- 6. Между какими городами пассажиры не делали пересадок?

WITH t1 AS (
    SELECT DISTINCT 
        t.depcity,
        t.arrcity2
    FROM (
        SELECT 
            t.passenger_id,
            a.city AS depcity,
            a2.city AS arrcity,
            f.actual_departure,
            f.actual_arrival,
            LEAD(a2.city) OVER (PARTITION BY t.passenger_id ORDER BY t.passenger_id) AS arrcity2,
            LEAD(f.actual_departure) OVER (PARTITION BY t.passenger_id ORDER BY t.passenger_id) AS actdep
        FROM 
            tickets t
        LEFT JOIN 
            ticket_flights tf ON t.ticket_no = tf.ticket_no
        LEFT JOIN 
            flights f ON tf.flight_id = f.flight_id
        LEFT JOIN 
            airports a ON f.departure_airport = a.airport_code
        LEFT JOIN 
            airports a2 ON f.arrival_airport = a2.airport_code
        ORDER BY 
            t.passenger_id
    ) t
    WHERE 
        t.arrcity2 IS NOT NULL AND (t.actdep - t.actual_arrival) < INTERVAL '24 hours' AND (t.arrcity2 != t.depcity)
),
x1 AS (
    SELECT DISTINCT 
        a.city AS c1,
        a2.city AS c2
    FROM 
        airports a
    CROSS JOIN 
        airports a2
    WHERE 
        a.city != a2.city
)
SELECT 
    x1.c1,
    x1.c2
FROM 
    x1
LEFT JOIN 
    t1 ON x1.c1 = t1.arrcity2 AND x1.c2 = t1.depcity
WHERE 
    t1.arrcity2 IS NULL AND t1.depcity IS NULL;

--7. Выведите название самолетов, которые имеют менее 50 посадочных мест?

select a.aircraft_code, a.model, count(s.seat_no) "num_seats"
from aircrafts a 
left join seats s on a.aircraft_code = s.aircraft_code 
group by a.aircraft_code
having count(s.seat_no) < 50


--8. Выведите процентное изменение ежемесячной суммы бронирования билетов, округленной до сотых. - не забыть что первый месяц NULL -- отрицательное изменения тоже корректно

select месяц, сумма,
round(((сумма - lag(сумма, 1, 0.) over (order by месяц))/lag(сумма, 1) over (order by месяц))*100,2)
from (
	select date_part('month', book_date) "месяц", sum(total_amount) "сумма"
	from bookings b 
	group by месяц
	order by месяц)
 
--9. Выведите названия самолетов не имеющих бизнес - класс. Решение должно быть через функцию array_agg.
	
select a.model
from(
	select s.aircraft_code, array_agg(s.fare_conditions)
	from seats s
	group by s.aircraft_code
	having array_position(array_agg(s.fare_conditions), 'Business') is null) s
left join aircrafts a on s.aircraft_code = a.aircraft_code
	
--10. Вывести накопительный итог количества мест в самолетах по каждому аэропорту на каждый день, учитывая только те самолеты, которые летали пустыми и только те дни, где из одного аэропорта таких самолетов вылетало более одного.

select  a.departure_airport "код аэрапорта", дата, a.count "кол-во пустых мест", a.sum "накопительный итог"
from(
	select дата, f.departure_airport, f.aircraft_code, s.count,
		   count(f.aircraft_code) over (partition by дата, f.departure_airport) count_of_boards,
		   sum(s.count) over (partition by дата, f.departure_airport)-- rows between unbounded preceding and current row)
	from (
		select date_trunc('day', f.actual_departure) "дата", f.departure_airport, f.aircraft_code
		from flights f
		left join boarding_passes b on f.flight_id = b.flight_id
		where b.boarding_no is null and (f.status = 'Departed' or f.status = 'Arrived')) f
	left join (select aircraft_code, count(seat_no)
			   from seats s 
			   group by aircraft_code) s on f.aircraft_code = s.aircraft_code) a
where count_of_boards > 1	


--11. Найдите процентное соотношение перелетов по маршрутам от общего количества перелетов.
 --Выведите в результат названия аэропортов и процентное отношение.

	select *, r.departure_airport_name, r.arrival_airport_name,
	round(sum(count(*)) over (partition by f.departure_airport||f.arrival_airport)/sum(count(*)) over ()*100,4) "процентное отношение"
	from flights f
	left join routes r on f.flight_no = r.flight_no 
	group by f.departure_airport, f.arrival_airport, r.departure_airport_name, r.arrival_airport_name
		
	
--12. Выведите количество пассажиров по каждому коду сотового оператора, если учесть, что код оператора - это три символа после +7
--сложный тип данных, выдернуть 3 символа после +7
	
select substring(contact_data ->> 'phone' from 3 for 3) "оператор", count(t.passenger_id) "количество пассажиров"
from tickets t
group by оператор
order by оператор

--13. Классифицируйте финансовые обороты (сумма стоимости перелетов) по маршрутам:
--До 50 млн -- low
--От 50 млн включительно до 150 млн - middle
--От 150 млн включительно - high --25 маршрутов
--Выведите в результат количество маршрутов в каждом полученном классе
 
select  классификатор, count(классификатор) "кол-во маршрутов"
from (
select case 
			when сумма >= 150000000 then 'high'
			when сумма between 50000000 and 150000000 then 'middle'
			else 'low'
		end  "классификатор"
from (
	select f.departure_airport, f.arrival_airport, sum(t.amount)"сумма"
	from flights f 
	join ticket_flights t on f.flight_id = t.flight_id 
	group by f.departure_airport,  f.arrival_airport) t
) f
group by классификатор

--14. Вычислите медиану стоимости перелетов(amount), медиану размера бронирования и отношение медианы бронирования к медиане стоимости перелетов, округленной до сотых

with c1 as (
select percentile_cont(0.5) within group (order by tf.amount) a1 --"Медиана стоимости перелётов"
from ticket_flights tf ), 
c2 as (
select percentile_cont(0.5) within group (order by b.total_amount) a2 --"Медиана стоимости бронирования"
from bookings b) 
select c1.a1 "Медиана стоимости перелётов", c2.a2 "Медиана стоимости бронирования" , round(((c2.a2/c1.a1))::numeric, 2) "отношение"
from c1, c2

--"странный" вариант
select t.med "Медиана стоимости перелётов", lead( t.med) over () "Медиана стоимости бронирования", round((lead(t.med) over()/t.med)::numeric, 2) "отношение"
from(
		select percentile_cont(0.5) within group (order by b.total_amount) med
		from bookings b
		union
		select percentile_cont(0.5) within group (order by tf.amount)
		from ticket_flights tf) t
limit 1

--15. Найдите значение минимальной стоимости полета 1 км для пассажиров. То есть нужно найти расстояние между аэропортами и с учетом стоимости перелетов получить искомый результат
  --Для поиска расстояния между двумя точками на поверхности Земли используется модуль earthdistance.
  --Для работы модуля earthdistance необходимо предварительно установить модуль cube.
  --Установка модулей происходит через команду: create extension название_модуля.
  --найти растройние меджду аэрапортами по сфере земли и посчитать стоимость 1 км

create extension cube
create extension earthdistance

select t.departure_airport, t.arrival_airport, distance ,min_amount,  round((t.min_amount/t.distance),2) as "Min стоимость 1 км"
	from (
	select t.departure_airport, t.longitude, t.latitude, t.arrival_airport, a.longitude, a.latitude, t.min_amount,
		   round((earth_distance (ll_to_earth (t.latitude, t.longitude), ll_to_earth (a.latitude, a.longitude))::numeric)/1000, 2) distance
	from (
		select t.departure_airport, a.longitude, a.latitude, t.arrival_airport, t.min_amount
		from (
			select f.departure_airport, f.arrival_airport, min(t.amount) min_amount
			from flights f 
			join ticket_flights t on f.flight_id = t.flight_id
			group by f.departure_airport,f.arrival_airport) t
		left join airports a on t.departure_airport = a.airport_code) t 
	left join airports a on t.arrival_airport = a.airport_code
	) t 
order by "Min стоимость 1 км"
limit 1




