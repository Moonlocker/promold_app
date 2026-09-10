/// Configuração de ambiente do aplicativo.
///
/// O aplicativo reutiliza exatamente o mesmo projeto Supabase do sistema web
/// Promold (mesma URL, mesma chave pública/anon). Nunca coloque aqui a
/// service_role key: ela não pode ser distribuída em um app.
///
/// Os valores podem ser sobrescritos em build com:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...
class Env {
  Env._();

  static const String appName = 'ProMold';

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://kdtfjrdgnebncizjgymw.supabase.co',
  );

  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtkdGZqcmRnbmVibmNpempneW13Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk4MjI1NzEsImV4cCI6MjA4NTM5ODU3MX0.3DFHAc7GS95guzVHcQ_887ctMMencfDcBWqmfm0beqI',
  );
}
