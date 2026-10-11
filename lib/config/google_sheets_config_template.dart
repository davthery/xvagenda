/// Configuration Google Sheets API
///
/// IMPORTANT: À personnaliser avec vos propres credentials
/// Pour la production, utiliser des variables d'environnement ou un gestionnaire de secrets
class GoogleSheetsConfig {
  /// Credentials du compte de service Google Sheets API
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

  /// ID de la Google Sheet contenant les événements
  static const spreadsheetId = '1bx6UsUSK332jkwnGWHUW9ox9hb3vVppa6m1ITGzhBW8';

  /// Nom de la feuille (worksheet) contenant les événements
  static const worksheetTitle = 'Planning';
}
