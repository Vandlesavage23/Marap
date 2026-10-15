/// One page of a cursor-paginated list (`{items, next_cursor}`, Bible §8.1).
class Paged<T> {
  const Paged({required this.items, this.nextCursor});
  final List<T> items;
  final String? nextCursor;
}

/// Helpers for reading the backend's snake_case JSON without `dynamic`.
extension JsonMap on Map<String, dynamic> {
  String str(String key, [String fallback = '']) {
    final v = this[key];
    return v is String ? v : fallback;
  }

  String? strOrNull(String key) {
    final v = this[key];
    return v is String && v.isNotEmpty ? v : null;
  }

  int? intOrNull(String key) {
    final v = this[key];
    return v is int ? v : (v is num ? v.toInt() : null);
  }

  bool flag(String key) => this[key] == true;

  DateTime? time(String key) {
    final v = this[key];
    return v is String ? DateTime.tryParse(v)?.toLocal() : null;
  }

  Map<String, dynamic>? obj(String key) {
    final v = this[key];
    return v is Map<String, dynamic> ? v : null;
  }

  List<String> strings(String key) {
    final v = this[key];
    return v is List ? v.whereType<String>().toList() : const [];
  }

  List<Map<String, dynamic>> maps(String key) {
    final v = this[key];
    return v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];
  }
}
