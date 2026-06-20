import 'package:shared_preferences/shared_preferences.dart';

class RecentlyPlayedService {
  static const _kKey = 'recently_played_ids';
  static const _maxSize = 5;

  /// Adiciona [id] ao histórico. Remove duplicata existente antes de inserir
  /// no topo. Mantém no máximo [_maxSize] entradas.
  static Future<List<int>> push(int id, List<int> current) async {
    final updated = [id, ...current.where((e) => e != id)];
    if (updated.length > _maxSize)
      updated.removeRange(_maxSize, updated.length);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kKey, updated.map((e) => e.toString()).toList());
    return updated;
  }

  static Future<List<int>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kKey) ?? [];
    return raw.map((e) => int.tryParse(e)).whereType<int>().toList();
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }
}
