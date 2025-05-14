-- file: calendar.sql
-- sqlite3.exe test.db3 -init calendar.sql .exit

/*** create calendar and name tables ***/
DROP TABLE IF EXISTS calendar;
CREATE TABLE IF NOT EXISTS calendar (
  d date UNIQUE NOT NULL,
  ISOdayofweek TEXT NOT NULL,
  year TEXT NOT NULL,
  month TEXT NOT NULL,
  day TEXT NOT NULL,
  quarter TEXT NOT NULL,
  ISOweek TEXT NOT NULL,
  ISOyear TEXT NOT NULL,
  julianday_local2utc TEXT NOT NULL,
  date_as_int INT NOT NULL,
  US_date TEXT NOT NULL,
  weekday INT NOT NULL,
  daynumber INT NOT NULL,
  PRIMARY KEY (d)
);
INSERT
  OR IGNORE INTO calendar 
SELECT *
FROM (
  WITH RECURSIVE dates(d) AS (
    VALUES(strftime('%F', 'now', 'start of year', '-5 years')) --minimal 1 year past history
    UNION ALL
    SELECT date(d, '+1 day')
    FROM dates
    WHERE d < strftime('%F', 'now', '+1 years', 'start of year', '-1 days', '+5 years') --minimal 1 year future planning
  )
  SELECT d,
	strftime('%u', d) AS ISOdayofweek,
  strftime('%Y', d) AS year,
  strftime('%m', d) AS month,
  strftime('%d', d) AS day,
	(strftime('%m', d) - 1) / 3 + 1 AS quarter,
	strftime('%V', d) AS ISOweek,
	strftime('%g', d) AS ISOyear,
	julianday(d, 'utc') AS julianday_local2utc, -- not correct in local time
	strftime('%Y%m%d',d) AS date_as_int,
	CONCAT(CAST(strftime('%m', d) AS INT),'/',CAST(strftime('%d', d) AS INT),'/',substr(strftime('%Y', d),3, 2)) AS US_date,
	CASE
      WHEN CAST(strftime('%u', d) AS INT) BETWEEN 1 AND 5 THEN 1
      ELSE 0
    END AS weekday,
	strftime('%j', d) AS daynumber
  FROM dates
);

CREATE TABLE IF NOT EXISTS month_NL (
   month TEXT UNIQUE NOT NULL,
   month_long TEXT NOT NULL,
   month_short TEXT NOT NULL,
   PRIMARY KEY (month));
INSERT OR IGNORE INTO month_NL VALUES 
   ('01', 'januari', 'jan'),
   ('02', 'februari', 'feb'),
   ('03', 'maart', 'mrt'),
   ('04', 'april', 'apr'),
   ('05', 'mei', 'mei'),
   ('06', 'juni', 'jun'),
   ('07', 'juli', 'jul'),
   ('08', 'augustus', 'aug'),
   ('09', 'september', 'sep'),
   ('10', 'oktober', 'okt'),
   ('11', 'november', 'nov'),
   ('12', 'december', 'dec');
   
CREATE TABLE IF NOT EXISTS weekday_NL (
   ISOdayofweek TEXT UNIQUE NOT NULL,
   day_long TEXT NOT NULL,
   day_short TEXT NOT NULL,
   PRIMARY KEY (ISOdayofweek));
INSERT OR IGNORE INTO weekday_NL VALUES 
   (1, 'maandag', 'ma'),
   (2, 'dinsdag', 'di'),
   (3, 'woensdag', 'wo'),
   (4, 'donderdag', 'do'),
   (5, 'vrijdag', 'vr'),
   (6, 'zaterdag', 'za'),
   (7, 'zondag', 'zo');
   
CREATE TABLE IF NOT EXISTS month_US (
   month TEXT UNIQUE NOT NULL,
   month_long TEXT NOT NULL,
   month_short TEXT NOT NULL,
   PRIMARY KEY (month));
INSERT OR IGNORE INTO month_US VALUES 
   ('01', 'January', 'Jan'),
   ('02', 'February', 'Feb'),
   ('03', 'March', 'Mar'),
   ('04', 'April', 'Apr'),
   ('05', 'May', 'May'),
   ('06', 'June', 'Jun'),
   ('07', 'July', 'Jul'),
   ('08', 'August', 'Aug'),
   ('09', 'September', 'Sep'),
   ('10', 'October', 'Oct'),
   ('11', 'November', 'Nov'),
   ('12', 'December ', 'Dec');
   
CREATE TABLE IF NOT EXISTS weekday_US (
   ISOdayofweek TEXT UNIQUE NOT NULL,
   day_long TEXT NOT NULL,
   day_short TEXT NOT NULL,
   PRIMARY KEY (ISOdayofweek));
INSERT OR IGNORE INTO weekday_US VALUES 
   (1, 'Monday', 'Mon'),
   (2, 'Tuesday', 'Tue'),
   (3, 'Wednesday', 'Wed'),
   (4, 'Thursday', 'Thu'),
   (5, 'Friday', 'Fri'),
   (6, 'Saturday', 'Sat'),
   (7, 'Sunday', 'Sun');
   
/*** calculate regulated holidays for calendar dates ***/
DROP TABLE IF EXISTS holidays;
CREATE TABLE IF NOT EXISTS holidays (
/* types:
   public holiday
   replacement holiday
   national celebration
   special day */
   d date,
   country TEXT,
   type TEXT,
   holiday TEXT,
   description TEXT
   );

DROP TABLE IF EXISTS computus_paschalis;
CREATE TEMP TABLE IF NOT EXISTS computus_paschalis (
-- valid for years 1900..2099, Gregorian calendar
   year INT,
   n INT GENERATED ALWAYS AS (year - 1900),
   a INT GENERATED ALWAYS AS (mod(n, 19)),
   b INT GENERATED ALWAYS AS ((7 * a + 1) / 19),
   m INT GENERATED ALWAYS AS (mod((11*a+4-b), 29)),
   q INT GENERATED ALWAYS AS (n / 4),
   w INT GENERATED ALWAYS AS (mod((n+q+31-m), 7)),
   Easter INT GENERATED ALWAYS AS (25-m-w),
   mnd TEXT GENERATED ALWAYS AS (CASE WHEN Easter < 1 THEN '03' ELSE '04' END),
   dy TEXT GENERATED ALWAYS AS (printf('%02d',(CASE WHEN Easter < 1 THEN Easter + 31 ELSE Easter END))),
   EasterSunday date GENERATED ALWAYS AS (CASE
      WHEN year < 1900 THEN NULL
	  WHEN year > 2099 THEN NULL
      ELSE CONCAT(year,'-',mnd,'-',dy)
   END),
   type TEXT GENERATED ALWAYS AS ('public holiday'),
   country TEXT GENERATED ALWAYS AS ('NL'),
   holiday TEXT GENERATED ALWAYS AS ('pasen'),
   description TEXT GENERATED ALWAYS AS ('easter (gregorian)')
   );
INSERT
  OR IGNORE INTO computus_paschalis
SELECT DISTINCT year FROM calendar;
INSERT
  OR IGNORE INTO holidays
SELECT EasterSunday, country, type, holiday, description FROM computus_paschalis;

DROP TABLE IF EXISTS carnaval_t;
CREATE TEMP TABLE IF NOT EXISTS carnaval_t (
   EasterSunday date,
   carnaval date GENERATED ALWAYS AS (date(EasterSunday, '-49 days')),
   type TEXT GENERATED ALWAYS AS ('national celebration'),
   country TEXT GENERATED ALWAYS AS ('NL'),
   holiday TEXT GENERATED ALWAYS AS ('carnaval'),
   description TEXT GENERATED ALWAYS AS ('7 weeks before easter')
   );
INSERT
  OR IGNORE INTO carnaval_t
SELECT EasterSunday FROM computus_paschalis;
INSERT
  OR IGNORE INTO holidays
SELECT carnaval, country, type, holiday, description FROM carnaval_t;

DROP TABLE IF EXISTS mardi_gras_t;
CREATE TEMP TABLE IF NOT EXISTS mardi_gras_t (
   EasterSunday date,
   mardi_gras date GENERATED ALWAYS AS (date(EasterSunday, '-47 days')),
   type TEXT GENERATED ALWAYS AS ('national celebration'),
   country TEXT GENERATED ALWAYS AS ('US'),
   holiday TEXT GENERATED ALWAYS AS ('Mardi Gras'),
   description TEXT GENERATED ALWAYS AS ('Shrove Tuesday, carnaval ends')
   );
INSERT
  OR IGNORE INTO mardi_gras_t
SELECT EasterSunday FROM computus_paschalis;
INSERT
  OR IGNORE INTO holidays
SELECT mardi_gras, country, type, holiday, description FROM mardi_gras_t;

DROP TABLE IF EXISTS hemelvaart_t;
CREATE TEMP TABLE IF NOT EXISTS hemelvaart_t (
   EasterSunday date,
   hemelvaart date GENERATED ALWAYS AS (date(EasterSunday, '+39 days')),
   type TEXT GENERATED ALWAYS AS ('public holiday'),
   country TEXT GENERATED ALWAYS AS ('NL'),
   holiday TEXT GENERATED ALWAYS AS ('hemelvaart'),
   description TEXT GENERATED ALWAYS AS ('ascension day, 39 days after easter ')
   );
INSERT
  OR IGNORE INTO hemelvaart_t
SELECT EasterSunday FROM computus_paschalis;
INSERT
  OR IGNORE INTO holidays
SELECT hemelvaart, country, type, holiday, description FROM hemelvaart_t;

DROP TABLE IF EXISTS goede_vrijdag_t;
CREATE TEMP TABLE IF NOT EXISTS goede_vrijdag_t (
   EasterSunday date,
   goede_vrijdag date GENERATED ALWAYS AS (date(EasterSunday, '-2 days')),
   type TEXT GENERATED ALWAYS AS ('public holiday'),
   country TEXT GENERATED ALWAYS AS ('NL'),
   holiday TEXT GENERATED ALWAYS AS ('goede vrijdag'),
   description TEXT GENERATED ALWAYS AS ('2 days before easter')
   );
INSERT
  OR IGNORE INTO goede_vrijdag_t
SELECT EasterSunday FROM computus_paschalis;
INSERT
  OR IGNORE INTO holidays
SELECT goede_vrijdag, country, type, holiday, description FROM goede_vrijdag_t;

DROP TABLE IF EXISTS tweede_paasdag_t;
CREATE TEMP TABLE IF NOT EXISTS tweede_paasdag_t (
   EasterSunday date,
   tweede_paasdag date GENERATED ALWAYS AS (date(EasterSunday, '+1 days')),
   type TEXT GENERATED ALWAYS AS ('public holiday'),
   country TEXT GENERATED ALWAYS AS ('NL'),
   holiday TEXT GENERATED ALWAYS AS ('2e paasdag'),
   description TEXT GENERATED ALWAYS AS ('day after easter')
   );
INSERT
  OR IGNORE INTO tweede_paasdag_t
SELECT EasterSunday FROM computus_paschalis;
INSERT
  OR IGNORE INTO holidays
SELECT tweede_paasdag, country, type, holiday, description FROM tweede_paasdag_t;

DROP TABLE IF EXISTS pinksteren_t;
CREATE TEMP TABLE IF NOT EXISTS pinksteren_t (
   EasterSunday date,
   pinksteren date GENERATED ALWAYS AS (date(EasterSunday, '+49 days')),
   type TEXT GENERATED ALWAYS AS ('public holiday'),
   country TEXT GENERATED ALWAYS AS ('NL'),
   holiday TEXT GENERATED ALWAYS AS ('pinksteren'),
   description TEXT GENERATED ALWAYS AS ('Pentecost, 7 weeks after easter')
   );
INSERT
  OR IGNORE INTO pinksteren_t
SELECT EasterSunday FROM computus_paschalis;
INSERT
  OR IGNORE INTO holidays
SELECT pinksteren, country, type, holiday, description FROM pinksteren_t;

DROP TABLE IF EXISTS tweede_pinksterdag_t;
CREATE TEMP TABLE IF NOT EXISTS tweede_pinksterdag_t (
   EasterSunday date,
   tweede_pinksterdag date GENERATED ALWAYS AS (date(EasterSunday, '+50 days')),
   type TEXT GENERATED ALWAYS AS ('public holiday'),
   country TEXT GENERATED ALWAYS AS ('NL'),
   holiday TEXT GENERATED ALWAYS AS ('2e pinksterdag'),
   description TEXT GENERATED ALWAYS AS ('day after Pentecost')
   );
INSERT
  OR IGNORE INTO tweede_pinksterdag_t
SELECT EasterSunday FROM computus_paschalis;
INSERT
  OR IGNORE INTO holidays
SELECT tweede_pinksterdag, country, type, holiday, description FROM tweede_pinksterdag_t;

DROP TABLE IF EXISTS nieuwjaar_t;
CREATE TEMP TABLE IF NOT EXISTS nieuwjaar_t (
   year INT,
   nieuwjaar date GENERATED ALWAYS AS (CONCAT(year,'-01-01')),
   type TEXT GENERATED ALWAYS AS ('public holiday'),
   country TEXT GENERATED ALWAYS AS ('NL'),
   holiday TEXT GENERATED ALWAYS AS ('nieuwsjaarsdag'),
   description TEXT GENERATED ALWAYS AS ('new year')
   );
INSERT
  OR IGNORE INTO nieuwjaar_t
SELECT DISTINCT year FROM calendar;
INSERT
  OR IGNORE INTO holidays
SELECT nieuwjaar, country, type, holiday, description FROM nieuwjaar_t;

DROP TABLE IF EXISTS koningsdag_t;
CREATE TEMP TABLE IF NOT EXISTS koningsdag_t (
-- 27-april from 2014
-- 30-april 1980-2013
-- NOT on Sunday > Saturday
   year INT,
   kon_temp date GENERATED ALWAYS AS (CASE
      WHEN year < 2014 THEN CONCAT(year,'-04-30')
      ELSE CONCAT(year,'-04-27')
   END),
   kon_zon date GENERATED ALWAYS AS (CASE
      WHEN strftime('%u', kon_temp) = '7' THEN strftime('%F', kon_temp, '-1 days')
      ELSE kon_temp
   END),
   koningsdag date GENERATED ALWAYS AS (CASE
      WHEN year < 1980 THEN NULL
      ELSE kon_zon
   END),
   type TEXT GENERATED ALWAYS AS ('public holiday'),
   country TEXT GENERATED ALWAYS AS ('NL'),
   holiday TEXT GENERATED ALWAYS AS (CASE
      WHEN year < 2014 THEN 'koninginnedag'
      ELSE 'koningsdag'
   END),
   description TEXT GENERATED ALWAYS AS ('kingsday, fixed but NOT on sunday')
   );
INSERT
  OR IGNORE INTO koningsdag_t
SELECT DISTINCT year FROM calendar;
INSERT
  OR IGNORE INTO holidays
SELECT koningsdag, country, type, holiday, description FROM koningsdag_t;

DROP TABLE IF EXISTS oktoberfest_t;
CREATE TEMP TABLE IF NOT EXISTS oktoberfest_t (
   year INT,
   oktoberfest date GENERATED ALWAYS AS (date(CONCAT(year,'-09-16'), 'weekday 6')),
   type TEXT GENERATED ALWAYS AS ('national celebration'),
   country TEXT GENERATED ALWAYS AS ('DE'),
   holiday TEXT GENERATED ALWAYS AS ('start oktoberfest'),
   description TEXT GENERATED ALWAYS AS ('ist das weltweit größte volksfest in München, Bayern. first saturday after 15-sep')
   );
INSERT
  OR IGNORE INTO oktoberfest_t
SELECT DISTINCT year FROM calendar;
INSERT
  OR IGNORE INTO holidays
SELECT oktoberfest, country, type, holiday, description FROM oktoberfest_t;

DROP TABLE IF EXISTS vijfmei_t;
CREATE TEMP TABLE IF NOT EXISTS vijfmei_t (
-- special day every 5 year lustrum
   year INT,
   vijfmei date GENERATED ALWAYS AS (date(CONCAT(year,'-05-05'))),
   type TEXT GENERATED ALWAYS AS ('public holiday'),
   country TEXT GENERATED ALWAYS AS ('NL'),
   holiday TEXT GENERATED ALWAYS AS (CASE
      WHEN MOD(year,5) = 0 THEN 'bevrijdingsdag (lustrum)'
      ELSE 'bevrijdingsdag'
   END),
   description TEXT GENERATED ALWAYS AS ('liberation day, fixed 05-may')
   );
INSERT
  OR IGNORE INTO vijfmei_t
SELECT DISTINCT year FROM calendar;
INSERT
  OR IGNORE INTO holidays
SELECT vijfmei, country, type, holiday, description FROM vijfmei_t;

DROP TABLE IF EXISTS herdenking_t;
CREATE TEMP TABLE IF NOT EXISTS herdenking_t (
   year INT,
   herdenking date GENERATED ALWAYS AS (date(CONCAT(year,'-05-04'))),
   type TEXT GENERATED ALWAYS AS ('special day'),
   country TEXT GENERATED ALWAYS AS ('NL'),
   holiday TEXT GENERATED ALWAYS AS ('dodenherdenking'),
   description TEXT GENERATED ALWAYS AS ('remembrance of the dead, fixed 04-may')
   );
INSERT
  OR IGNORE INTO herdenking_t
SELECT DISTINCT year FROM calendar;
INSERT
  OR IGNORE INTO holidays
SELECT herdenking, country, type, holiday, description FROM herdenking_t;

DROP TABLE IF EXISTS kerst_t;
CREATE TEMP TABLE IF NOT EXISTS kerst_t (
   year INT,
   kerst date GENERATED ALWAYS AS (date(CONCAT(year,'-12-25'))),
   type TEXT GENERATED ALWAYS AS ('public holiday'),
   country TEXT GENERATED ALWAYS AS ('NL'),
   holiday TEXT GENERATED ALWAYS AS ('kerst'),
   description TEXT GENERATED ALWAYS AS ('X-mas, fixed 25-dec')
   );
INSERT
  OR IGNORE INTO kerst_t
SELECT DISTINCT year FROM calendar;
INSERT
  OR IGNORE INTO holidays
SELECT kerst, country, type, holiday, description FROM kerst_t;

DROP TABLE IF EXISTS tweede_kerst_t;
CREATE TEMP TABLE IF NOT EXISTS tweede_kerst_t (
   year INT,
   tweede_kerst date GENERATED ALWAYS AS (date(CONCAT(year,'-12-26'))),
   type TEXT GENERATED ALWAYS AS ('public holiday'),
   country TEXT GENERATED ALWAYS AS ('NL'),
   holiday TEXT GENERATED ALWAYS AS ('2e kerstdag'),
   description TEXT GENERATED ALWAYS AS ('day after X-mas')
   );
INSERT
  OR IGNORE INTO tweede_kerst_t
SELECT DISTINCT year FROM calendar;
INSERT
  OR IGNORE INTO holidays
SELECT tweede_kerst, country, type, holiday, description FROM tweede_kerst_t;

DROP TABLE IF EXISTS kerstavond_t;
CREATE TEMP TABLE IF NOT EXISTS kerstavond_t (
   year INT,
   kerstavond date GENERATED ALWAYS AS (date(CONCAT(year,'-12-24'))),
   type TEXT GENERATED ALWAYS AS ('national celebration'),
   country TEXT GENERATED ALWAYS AS ('NL'),
   holiday TEXT GENERATED ALWAYS AS ('kerstavond'),
   description TEXT GENERATED ALWAYS AS ('X-mas eve')
   );
INSERT
  OR IGNORE INTO kerstavond_t
SELECT DISTINCT year FROM calendar;
INSERT
  OR IGNORE INTO holidays
SELECT kerstavond, country, type, holiday, description FROM kerstavond_t;

DROP TABLE IF EXISTS kerstavond_t;
CREATE TEMP TABLE IF NOT EXISTS kerstavond_t (
   year INT,
   kerstavond date GENERATED ALWAYS AS (date(CONCAT(year,'-12-24'))),
   type TEXT GENERATED ALWAYS AS ('national celebration'),
   country TEXT GENERATED ALWAYS AS ('US'),
   holiday TEXT GENERATED ALWAYS AS ('Christmas Eve'),
   description TEXT GENERATED ALWAYS AS ('X-mas eve')
   );
INSERT
  OR IGNORE INTO kerstavond_t
SELECT DISTINCT year FROM calendar;
INSERT
  OR IGNORE INTO holidays
SELECT kerstavond, country, type, holiday, description FROM kerstavond_t;

DROP TABLE IF EXISTS moederdag_t;
CREATE TEMP TABLE IF NOT EXISTS moederdag_t (
   year INT,
   moederdag date GENERATED ALWAYS AS (date(CONCAT(year,'-05-08'), 'weekday 0')),
   type TEXT GENERATED ALWAYS AS ('national celebration'),
   country TEXT GENERATED ALWAYS AS ('NL'),
   holiday TEXT GENERATED ALWAYS AS ('moederdag'),
   description TEXT GENERATED ALWAYS AS ('second sunday may')
   );
INSERT
  OR IGNORE INTO moederdag_t
SELECT DISTINCT year FROM calendar;
INSERT
  OR IGNORE INTO holidays
SELECT moederdag, country, type, holiday, description FROM moederdag_t;

DROP TABLE IF EXISTS vaderdag_t;
CREATE TEMP TABLE IF NOT EXISTS vaderdag_t (
   year INT,
   vaderdag date GENERATED ALWAYS AS (date(CONCAT(year,'-06-15'), 'weekday 0')),
   type TEXT GENERATED ALWAYS AS ('national celebration'),
   country TEXT GENERATED ALWAYS AS ('NL'),
   holiday TEXT GENERATED ALWAYS AS ('vaderdag'),
   description TEXT GENERATED ALWAYS AS ('third sunday jun')
   );
INSERT
  OR IGNORE INTO vaderdag_t
SELECT DISTINCT year FROM calendar;
INSERT
  OR IGNORE INTO holidays
SELECT vaderdag, country, type, holiday, description FROM vaderdag_t;

DROP TABLE IF EXISTS oudjaar_t;
CREATE TEMP TABLE IF NOT EXISTS oudjaar_t (
   year INT,
   oudjaar date GENERATED ALWAYS AS (date(CONCAT(year,'-12-31'))),
   type TEXT GENERATED ALWAYS AS ('national celebration'),
   country TEXT GENERATED ALWAYS AS ('NL'),
   holiday TEXT GENERATED ALWAYS AS ('oudjaars avond'),
   description TEXT GENERATED ALWAYS AS ('evening before new year')
   );
INSERT
  OR IGNORE INTO oudjaar_t
SELECT DISTINCT year FROM calendar;
INSERT
  OR IGNORE INTO holidays
SELECT oudjaar, country, type, holiday, description FROM oudjaar_t;

DROP TABLE IF EXISTS oudjaar_t;
CREATE TEMP TABLE IF NOT EXISTS oudjaar_t (
   year INT,
   oudjaar date GENERATED ALWAYS AS (date(CONCAT(year,'-12-31'))),
   type TEXT GENERATED ALWAYS AS ('national celebration'),
   country TEXT GENERATED ALWAYS AS ('US'),
   holiday TEXT GENERATED ALWAYS AS ('New Year''s Eve'),
   description TEXT GENERATED ALWAYS AS ('evening before new year')
   );
INSERT
  OR IGNORE INTO oudjaar_t
SELECT DISTINCT year FROM calendar;
INSERT
  OR IGNORE INTO holidays
SELECT oudjaar, country, type, holiday, description FROM oudjaar_t;

DROP TABLE IF EXISTS zomertijd_t;
CREATE TEMP TABLE IF NOT EXISTS zomertijd_t (
--valid from year 1996
   year INT,
   zomertijd date GENERATED ALWAYS AS (CASE
      WHEN year < 1996 THEN NULL
      ELSE date(CONCAT(year,'-03-25'), 'weekday 0')
   END),
   type TEXT GENERATED ALWAYS AS ('special day'),
   country TEXT GENERATED ALWAYS AS ('NL'),
   holiday TEXT GENERATED ALWAYS AS ('zomertijd EU'),
   description TEXT GENERATED ALWAYS AS ('start DST, last sunday march')
   );
INSERT
  OR IGNORE INTO zomertijd_t
SELECT DISTINCT year FROM calendar;
INSERT
  OR IGNORE INTO holidays
SELECT zomertijd, country, type, holiday, description FROM zomertijd_t;

DROP TABLE IF EXISTS wintertijd_t;
CREATE TEMP TABLE IF NOT EXISTS wintertijd_t (
--valid from year 1996
   year INT,
   wintertijd date GENERATED ALWAYS AS (CASE
      WHEN year < 1996 THEN NULL
      ELSE date(CONCAT(year,'-10-25'), 'weekday 0')
   END),
   type TEXT GENERATED ALWAYS AS ('special day'),
   country TEXT GENERATED ALWAYS AS ('NL'),
   holiday TEXT GENERATED ALWAYS AS ('wintertijd EU'),
   description TEXT GENERATED ALWAYS AS ('end DST, last sunday october')
   );
INSERT
  OR IGNORE INTO wintertijd_t
SELECT DISTINCT year FROM calendar;
INSERT
  OR IGNORE INTO holidays
SELECT wintertijd, country, type, holiday, description FROM wintertijd_t;

DROP TABLE IF EXISTS ketikoti_t;
CREATE TEMP TABLE IF NOT EXISTS ketikoti_t (
   year INT,
   ketikoti date GENERATED ALWAYS AS (date(CONCAT(year,'-07-01'))),
   type TEXT GENERATED ALWAYS AS ('special day'),
   country TEXT GENERATED ALWAYS AS ('NL'),
   holiday TEXT GENERATED ALWAYS AS ('ketikoti'),
   description TEXT GENERATED ALWAYS AS ('freedom of the slaves, fixed 01-july')
   );
INSERT
  OR IGNORE INTO ketikoti_t
SELECT DISTINCT year FROM calendar;
INSERT
  OR IGNORE INTO holidays
SELECT ketikoti, country, type, holiday, description FROM ketikoti_t;

DROP TABLE IF EXISTS midzomer_t;
CREATE TEMP TABLE IF NOT EXISTS midzomer_t (
   year INT,
   midzomer date GENERATED ALWAYS AS (date(CONCAT(year,'-06-21'))),
   type TEXT GENERATED ALWAYS AS ('special day'),
   country TEXT GENERATED ALWAYS AS ('NL'),
   holiday TEXT GENERATED ALWAYS AS ('midzomer'),
   description TEXT GENERATED ALWAYS AS ('midsummer festivals, flexible around 21-june')
   );
INSERT
  OR IGNORE INTO midzomer_t
SELECT DISTINCT year FROM calendar;
INSERT
  OR IGNORE INTO holidays
SELECT midzomer, country, type, holiday, description FROM midzomer_t;

DROP TABLE IF EXISTS valentijn_t;
CREATE TEMP TABLE IF NOT EXISTS valentijn_t (
   year INT,
   valentijn date GENERATED ALWAYS AS (date(CONCAT(year,'-02-14'))),
   type TEXT GENERATED ALWAYS AS ('special day'),
   country TEXT GENERATED ALWAYS AS ('NL'),
   holiday TEXT GENERATED ALWAYS AS ('valentijn'),
   description TEXT GENERATED ALWAYS AS ('valentine''s day, fixed 14-feb')
   );
INSERT
  OR IGNORE INTO valentijn_t
SELECT DISTINCT year FROM calendar;
INSERT
  OR IGNORE INTO holidays
SELECT valentijn, country, type, holiday, description FROM valentijn_t;

DROP TABLE IF EXISTS sint_t;
CREATE TEMP TABLE IF NOT EXISTS sint_t (
   year INT,
   sint date GENERATED ALWAYS AS (date(CONCAT(year,'-12-05'))),
   type TEXT GENERATED ALWAYS AS ('special day'),
   country TEXT GENERATED ALWAYS AS ('NL'),
   holiday TEXT GENERATED ALWAYS AS ('sinterklaasavond'),
   description TEXT GENERATED ALWAYS AS ('dutch santa claus, flexible around 05-dec')
   );
INSERT
  OR IGNORE INTO sint_t
SELECT DISTINCT year FROM calendar;
INSERT
  OR IGNORE INTO holidays
SELECT sint, country, type, holiday, description FROM sint_t;

DROP TABLE IF EXISTS mlk_t;
CREATE TEMP TABLE IF NOT EXISTS mlk_t (
   year INT,
   mlk date GENERATED ALWAYS AS (date(CONCAT(year,'-01-15'), 'weekday 1')),
   type TEXT GENERATED ALWAYS AS ('public holiday'),
   country TEXT GENERATED ALWAYS AS ('US'),
   holiday TEXT GENERATED ALWAYS AS ('Martin Luther King Day'),
   description TEXT GENERATED ALWAYS AS ('third Monday of January')
   );
INSERT
  OR IGNORE INTO mlk_t
SELECT DISTINCT year FROM calendar;
INSERT
  OR IGNORE INTO holidays
SELECT mlk, country, type, holiday, description FROM mlk_t;

DROP TABLE IF EXISTS president_t;
CREATE TEMP TABLE IF NOT EXISTS president_t (
   year INT,
   president date GENERATED ALWAYS AS (date(CONCAT(year,'-02-15'), 'weekday 1')),
   type TEXT GENERATED ALWAYS AS ('public holiday'),
   country TEXT GENERATED ALWAYS AS ('US'),
   holiday TEXT GENERATED ALWAYS AS ('President''s Day'),
   description TEXT GENERATED ALWAYS AS ('third Monday of February')
   );
INSERT
  OR IGNORE INTO president_t
SELECT DISTINCT year FROM calendar;
INSERT
  OR IGNORE INTO holidays
SELECT president, country, type, holiday, description FROM president_t;

DROP TABLE IF EXISTS memorial_t;
CREATE TEMP TABLE IF NOT EXISTS memorial_t (
   year INT,
   memorial date GENERATED ALWAYS AS (date(CONCAT(year,'-05-25'), 'weekday 1')),
   type TEXT GENERATED ALWAYS AS ('public holiday'),
   country TEXT GENERATED ALWAYS AS ('US'),
   holiday TEXT GENERATED ALWAYS AS ('Memorial Day'),
   description TEXT GENERATED ALWAYS AS ('last Monday of May')
   );
INSERT
  OR IGNORE INTO memorial_t
SELECT DISTINCT year FROM calendar;
INSERT
  OR IGNORE INTO holidays
SELECT memorial, country, type, holiday, description FROM memorial_t;

DROP TABLE IF EXISTS juneteenth_t;
CREATE TEMP TABLE IF NOT EXISTS juneteenth_t (
   year INT,
   juneteenth date GENERATED ALWAYS AS (date(CONCAT(year,'-06-19'))),
   type TEXT GENERATED ALWAYS AS ('public holiday'),
   country TEXT GENERATED ALWAYS AS ('US'),
   holiday TEXT GENERATED ALWAYS AS ('Juneteenth'),
   description TEXT GENERATED ALWAYS AS ('fixed June 19')
   );
INSERT
  OR IGNORE INTO juneteenth_t
SELECT DISTINCT year FROM calendar;
INSERT
  OR IGNORE INTO holidays
SELECT juneteenth, country, type, holiday, description FROM juneteenth_t;

DROP TABLE IF EXISTS juneteenth_rep_t;
CREATE TEMP TABLE IF NOT EXISTS juneteenth_rep_t (
   juneteenth date,
   weekend INT GENERATED ALWAYS AS (strftime('%u', juneteenth)),
   juneteenth_rep date GENERATED ALWAYS AS (CASE
      WHEN weekend = 6 THEN date(juneteenth, '-1 days')
      WHEN weekend = 7 THEN date(juneteenth, '+1 days')
      ELSE NULL
   END),
   type TEXT GENERATED ALWAYS AS ('replacement holiday'),
   country TEXT GENERATED ALWAYS AS ('US'),
   holiday TEXT GENERATED ALWAYS AS ('Juneteenth (observed)'),
   description TEXT GENERATED ALWAYS AS ('if in weekend')
   );
INSERT
  OR IGNORE INTO juneteenth_rep_t
SELECT juneteenth FROM juneteenth_t;
INSERT
  OR IGNORE INTO holidays
SELECT juneteenth_rep, country, type, holiday, description FROM juneteenth_rep_t;

DROP TABLE IF EXISTS indep_t;
CREATE TEMP TABLE IF NOT EXISTS indep_t (
   year INT,
   indep date GENERATED ALWAYS AS (date(CONCAT(year,'-07-04'))),
   type TEXT GENERATED ALWAYS AS ('public holiday'),
   country TEXT GENERATED ALWAYS AS ('US'),
   holiday TEXT GENERATED ALWAYS AS ('Independence Day'),
   description TEXT GENERATED ALWAYS AS ('fixed July 04')
   );
INSERT
  OR IGNORE INTO indep_t
SELECT DISTINCT year FROM calendar;
INSERT
  OR IGNORE INTO holidays
SELECT indep, country, type, holiday, description FROM indep_t;

DROP TABLE IF EXISTS indep_rep_t;
CREATE TEMP TABLE IF NOT EXISTS indep_rep_t (
   year INT,
   indep date GENERATED ALWAYS AS (date(CONCAT(year,'-07-04'))),
   weekend INT GENERATED ALWAYS AS (strftime('%u', indep)),
   indep_rep date GENERATED ALWAYS AS (CASE
      WHEN weekend = 6 THEN date(indep, '-1 days')
      WHEN weekend = 7 THEN date(indep, '+1 days')
      ELSE NULL
   END),
   type TEXT GENERATED ALWAYS AS ('replacement holiday'),
   country TEXT GENERATED ALWAYS AS ('US'),
   holiday TEXT GENERATED ALWAYS AS ('Independence Day (observed)'),
   description TEXT GENERATED ALWAYS AS ('if in weekend')
   );
INSERT
  OR IGNORE INTO indep_rep_t
SELECT DISTINCT year FROM calendar;
INSERT
  OR IGNORE INTO holidays
SELECT indep_rep, country, type, holiday, description FROM indep_rep_t;

DROP TABLE IF EXISTS xmas_t;
CREATE TEMP TABLE IF NOT EXISTS xmas_t (
   year INT,
   xmas date GENERATED ALWAYS AS (date(CONCAT(year,'-12-25'))),
   type TEXT GENERATED ALWAYS AS ('public holiday'),
   country TEXT GENERATED ALWAYS AS ('US'),
   holiday TEXT GENERATED ALWAYS AS ('Christmas Day'),
   description TEXT GENERATED ALWAYS AS ('X-mas, fixed 25-dec')
   );
INSERT
  OR IGNORE INTO xmas_t
SELECT DISTINCT year FROM calendar;
INSERT
  OR IGNORE INTO holidays
SELECT xmas, country, type, holiday, description FROM xmas_t;

DROP TABLE IF EXISTS xmas_rep_t;
CREATE TEMP TABLE IF NOT EXISTS xmas_rep_t (
   year INT,
   xmas date GENERATED ALWAYS AS (date(CONCAT(year,'-12-25'))),
   weekend INT GENERATED ALWAYS AS (strftime('%u', xmas)),
   xmas_rep date GENERATED ALWAYS AS (CASE
      WHEN weekend = 6 THEN date(xmas, '-1 days')
      WHEN weekend = 7 THEN date(xmas, '+1 days')
      ELSE NULL
   END),
   type TEXT GENERATED ALWAYS AS ('replacement holiday'),
   country TEXT GENERATED ALWAYS AS ('US'),
   holiday TEXT GENERATED ALWAYS AS ('Christmas Day (observed)'),
   description TEXT GENERATED ALWAYS AS ('if in weekend')
   );
INSERT
  OR IGNORE INTO xmas_rep_t
SELECT DISTINCT year FROM calendar;
INSERT
  OR IGNORE INTO holidays
SELECT xmas_rep, country, type, holiday, description FROM xmas_rep_t;

DROP TABLE IF EXISTS new_years;
CREATE TEMP TABLE IF NOT EXISTS new_years (
   year INT,
   newyear date GENERATED ALWAYS AS (CONCAT(year,'-01-01')),
   type TEXT GENERATED ALWAYS AS ('public holiday'),
   country TEXT GENERATED ALWAYS AS ('US'),
   holiday TEXT GENERATED ALWAYS AS ('New Year''s Day'),
   description TEXT GENERATED ALWAYS AS ('new year')
   );
INSERT
  OR IGNORE INTO new_years
SELECT DISTINCT year FROM calendar;
INSERT
  OR IGNORE INTO holidays
SELECT newyear, country, type, holiday, description FROM new_years;

DROP TABLE IF EXISTS new_year_rep_t;
CREATE TEMP TABLE IF NOT EXISTS new_year_rep_t (
-- needs INNER join, can be out of year range
   year INT,
   newyear date GENERATED ALWAYS AS (CONCAT(year,'-01-01')),
   weekend INT GENERATED ALWAYS AS (strftime('%u', newyear)),
   new_year_rep date GENERATED ALWAYS AS (CASE
      WHEN weekend = 6 THEN date(newyear, '-1 days')
      WHEN weekend = 7 THEN date(newyear, '+1 days')
      ELSE NULL
   END),
   type TEXT GENERATED ALWAYS AS ('replacement holiday'),
   country TEXT GENERATED ALWAYS AS ('US'),
   holiday TEXT GENERATED ALWAYS AS ('New Year''s Day (observed)'),
   description TEXT GENERATED ALWAYS AS ('if in weekend')
   );
INSERT
  OR IGNORE INTO new_year_rep_t
SELECT DISTINCT year FROM calendar;
INSERT
  OR IGNORE INTO new_year_rep_t
SELECT MAX (year + 1) FROM calendar;
INSERT
  OR IGNORE INTO holidays
SELECT new_year_rep, country, type, holiday, description FROM new_year_rep_t;

DROP TABLE IF EXISTS labor_t;
CREATE TEMP TABLE IF NOT EXISTS labor_t (
   year INT,
   labor date GENERATED ALWAYS AS (date(CONCAT(year,'-09-01'), 'weekday 1')),
   type TEXT GENERATED ALWAYS AS ('public holiday'),
   country TEXT GENERATED ALWAYS AS ('US'),
   holiday TEXT GENERATED ALWAYS AS ('Labor Day'),
   description TEXT GENERATED ALWAYS AS ('first Monday of Sep')
   );
INSERT
  OR IGNORE INTO labor_t
SELECT DISTINCT year FROM calendar;
INSERT
  OR IGNORE INTO holidays
SELECT labor, country, type, holiday, description FROM labor_t;

DROP TABLE IF EXISTS columbus_t;
CREATE TEMP TABLE IF NOT EXISTS columbus_t (
   year INT,
   columbus date GENERATED ALWAYS AS (date(CONCAT(year,'-10-08'), 'weekday 1')),
   type TEXT GENERATED ALWAYS AS ('public holiday'),
   country TEXT GENERATED ALWAYS AS ('US'),
   holiday TEXT GENERATED ALWAYS AS ('Columbus Day'),
   description TEXT GENERATED ALWAYS AS ('second Monday of Okt')
   );
INSERT
  OR IGNORE INTO columbus_t
SELECT DISTINCT year FROM calendar;
INSERT
  OR IGNORE INTO holidays
SELECT columbus, country, type, holiday, description FROM columbus_t;

DROP TABLE IF EXISTS veterans_t;
CREATE TEMP TABLE IF NOT EXISTS veterans_t (
   year INT,
   veterans date GENERATED ALWAYS AS (CONCAT(year,'-11-11')),
   type TEXT GENERATED ALWAYS AS ('public holiday'),
   country TEXT GENERATED ALWAYS AS ('US'),
   holiday TEXT GENERATED ALWAYS AS ('Veterans Day'),
   description TEXT GENERATED ALWAYS AS ('fixed 11-nov')
   );
INSERT
  OR IGNORE INTO veterans_t
SELECT DISTINCT year FROM calendar;
INSERT
  OR IGNORE INTO holidays
SELECT veterans, country, type, holiday, description FROM veterans_t;

DROP TABLE IF EXISTS veterans_rep_t;
CREATE TEMP TABLE IF NOT EXISTS veterans_rep_t (
-- needs INNER join, can be out of year range
   year INT,
   veterans date GENERATED ALWAYS AS (CONCAT(year,'-11-11')),
   weekend INT GENERATED ALWAYS AS (strftime('%u', veterans)),
   veterans_rep date GENERATED ALWAYS AS (CASE
      WHEN weekend = 6 THEN date(veterans, '-1 days')
      WHEN weekend = 7 THEN date(veterans, '+1 days')
      ELSE NULL
   END),
   type TEXT GENERATED ALWAYS AS ('replacement holiday'),
   country TEXT GENERATED ALWAYS AS ('US'),
   holiday TEXT GENERATED ALWAYS AS ('Veterans Day (observed)'),
   description TEXT GENERATED ALWAYS AS ('if in weekend')
   );
INSERT
  OR IGNORE INTO veterans_rep_t
SELECT DISTINCT year FROM calendar;
INSERT
  OR IGNORE INTO new_year_rep_t
SELECT MAX (year + 1) FROM calendar;
INSERT
  OR IGNORE INTO holidays
SELECT veterans_rep, country, type, holiday, description FROM veterans_rep_t;

DROP TABLE IF EXISTS thanksgiving_t;
CREATE TEMP TABLE IF NOT EXISTS thanksgiving_t (
   year INT,
   thanksgiving date GENERATED ALWAYS AS (date(CONCAT(year,'-11-22'), 'weekday 4')),
   type TEXT GENERATED ALWAYS AS ('public holiday'),
   country TEXT GENERATED ALWAYS AS ('US'),
   holiday TEXT GENERATED ALWAYS AS ('Thanksgiving Day'),
   description TEXT GENERATED ALWAYS AS ('fourth Thursday of Nov')
   );
INSERT
  OR IGNORE INTO thanksgiving_t
SELECT DISTINCT year FROM calendar;
INSERT
  OR IGNORE INTO holidays
SELECT thanksgiving, country, type, holiday, description FROM thanksgiving_t;

DROP TABLE IF EXISTS black_friday_t;
CREATE TEMP TABLE IF NOT EXISTS black_friday_t (
   year INT,
   black_friday date GENERATED ALWAYS AS (date(CONCAT(year,'-11-22'), 'weekday 4', '+1 days')),
   type TEXT GENERATED ALWAYS AS ('national celebration'),
   country TEXT GENERATED ALWAYS AS ('US'),
   holiday TEXT GENERATED ALWAYS AS ('black Friday'),
   description TEXT GENERATED ALWAYS AS ('day after Thanksgiving')
   );
INSERT
  OR IGNORE INTO black_friday_t
SELECT DISTINCT year FROM calendar;
INSERT
  OR IGNORE INTO holidays
SELECT black_friday, country, type, holiday, description FROM black_friday_t;

DROP TABLE IF EXISTS halloween_t;
CREATE TEMP TABLE IF NOT EXISTS halloween_t (
   year INT,
   halloween date GENERATED ALWAYS AS (CONCAT(year,'-10-31')),
   type TEXT GENERATED ALWAYS AS ('national celebration'),
   country TEXT GENERATED ALWAYS AS ('US'),
   holiday TEXT GENERATED ALWAYS AS ('Halloween'),
   description TEXT GENERATED ALWAYS AS ('fixed 31-okt')
   );
INSERT
  OR IGNORE INTO halloween_t
SELECT DISTINCT year FROM calendar;
INSERT
  OR IGNORE INTO holidays
SELECT halloween, country, type, holiday, description FROM halloween_t;

DROP TABLE IF EXISTS st_patrick_t;
CREATE TEMP TABLE IF NOT EXISTS st_patrick_t (
   year INT,
   st_patrick date GENERATED ALWAYS AS (CONCAT(year,'-03-17')),
   type TEXT GENERATED ALWAYS AS ('national celebration'),
   country TEXT GENERATED ALWAYS AS ('US'),
   holiday TEXT GENERATED ALWAYS AS ('Saint Patrick''s Day'),
   description TEXT GENERATED ALWAYS AS ('fixed 17-mar')
   );
INSERT
  OR IGNORE INTO st_patrick_t
SELECT DISTINCT year FROM calendar;
INSERT
  OR IGNORE INTO holidays
SELECT st_patrick, country, type, holiday, description FROM st_patrick_t;

/*** remove invalid NULL holidays ***/
DELETE FROM holidays WHERE d IS NULL;

/*** workdays without selected holidays ***/
DROP TABLE IF EXISTS leave_days;
CREATE TEMP TABLE IF NOT EXISTS leave_days (
/* use your application holidays: 
   select holidays with leave  */ 
   ld date,
   country TEXT,
   type TEXT,
   holiday TEXT,
   leave INT GENERATED ALWAYS AS (1) 
   );
INSERT
  OR IGNORE INTO leave_days
SELECT *
FROM ( 
  SELECT d AS ld, country, type, holiday
  FROM holidays
  WHERE country = 'NL' AND type = 'public holiday' AND holiday NOT IN ('goede vrijdag', 'bevrijdingsdag')
);

DROP TABLE IF EXISTS work_days;
CREATE TABLE IF NOT EXISTS work_days (
/* use your application leave days: 
   calculate workday on weekdays  */
   d date,
   weekday INT,
   leave date,
   workday INT GENERATED ALWAYS AS (CASE
     WHEN leave = 1 THEN 0
     ELSE weekday
   END) 
   );
INSERT
  OR IGNORE INTO work_days
SELECT d, weekday, leave
FROM ( 
  SELECT d, weekday, leave
  FROM calendar
  LEFT JOIN leave_days ON calendar.d = leave_days.ld   
) ORDER BY d;

/*** calculate fiscal periods ***/
DROP TABLE IF EXISTS fiscal_years;
CREATE TABLE IF NOT EXISTS fiscal_years (
   d date,
   year TEXT,
   month TEXT,
   fiscal_year TEXT GENERATED ALWAYS AS (CONCAT('FY',SUBSTR(CAST(CASE
   /* use your application periods: 
   start 01-oct  */
     WHEN month < 10 THEN year
     ELSE year + 1
   END AS TEXT),3,2)))
   );
INSERT
  OR IGNORE INTO fiscal_years
SELECT 
  d,
  year,
  month
FROM 
  calendar;

/*** calculate date periods, only USEFULL with daily refresh !! ***/
DROP TABLE IF EXISTS periods;
CREATE TABLE IF NOT EXISTS periods (
   d date,
   period TEXT);

DROP TABLE IF EXISTS offsets_t;
CREATE TEMP TABLE IF NOT EXISTS offsets_t (
   d date,
   ISOdayofweek TEXT,
   year TEXT,
   month TEXT,
   quarter TEXT,
   today date,
   day_offset INT GENERATED ALWAYS AS (julianday(d) - julianday(today)),
   isoweek_offset INT GENERATED ALWAYS AS ((day_offset - ISOdayofweek + strftime('%u', today)) / 7),
   year_offset INT GENERATED ALWAYS AS (year - strftime('%Y', today)),
   month_offset INT GENERATED ALWAYS AS (12 * year_offset + month - strftime('%m', today)),
   quarter_offset INT GENERATED ALWAYS AS (4 * year_offset + quarter - ((strftime('%m', today) - 1) / 3 + 1))
   );
INSERT
  OR IGNORE INTO offsets_t
SELECT 
  d,
  ISOdayofweek,
  year TEXT,
  month TEXT,
  quarter,
  current_date AS today
FROM 
  calendar;

DROP TABLE IF EXISTS this_day_t;
CREATE TEMP TABLE IF NOT EXISTS this_day_t (
   d date,
   description TEXT GENERATED ALWAYS AS ('this day')
   );
INSERT
  OR IGNORE INTO this_day_t
SELECT d FROM offsets_t
   WHERE day_offset = 0;
INSERT
  OR IGNORE INTO periods
SELECT d, description FROM this_day_t;

DROP TABLE IF EXISTS this_ISOweek_t;
CREATE TEMP TABLE IF NOT EXISTS this_ISOweek_t (
   d date,
   description TEXT GENERATED ALWAYS AS ('this_ISOweek')
   );
INSERT
  OR IGNORE INTO this_ISOweek_t
SELECT d FROM offsets_t
   WHERE isoweek_offset = 0;
INSERT
  OR IGNORE INTO periods
SELECT d, description FROM this_ISOweek_t;

DROP TABLE IF EXISTS this_month_t;
CREATE TEMP TABLE IF NOT EXISTS this_month_t (
   d date,
   description TEXT GENERATED ALWAYS AS ('this_month')
   );
INSERT
  OR IGNORE INTO this_month_t
SELECT d FROM offsets_t
   WHERE month_offset = 0;
INSERT
  OR IGNORE INTO periods
SELECT d, description FROM this_month_t;

DROP TABLE IF EXISTS this_quarter_t;
CREATE TEMP TABLE IF NOT EXISTS this_quarter_t (
   d date,
   description TEXT GENERATED ALWAYS AS ('this_quarter')
   );
INSERT
  OR IGNORE INTO this_quarter_t
SELECT d FROM offsets_t
   WHERE quarter_offset = 0;
INSERT
  OR IGNORE INTO periods
SELECT d, description FROM this_quarter_t;

DROP TABLE IF EXISTS this_year_t;
CREATE TEMP TABLE IF NOT EXISTS this_year_t (
   d date,
   description TEXT GENERATED ALWAYS AS ('this_year')
   );
INSERT
  OR IGNORE INTO this_year_t
SELECT d FROM offsets_t
   WHERE year_offset = 0;
INSERT
  OR IGNORE INTO periods
SELECT d, description FROM this_year_t;

DROP TABLE IF EXISTS last_10_days_t;
CREATE TEMP TABLE IF NOT EXISTS last_10_days_t (
   d date,
   description TEXT GENERATED ALWAYS AS ('last_10_days')
   );
INSERT
  OR IGNORE INTO last_10_days_t
SELECT d FROM offsets_t
   WHERE day_offset BETWEEN -10 AND -1; -- mind the order BETWEEN
INSERT
  OR IGNORE INTO periods
SELECT d, description FROM last_10_days_t;

DROP TABLE IF EXISTS next_10_days_t;
CREATE TEMP TABLE IF NOT EXISTS next_10_days_t (
   d date,
   description TEXT GENERATED ALWAYS AS ('next_10_days')
   );
INSERT
  OR IGNORE INTO next_10_days_t
SELECT d FROM offsets_t
   WHERE day_offset BETWEEN 1 AND 10; -- mind the order BETWEEN
INSERT
  OR IGNORE INTO periods
SELECT d, description FROM next_10_days_t;

/* use your application periods:
this 0
last -1, -4, -10, -12, -13 etc.
next +1, +4, +10, +12, +13 etc.
day, ISOweek, month, quarter, year
ytd, mtd*/