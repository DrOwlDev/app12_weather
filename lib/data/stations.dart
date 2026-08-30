class StationInfo {
  const StationInfo({
    required this.cityKey,
    required this.displayName,
    required this.icao,
    required this.latitude,
    required this.longitude,
    required this.resolutionSource,
    this.dataQualityScore = 0.8,
  });

  final String cityKey;
  final String displayName;
  final String icao;
  final double latitude;
  final double longitude;
  final String resolutionSource;
  final double dataQualityScore;
}

const stationRegistry = <String, StationInfo>{
  'miami': StationInfo(
    cityKey: 'miami',
    displayName: 'Miami',
    icao: 'KMIA',
    latitude: 25.79,
    longitude: -80.29,
    resolutionSource: 'NOAA KMIA',
    dataQualityScore: 0.95,
  ),
  'dallas': StationInfo(
    cityKey: 'dallas',
    displayName: 'Dallas',
    icao: 'KDFW',
    latitude: 32.90,
    longitude: -97.04,
    resolutionSource: 'NOAA KDFW',
    dataQualityScore: 0.95,
  ),
  'new york': StationInfo(
    cityKey: 'new york',
    displayName: 'New York',
    icao: 'KLGA',
    latitude: 40.78,
    longitude: -73.87,
    resolutionSource: 'NOAA KLGA',
    dataQualityScore: 0.95,
  ),
  'toronto': StationInfo(
    cityKey: 'toronto',
    displayName: 'Toronto',
    icao: 'CYYZ',
    latitude: 43.68,
    longitude: -79.63,
    resolutionSource: 'Wunderground CYYZ',
    dataQualityScore: 0.85,
  ),
  'seoul': StationInfo(
    cityKey: 'seoul',
    displayName: 'Seoul (Incheon)',
    icao: 'RKSI',
    latitude: 37.46,
    longitude: 126.44,
    resolutionSource: 'METAR RKSI',
    dataQualityScore: 0.88,
  ),
  'hong kong': StationInfo(
    cityKey: 'hong kong',
    displayName: 'Hong Kong',
    icao: 'VHHH',
    latitude: 22.31,
    longitude: 113.91,
    resolutionSource: 'METAR VHHH',
    dataQualityScore: 0.85,
  ),
  'paris': StationInfo(
    cityKey: 'paris',
    displayName: 'Paris',
    icao: 'LFPB',
    latitude: 48.97,
    longitude: 2.44,
    resolutionSource: 'Wunderground LFPB',
    dataQualityScore: 0.85,
  ),
  'london': StationInfo(
    cityKey: 'london',
    displayName: 'London',
    icao: 'EGLC',
    latitude: 51.51,
    longitude: 0.05,
    resolutionSource: 'METAR EGLC',
    dataQualityScore: 0.88,
  ),
  'shanghai': StationInfo(
    cityKey: 'shanghai',
    displayName: 'Shanghai',
    icao: 'ZSPD',
    latitude: 31.14,
    longitude: 121.81,
    resolutionSource: 'METAR ZSPD',
    dataQualityScore: 0.82,
  ),
  'beijing': StationInfo(
    cityKey: 'beijing',
    displayName: 'Beijing',
    icao: 'ZBAA',
    latitude: 40.08,
    longitude: 116.58,
    resolutionSource: 'METAR ZBAA',
    dataQualityScore: 0.82,
  ),
  'tokyo': StationInfo(
    cityKey: 'tokyo',
    displayName: 'Tokyo',
    icao: 'RJTT',
    latitude: 35.55,
    longitude: 139.78,
    resolutionSource: 'METAR RJTT',
    dataQualityScore: 0.85,
  ),
  'taipei': StationInfo(
    cityKey: 'taipei',
    displayName: 'Taipei',
    icao: 'RCTP',
    latitude: 25.08,
    longitude: 121.23,
    resolutionSource: 'METAR RCTP',
    dataQualityScore: 0.82,
  ),
  'wuhan': StationInfo(
    cityKey: 'wuhan',
    displayName: 'Wuhan',
    icao: 'ZHHH',
    latitude: 30.78,
    longitude: 114.21,
    resolutionSource: 'METAR ZHHH',
    dataQualityScore: 0.80,
  ),
  'los angeles': StationInfo(
    cityKey: 'los angeles',
    displayName: 'Los Angeles',
    icao: 'KLAX',
    latitude: 33.94,
    longitude: -118.41,
    resolutionSource: 'NOAA KLAX',
    dataQualityScore: 0.90,
  ),
  'phoenix': StationInfo(
    cityKey: 'phoenix',
    displayName: 'Phoenix',
    icao: 'KPHX',
    latitude: 33.43,
    longitude: -112.01,
    resolutionSource: 'NOAA KPHX',
    dataQualityScore: 0.92,
  ),
};

StationInfo? lookupStation(String city) {
  final normalized = city.toLowerCase().trim();
  if (stationRegistry.containsKey(normalized)) {
    return stationRegistry[normalized];
  }
  for (final entry in stationRegistry.entries) {
    if (normalized.contains(entry.key) || entry.key.contains(normalized)) {
      return entry.value;
    }
  }
  return null;
}

String? extractIcaoFromText(String text) {
  final siteMatch = RegExp(r'site=([a-z0-9]{4})', caseSensitive: false)
      .firstMatch(text);
  if (siteMatch != null) {
    return siteMatch.group(1)!.toUpperCase();
  }
  final icaoMatch =
      RegExp(r'\b([A-Z]{4})\b').allMatches(text).map((m) => m.group(1)!);
  for (final code in icaoMatch) {
    if (code.startsWith('K') ||
        code.startsWith('C') ||
        code.startsWith('R') ||
        code.startsWith('L') ||
        code.startsWith('E') ||
        code.startsWith('V') ||
        code.startsWith('Z')) {
      return code;
    }
  }
  return null;
}

String extractCityFromTitle(String title) {
  final match = RegExp(
    r'(?:Highest|Lowest) temperature in (.+?) on ',
    caseSensitive: false,
  ).firstMatch(title);
  if (match != null) {
    return match.group(1)!.trim();
  }
  return title;
}

DateTime? extractDateFromTitle(String title) {
  final match = RegExp(
    r'on ([A-Za-z]+ \d{1,2})(?:\?|$|\.)',
    caseSensitive: false,
  ).firstMatch(title);
  if (match == null) return null;
  final dateStr = match.group(1)!;
  final now = DateTime.now();
  const months = {
    'january': 1,
    'february': 2,
    'march': 3,
    'april': 4,
    'may': 5,
    'june': 6,
    'july': 7,
    'august': 8,
    'september': 9,
    'october': 10,
    'november': 11,
    'december': 12,
  };
  final parts = dateStr.toLowerCase().split(' ');
  if (parts.length != 2) return null;
  final month = months[parts[0]];
  final day = int.tryParse(parts[1]);
  if (month == null || day == null) return null;
  var year = now.year;
  final thisYear = DateTime(year, month, day);
  final candidates = [
    thisYear,
    DateTime(year - 1, month, day),
    DateTime(year + 1, month, day),
  ];
  candidates.sort((a, b) {
    final diffA = a.difference(dateOnly(now)).inDays.abs();
    final diffB = b.difference(dateOnly(now)).inDays.abs();
    return diffA.compareTo(diffB);
  });
  return dateOnly(candidates.first);
}

DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
