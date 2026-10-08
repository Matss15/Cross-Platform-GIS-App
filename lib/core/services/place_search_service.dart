part of '../../app.dart';

/// A place the citizen can pick from the location search suggestions.
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.title,
    required this.subtitle,
    required this.point,
  });

  final String title;
  final String subtitle;
  final LatLng point;

  /// The text written into the report's location field.
  String get addressText => subtitle.isEmpty ? title : '$title, $subtitle';
}

// Everyday words people type that OpenStreetMap names differently.
const _placeSearchAliases = {
  'munisipyo': 'municipal hall',
  'palengke': 'public market',
  'simbahan': 'church',
  'paaralan': 'school',
  'eskwelahan': 'school',
  'ospital': 'hospital',
  'brgy': 'barangay',
  'bgy': 'barangay',
  'seven eleven': '7-Eleven',
  '7/11': '7-Eleven',
  '711': '7-Eleven',
};

String _expandPlaceAliases(String query) {
  var text = ' ${query.toLowerCase()} ';
  _placeSearchAliases.forEach((alias, replacement) {
    text = text.replaceAll(' $alias ', ' $replacement ');
  });
  // "Rosario" only narrows the search, which the map bounds already do.
  text = text.replaceAll(RegExp(r'\b(rosario|batangas)\b'), ' ');
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Finds places in Rosario for the location search box, best match first.
///
/// Uses Photon (OpenStreetMap search built for type-ahead), which tolerates
/// nicknames and typos such as "mcdo", and falls back to Nominatim.
Future<List<PlaceSuggestion>> searchRosarioPlaces(String query) async {
  final text = _expandPlaceAliases(query);
  if (text.length < 2) return const [];
  try {
    final results = await _searchPhoton(text);
    if (results.isNotEmpty) return results;
  } catch (_) {
    // Try the other geocoder below.
  }
  try {
    return await _searchNominatim(text);
  } catch (_) {
    return const [];
  }
}

Future<List<PlaceSuggestion>> _searchPhoton(String text) async {
  final uri = Uri.https('photon.komoot.io', '/api/', {
    'q': text,
    'lat': '${rosarioCenter.latitude}',
    'lon': '${rosarioCenter.longitude}',
    'bbox':
        '${rosarioBounds.west},${rosarioBounds.south},'
        '${rosarioBounds.east},${rosarioBounds.north}',
    'limit': '8',
  });
  final response = await http
      .get(uri, headers: const {'User-Agent': 'BFP-Rosario-GIS/1.0'})
      .timeout(const Duration(seconds: 8));
  if (response.statusCode != 200) return const [];
  final payload = jsonDecode(response.body);
  final features = payload is Map ? payload['features'] : null;
  if (features is! List) return const [];

  final inRosario = <PlaceSuggestion>[];
  final nearby = <PlaceSuggestion>[];
  for (final feature in features.whereType<Map>()) {
    final coordinates = (feature['geometry'] as Map?)?['coordinates'];
    final props = feature['properties'];
    if (coordinates is! List || coordinates.length < 2 || props is! Map) {
      continue;
    }
    final point = LatLng(
      (coordinates[1] as num).toDouble(),
      (coordinates[0] as num).toDouble(),
    );
    if (!rosarioBounds.contains(point)) continue;

    final street = [
      props['housenumber'],
      props['street'],
    ].whereType<String>().join(' ');
    final name = props['name'] as String?;
    final title = name ?? (street.isEmpty ? null : street);
    if (title == null) continue;
    final city = props['city'] as String? ?? props['county'] as String?;
    final subtitle = [
      if (name != null && street.isNotEmpty) street,
      props['district'],
      city,
    ].whereType<String>().where((part) => part.isNotEmpty).join(', ');

    final suggestion = PlaceSuggestion(
      title: title,
      subtitle: subtitle,
      point: point,
    );
    // Rosario first; the bounds also reach into neighbouring towns.
    (city == 'Rosario' ? inRosario : nearby).add(suggestion);
  }
  return [...inRosario, ...nearby].take(6).toList();
}

Future<List<PlaceSuggestion>> _searchNominatim(String text) async {
  final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
    'format': 'jsonv2',
    'q': text,
    'countrycodes': 'ph',
    'viewbox':
        '${rosarioBounds.west},${rosarioBounds.north},'
        '${rosarioBounds.east},${rosarioBounds.south}',
    'bounded': '1',
    'limit': '6',
  });
  final response = await http
      .get(uri, headers: const {'User-Agent': 'BFP-Rosario-GIS/1.0'})
      .timeout(const Duration(seconds: 8));
  if (response.statusCode != 200) return const [];
  final results = jsonDecode(response.body);
  if (results is! List) return const [];

  return [
    for (final result in results.whereType<Map>())
      if (double.tryParse('${result['lat']}') case final lat?)
        if (double.tryParse('${result['lon']}') case final lon?)
          PlaceSuggestion(
            title: '${result['name'] ?? ''}'.isNotEmpty
                ? '${result['name']}'
                : '${result['display_name']}'.split(',').first,
            // Drop the region, postcode and country at the end.
            subtitle: '${result['display_name']}'
                .split(',')
                .skip(1)
                .take(3)
                .map((part) => part.trim())
                .join(', '),
            point: LatLng(lat, lon),
          ),
  ];
}
