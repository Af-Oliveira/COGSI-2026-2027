@echo off
rem Runs the Bookstore application from the development deployment directory.
rem Usage: run.bat [--server.port=8085] [other Spring Boot arguments]
setlocal
set DIR=%~dp0..
for %%f in ("%DIR%\bookstore-*.jar") do set JAR=%%f
java -jar "%JAR%" %*
