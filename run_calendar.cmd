@echo off
echo create db3:
sqlite3.exe test.db3 -init calendar.sql .exit
echo.
echo export to file: 
sqlite3.exe test.db3 -init export_calendar.sql .exit
echo.
pause
