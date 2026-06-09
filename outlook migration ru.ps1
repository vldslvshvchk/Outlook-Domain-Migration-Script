# =====================================================
# Скрипт для смены почтового домена olddomain.com на newdomain.com
# Меняет и визуальное название, и внутренние Account Name / Email
# Работает на Outlook 2010–2019 (включая 2016)
# =====================================================

$oldDomain = "@olddomain.com"
$newDomain = "@newdomain.com"

Write-Host "=== СМЕНА ДОМЕНА OUTLOOK: $oldDomain → $newDomain ===" -ForegroundColor Cyan

# Закрываем Outlook
Get-Process -Name "OUTLOOK" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 3

function Fix-AccountSettings {
    param($RootPath)

    if (-not (Test-Path $RootPath)) { return }

    Write-Host "→ Внутренние настройки учётной записи: $RootPath" -ForegroundColor Yellow

    Get-ChildItem -Path $RootPath -Recurse -ErrorAction SilentlyContinue | ForEach-Object {

        $keyPath = $_.PSPath
        $props = Get-ItemProperty -Path $keyPath -ErrorAction SilentlyContinue

        $accountProps = @("Account Name", "Email", "001f6620", "001e6620")

        foreach ($propName in $accountProps) {

            $value = $props.$propName

            # === СТРОКОВЫЙ формат ===
            if ($value -is [string] -and
                $value -like "*$oldDomain*" -and
                $value -match "@" -and
                $value -notlike "*.pst*") {

                $newValue = $value -replace [regex]::Escape($oldDomain), $newDomain

                Set-ItemProperty `
                    -Path $keyPath `
                    -Name $propName `
                    -Value $newValue `
                    -Force

                Write-Host "   [STR] $($_.PSChildName)\$propName → $newValue" -ForegroundColor Green
            }

            # === БИНАРНЫЙ формат ===
            elseif ($value -is [byte[]]) {

                try {

                    $str = [System.Text.Encoding]::Unicode.GetString($value).Trim("`0")

                    if ($str -like "*$oldDomain*" -and
                        $str -match "@" -and
                        $str -notlike "*.pst*") {

                        $newStr = $str -replace [regex]::Escape($oldDomain), $newDomain
                        $newBin = [System.Text.Encoding]::Unicode.GetBytes($newStr + "`0")

                        Set-ItemProperty `
                            -Path $keyPath `
                            -Name $propName `
                            -Value $newBin `
                            -Force

                        Write-Host "   [BIN] $($_.PSChildName)\$propName → $newStr" -ForegroundColor Green
                    }
                }
                catch {}
            }
        }
    }
}

function Fix-DisplayName {
    param($RootPath)

    if (-not (Test-Path $RootPath)) { return }

    Write-Host "→ Визуальное название (001f3001): $RootPath" -ForegroundColor Yellow

    Get-ChildItem -Path $RootPath -Recurse -ErrorAction SilentlyContinue | ForEach-Object {

        $props = Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue

        if ($props."001f3001" -is [byte[]]) {

            try {

                $str = [System.Text.Encoding]::Unicode.GetString($props."001f3001").Trim("`0")

                if ($str -like "*$oldDomain*" -and
                    $str -match "@" -and
                    $str -notlike "*.pst*") {

                    $newStr = $str -replace [regex]::Escape($oldDomain), $newDomain
                    $newBin = [System.Text.Encoding]::Unicode.GetBytes($newStr + "`0")

                    Set-ItemProperty `
                        -Path $_.PSPath `
                        -Name "001f3001" `
                        -Value $newBin `
                        -Force

                    Write-Host "   [DISPLAY] $($_.PSChildName) → $newStr" -ForegroundColor Green
                }
            }
            catch {}
        }
    }
}

# Проверяем права администратора
$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)

if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Скрипт необходимо запускать от имени администратора." -ForegroundColor Red
    exit 1
}

# Пути ко всем профилям
$profiles = Get-ChildItem `
    "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"

# Запускаем
foreach ($profile in $profiles) {

    $sid = $profile.PSChildName

    if ($sid -notmatch "^S-1-5-21-") {
        continue
    }

    $profilePath = [Environment]::ExpandEnvironmentVariables(
        $profile.GetValue("ProfileImagePath")
    )

    if (-not $profilePath) {
        continue
    }

    Write-Host ""
    Write-Host "=== Обработка профиля $sid ===" -ForegroundColor Cyan

    $hiveLoadedByScript = $false

    try {

        if (-not (Test-Path "Registry::HKEY_USERS\$sid")) {

            $ntUserDat = Join-Path $profilePath "NTUSER.DAT"

            if (Test-Path $ntUserDat) {

                Write-Host "Подключение профиля: $ntUserDat" -ForegroundColor DarkYellow

                reg load "HKU\$sid" "$ntUserDat" | Out-Null

                if ($LASTEXITCODE -eq 0) {
                    $hiveLoadedByScript = $true
                    Start-Sleep -Seconds 1
                }
                else {
                    Write-Warning "Не удалось подключить профиль $sid"
                    continue
                }
            }
            else {
                continue
            }
        }

        $profilePaths = @(
            "Registry::HKEY_USERS\$sid\Software\Microsoft\Windows NT\CurrentVersion\Windows Messaging Subsystem\Profiles",
            "Registry::HKEY_USERS\$sid\Software\Microsoft\Office\14.0\Outlook\Profiles",
            "Registry::HKEY_USERS\$sid\Software\Microsoft\Office\15.0\Outlook\Profiles",
            "Registry::HKEY_USERS\$sid\Software\Microsoft\Office\16.0\Outlook\Profiles"
        )

        foreach ($path in $profilePaths) {
            Fix-AccountSettings -RootPath $path
            Fix-DisplayName -RootPath $path
        }
    }
    finally {

        if ($hiveLoadedByScript) {

            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()

            Start-Sleep -Seconds 2

            reg unload "HKU\$sid" | Out-Null
        }
    }
}

Write-Host "`nГОТОВО! Скрипт завершён." -ForegroundColor Green
Write-Host "Проверьте в Outlook → Параметры учётных записей → Изменить." -ForegroundColor White