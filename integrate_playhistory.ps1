$file = 'c:\appdefinitiva\apps\frontend\lib\core\providers\auth_provider.dart'
$content = Get-Content $file -Raw

# Buscar el patrón donde se inicializa OfflineManager y agregar PlayHistory justo después
$patterns = @(
    # Patrón 1: En login
    @{
        Search = "(\s+await offlineManager\.initializeForUser\(authResponse\.user\.id\);\s+AppLogger\.info\('\[AuthProvider\][^\n]+OfflineManager inicializado[^\n]+'\);)"
        Replace = "`$1`n        final playHistory = ref.read(playHistoryProvider.notifier);`n        await playHistory.initializeForUser(authResponse.user.id);`n        AppLogger.info('[AuthProvider] PlayHistory inicializado para usuario: `${authResponse.user.id}');"
    },
    # Patrón 2: En _initialize (restaurar sesión)
    @{
        Search = "(\s+await offlineManager\.initializeForUser\(_authService\.currentUser!\.id\);\s+AppLogger\.info\('\[AuthProvider\][^\n]+OfflineManager inicializado para usuario restaurado[^\n]+'\);)"
        Replace = "`$1`n            final playHistory = ref.read(playHistoryProvider.notifier);`n            await playHistory.initializeForUser(_authService.currentUser!.id);`n            AppLogger.info('[AuthProvider] PlayHistory inicializado para usuario restaurado');"
    },
    # Patrón 3: En closeUserSession (cambiar OfflineManager por ambos)
    @{
        Search = "await offlineManager\.closeCurrentUserSession\(\);"
        Replace = "await offlineManager.closeCurrentUserSession();`n        final playHistory = ref.read(playHistoryProvider.notifier);`n        await playHistory.closeCurrentUserSession();"
    }
)

$modified = $content
foreach ($pattern in $patterns) {
    $modified = $modified -replace $pattern.Search, $pattern.Replace
}

Set-Content $file -Value $modified -NoNewline
Write-Host "PlayHistory integration agregada a AuthProvider"
