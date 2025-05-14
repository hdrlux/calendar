-- file: export_calendar.sql
-- sqlite3.exe test.db3 -init export_calendar.sql .exit
.headers on
.mode column

.output test_calendar.txt
SELECT calendar.*, work_days.workday, fiscal_years.fiscal_year, month_NL.month_long, month_NL.month_short, weekday_NL.day_long, weekday_NL.day_short 
	FROM calendar 
	INNER JOIN month_NL ON calendar.month = month_NL.month
	INNER JOIN weekday_NL ON calendar.ISOdayofweek = weekday_NL.ISOdayofweek
	INNER JOIN work_days ON calendar.d = work_days.d
	INNER JOIN fiscal_years ON calendar.d = fiscal_years.d
	ORDER BY d;

.output test_holidays.txt
SELECT weekday_NL.day_long, holidays.* 
	FROM holidays 
	INNER JOIN calendar ON holidays.d = calendar.d 
	LEFT JOIN weekday_NL ON calendar.ISOdayofweek = weekday_NL.ISOdayofweek 
	ORDER BY holidays.d, holidays.country;

.output test_periods.txt
SELECT * FROM periods
	ORDER BY d, period;