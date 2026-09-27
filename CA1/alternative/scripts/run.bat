@echo off
rem Runs the Bookstore application from the development deployment directory.
rem Usage: run.bat [--server.port=8085] [other Spring Boot arguments]
setlocal
set DIR=%~dp0..
set JAR=
for %%f in ("%DIR%\bookstore-*.jar") do set JAR=%%f

if "%JAR%"=="" (
    echo No application jar found in %DIR% >&2
    exit /b 1
)

java -cp "%JAR%;%DIR%\lib\*" com.example.bookstore.BookstoreApplication %*
