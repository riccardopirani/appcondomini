/// Maschera token o segreti per log di debug senza usare [String.substring] unsafe.
String redactTokenForLog(Object? token) {
  if (token == null) return '(null)';
  final s = token.toString();
  if (s.isEmpty) return '(empty)';
  if (s.length <= 8) return '***';
  if (s.length <= 20) return '${s.substring(0, 4)}…(${s.length})';
  return '${s.substring(0, 20)}…${s.substring(s.length - 10)}';
}
