class ParsedData {
  final String name;
  final int? days;

  ParsedData(this.name, this.days);
}

ParsedData parseSmart(String raw) {
  final lower = raw.toLowerCase();

  // NAME
  String name = 'Item';
  if (lower.contains('insurance')) name = 'Insurance Policy';
  else if (lower.contains('vehicle')) name = 'Vehicle';
  else if (lower.contains('license')) name = 'Driving License';
  else if (lower.contains('passport')) name = 'Passport';

  // DAYS
  final match = RegExp(r'(\d+)\s*day').firstMatch(lower);
  final days = match != null ? int.parse(match.group(1)!) : null;

  return ParsedData(name, days);
}
