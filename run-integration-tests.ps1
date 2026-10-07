# =============================================================================
# Executa os testes de integração do app Promold em um dispositivo/emulador.
#
# Uso:
#   ./run-integration-tests.ps1                       # usa TEST_EMAIL/TEST_PASSWORD do ambiente
#   ./run-integration-tests.ps1 -Email a@b.com -Password 123456
#   ./run-integration-tests.ps1 -Device emulator-5554 # escolhe o dispositivo
#   ./run-integration-tests.ps1 -File integration_test/backend_test.dart
#   ./run-integration-tests.ps1 -SupabaseUrl https://... -SupabaseKey eyJ...
#
# Sem credenciais, os testes de backend são marcados como "skipped" e apenas o
# smoke test de UI roda. Requer um dispositivo conectado (`flutter devices`).
# =============================================================================
param(
  [string]$Device = "",
  [string]$Email = $env:TEST_EMAIL,
  [string]$Password = $env:TEST_PASSWORD,
  [string]$SupabaseUrl = "",
  [string]$SupabaseKey = "",
  [string]$File = ""
)

$ErrorActionPreference = "Stop"

if (-not $Email -or -not $Password) {
  Write-Host "Aviso: TEST_EMAIL/TEST_PASSWORD não informados. Testes de backend serão ignorados (skipped)." -ForegroundColor Yellow
}

$defines = @()
if ($Email) { $defines += "--dart-define=TEST_EMAIL=$Email" }
if ($Password) { $defines += "--dart-define=TEST_PASSWORD=$Password" }
if ($SupabaseUrl) { $defines += "--dart-define=SUPABASE_URL=$SupabaseUrl" }
if ($SupabaseKey) { $defines += "--dart-define=SUPABASE_PUBLISHABLE_KEY=$SupabaseKey" }

$target = if ($File) { $File } else { "integration_test" }

$args = @("test", $target)
if ($Device) { $args += @("-d", $Device) }
$args += $defines

Write-Host "Executando: flutter $($args -join ' ')" -ForegroundColor Cyan
& flutter @args

exit $LASTEXITCODE
