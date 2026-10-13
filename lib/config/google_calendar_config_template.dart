/// Configuration Google Calendar API (TEMPLATE — à versionner)
///
/// Important: copier ce fichier en `google_calendar_config.dart` (ignoré par
/// git) et y mettre les vraies valeurs. Le même compte de service que Google
/// Sheets suffit — Google Calendar est activé sur le même projet.
class GoogleCalendarConfig {
  /// Credentials du compte de service Google Calendar API
  static const credentials = r'''
{
  "type": "service_account",
  "project_id": "to-be-defined",
  "private_key_id": "to-be-defined",
  "private_key": "to-be-defined",
  "client_email": "to-be-defined",
  "client_id": "to-be-defined",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "to-be-defined",
  "universe_domain": "googleapis.com"
}
''';

  /// ID du calendrier partagé à lire (email du calendrier ou "primary")
  static const calendarId = 'to-be-defined';

  /// Propriété privée qui porte la catégorie dans extendedProperties.private
  static const categoryKey = 'categorie';
}
