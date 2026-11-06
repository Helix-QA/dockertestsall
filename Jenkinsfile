pipeline {
agent any

```
options {
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '20', artifactNumToKeepStr: '10'))
    timeout(time: 60, unit: 'MINUTES')
}

parameters {
    booleanParam(
        name: 'REBUILD_IMAGE',
        defaultValue: false,
        description: 'Принудительно пересобрать Docker-образ перед запуском тестов'
    )
}

environment {
    ONEC_IMAGE   = 'local/onec-vanessa:8.5.1.1529'
    WIN_HOSTNAME = 'DESKTOP-BIF25NH'
    CONTAINER_1  = "va-job-${env.BUILD_NUMBER}-1"
    CONTAINER_2  = "va-job-${env.BUILD_NUMBER}-2"
}

stages {
    stage('Подготовка окружения') {
        steps {
            bat '''
                @echo off
                chcp 65001 > nul
                echo [INFO] Очистка возможных зависших контейнеров...
                for /f "tokens=*" %%i in ('docker ps -aq --filter "name=va-job-"') do docker rm -f %%i > nul 2>&1

                echo [INFO] Пересоздание каталогов сборки...
                if exist "build" rmdir /s /q "build"
                for %%t in (test1 test2) do (
                    mkdir "build\\%%t\\allure"
                    mkdir "build\\%%t\\results"
                    mkdir "build\\%%t\\junit"
                    mkdir "build\\%%t\\out\\jUnint"
                    mkdir "build\\%%t\\out\\allure\\screenshots"
                )
            '''
        }
    }

    stage('Проверка / Сборка Docker-образа') {
        steps {
            script {
                if (params.REBUILD_IMAGE) {
                    bat '''
                        @echo off
                        chcp 65001 > nul
                        echo [INFO] Принудительная сборка образа %ONEC_IMAGE%...
                        docker build -t %ONEC_IMAGE% .
                    '''
                } else {
                    bat '''
                        @echo off
                        chcp 65001 > nul
                        docker image inspect %ONEC_IMAGE% > nul 2>&1
                        if %ERRORLEVEL% NEQ 0 (
                            echo [INFO] Образ %ONEC_IMAGE% не найден локально. Запускаем сборку...
                            docker build -t %ONEC_IMAGE% .
                        ) else (
                            echo [INFO] Образ %ONEC_IMAGE% уже существует, сборка пропущена.
                        )
                    '''
                }
            }
        }
    }

    stage('Параллельные тесты Vanessa Automation') {
        parallel {
            stage('Поток 1: Test 1') {
                steps {
                    catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
                        bat '''
                            @echo off
                            setlocal EnableDelayedExpansion
                            chcp 65001 > nul

                            docker run --rm --name %CONTAINER_1% ^
                                --add-host=%WIN_HOSTNAME%:host-gateway ^
                                -p 5901:5900 ^
                                -v "%WORKSPACE%\\config:/workspace/config:ro" ^
                                -v "%WORKSPACE%\\features\\test1:/workspace/features:ro" ^
                                -v "%WORKSPACE%\\build\\test1:/workspace/build" ^
                                -e DISPLAY=:99 ^
                                -e WEBKIT_DISABLE_COMPOSITING_MODE=1 ^
                                -e LIBGL_ALWAYS_SOFTWARE=1 ^
                                %ONEC_IMAGE% ^
                                vrunner vanessa --settings /workspace/config/vrunner.json
                            set DOCKER_EXIT=%ERRORLEVEL%

                            echo.
                            echo === Лог выполнения Потока 1 (va-execution.log) ===
                            if exist "build\\test1\\va-execution.log" (
                                type "build\\test1\\va-execution.log"
                            ) else (
                                echo [WARN] Файл build\\test1\\va-execution.log не создан!
                            )

                            if exist "build\\test1\\return_code.txt" (
                                set /p VA_RC=<"build\\test1\\return_code.txt"
                                set VA_RC=!VA_RC: =!
                                echo [INFO] Код возврата Vanessa Automation (Test 1): !VA_RC!
                                if "!VA_RC!" NEQ "0" exit /b !VA_RC!
                            )

                            exit /b !DOCKER_EXIT!
                        '''
                    }
                }
            }

            stage('Поток 2: Test 2') {
                steps {
                    catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
                        bat '''
                            @echo off
                            setlocal EnableDelayedExpansion
                            chcp 65001 > nul

                            docker run --rm --name %CONTAINER_2% ^
                                --add-host=%WIN_HOSTNAME%:host-gateway ^
                                -p 5902:5900 ^
                                -v "%WORKSPACE%\\config:/workspace/config:ro" ^
                                -v "%WORKSPACE%\\features\\test2:/workspace/features:ro" ^
                                -v "%WORKSPACE%\\build\\test2:/workspace/build" ^
                                -e DISPLAY=:98 ^
                                -e WEBKIT_DISABLE_COMPOSITING_MODE=1 ^
                                -e LIBGL_ALWAYS_SOFTWARE=1 ^
                                %ONEC_IMAGE% ^
                                vrunner vanessa --settings /workspace/config/vrunner.json
                            set DOCKER_EXIT=%ERRORLEVEL%

                            echo.
                            echo === Лог выполнения Потока 2 (va-execution.log) ===
                            if exist "build\\test2\\va-execution.log" (
                                type "build\\test2\\va-execution.log"
                            ) else (
                                echo [WARN] Файл build\\test2\\va-execution.log не создан!
                            )

                            if exist "build\\test2\\return_code.txt" (
                                set /p VA_RC=<"build\\test2\\return_code.txt"
                                set VA_RC=!VA_RC: =!
                                echo [INFO] Код возврата Vanessa Automation (Test 2): !VA_RC!
                                if "!VA_RC!" NEQ "0" exit /b !VA_RC!
                            )

                            exit /b !DOCKER_EXIT!
                        '''
                    }
                }
            }
        }
    }
}

post {
    always {
        bat '''
            @echo off
            chcp 65001 > nul
            docker rm -f %CONTAINER_1% %CONTAINER_2% > nul 2>&1
            exit /b 0
        '''

        archiveArtifacts(
            artifacts: 'build/**/*.log, build/**/return_code.txt',
            allowEmptyArchive: true
        )

        junit(
            testResults: 'build/**/junit/*.xml, build/**/out/jUnint/*.xml',
            allowEmptyResults: true
        )

        allure([
            includeProperties: false,
            jdk: '',
            properties: [],
            reportBuildPolicy: 'ALWAYS',
            results: [
                [path: 'build/test1/allure'],
                [path: 'build/test2/allure'],
                [path: 'build/test1/results'],
                [path: 'build/test2/results']
            ]
        ])
    }
}

```

}