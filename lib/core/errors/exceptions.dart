/// Adatréteg kivételei (Data layer exceptions)
abstract class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;
}

/// Távoli API / Supabase hiba
class ServerException extends AppException {
  const ServerException([super.message = 'Szerver hiba történt']);
}

/// Helyi adatbázis / Cache hiba
class CacheException extends AppException {
  const CacheException([super.message = 'Helyi adatbázis hiba történt']);
}

/// Hálózati kapcsolat hiánya
class NetworkException extends AppException {
  const NetworkException([super.message = 'Nincs internetkapcsolat']);
}
