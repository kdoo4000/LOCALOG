List<List<T>> groupConsecutiveByKey<T, K>(
  Iterable<T> items,
  K? Function(T item) keyOf,
) {
  final groups = <List<T>>[];
  K? previousKey;
  var hasPreviousKey = false;

  for (final item in items) {
    final key = keyOf(item);
    if (groups.isNotEmpty &&
        hasPreviousKey &&
        key != null &&
        key == previousKey) {
      groups.last.add(item);
    } else {
      groups.add([item]);
    }
    previousKey = key;
    hasPreviousKey = key != null;
  }

  return groups;
}
