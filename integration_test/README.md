# Testes de integração (backend + UI)

Estes testes rodam **em um dispositivo/emulador** (Android/iOS), pois exercitam
o app real e o backend Supabase compartilhado com o webapp.

## Pré-requisitos
- Um dispositivo/emulador conectado: `flutter devices`.
- (Para os testes de backend) um usuário de teste no Supabase, idealmente de uma
  organização de teste. Os testes são **somente leitura**.

## Como executar

Via script (recomendado):

```powershell
# Usando variáveis de ambiente TEST_EMAIL / TEST_PASSWORD
$env:TEST_EMAIL    = "usuario@exemplo.com"
$env:TEST_PASSWORD = "senha"
./run-integration-tests.ps1 -Device emulator-5554
```

Ou diretamente:

```powershell
flutter test integration_test -d emulator-5554 `
  --dart-define=TEST_EMAIL=usuario@exemplo.com `
  --dart-define=TEST_PASSWORD=senha
```

Sem credenciais, os testes de backend são marcados como **skipped** e apenas o
smoke test de UI executa (não falha a suíte).

## Arquivos
- `app_smoke_test.dart` — sobe o `PromoldApp` e valida que o MaterialApp/Router
  monta sem exceções (não exige credenciais).
- `backend_test.dart` — autentica, chama a RPC `user_paginas_visiveis` e faz
  leituras somente-leitura dos repositórios principais (obras, clientes, contas
  a pagar, lotes de qualidade, configurações, dashboard).

## Alvos / overrides
O alvo Supabase é o mesmo do app (`core/config/env.dart`) e pode ser
sobrescrito em execução:

```powershell
./run-integration-tests.ps1 -SupabaseUrl https://SEU.supabase.co -SupabaseKey SUA_ANON_KEY
```

> Nunca use a `service_role` key no app. A chave usada é a pública (anon).

## Não é um teste unitário
Para os testes rápidos de lógica (rodam no host, sem dispositivo), use:

```powershell
flutter test
```
