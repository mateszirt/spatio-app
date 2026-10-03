import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// RFC4122 v4 formátumú szabványos UUID generálása (PostgreSQL / Supabase kompatibilis)
String generateUuid() => _uuid.v4();
