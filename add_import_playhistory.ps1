$file = 'c:\appdefinitiva\apps\frontend\lib\core\providers\auth_provider.dart'
$lines = Get-Content $file

# Encontrar la línea donde está offline_manager_provider y agregar play_history_provider después
$newLines = @()
for ($i = 0; $i -lt $lines.Length; $i++) {
    $newLines += $lines[$i]
    
    if ($lines[$i] -match "import 'offline_manager_provider\.dart'") {
        $newLines += "import 'play_history_provider.dart'; // PlayHistory"
    }
}

Set-Content $file -Value $newLines
Write-Host "Import de play_history_provider agregado"
