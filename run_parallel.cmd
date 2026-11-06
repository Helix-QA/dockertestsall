@echo off
chcp 65001 > nul
echo [1/3] Очистка и создание папок для логов...
if exist "build" rmdir /s /q "build"
mkdir "build\test1\allure"
mkdir "build\test2\allure"

echo [2/3] Сборка образа 1С 8.5.1.1529...
docker compose build va-test-1

echo [3/3] Параллельный запуск 2 тестов...
docker compose up

echo.
echo === Лог выполнения Test 1 (va-execution.log) ===
if exist "build\test1\va-execution.log" (
    type "build\test1\va-execution.log"
) else (
    echo Файл build\test1\va-execution.log не создан!
)
echo.
pause