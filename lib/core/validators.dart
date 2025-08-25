String? notEmpty(String? v, [String field = 'Field']) {
  if (v == null || v.trim().isEmpty) return '$field is required';
  return null;
}
