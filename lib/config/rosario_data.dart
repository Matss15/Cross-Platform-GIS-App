class RosarioBarangayRecord {
  const RosarioBarangayRecord({
    required this.name,
    this.psgcCode = '',
    this.correspondenceCode = '',
    this.classification = '',
    this.population = 0,
  });

  final String name;
  final String psgcCode;
  final String correspondenceCode;
  final String classification;
  final int population;
}

const superAdminEmail = 'akoangadmin@gmail.com';

const rosarioFireStationPhoneDisplay = '(043) 312-1102';
const rosarioFireStationMobileDisplay = '0915 602 4435';
const rosarioFireStationPhoneDial = '+63433121102';
const rosarioFireStationMobileDial = '+639156024435';

// Project barangay list supplied for Rosario, Batangas.
const rosarioBarangayRecords = <RosarioBarangayRecord>[
  RosarioBarangayRecord(name: 'Alupay'),
  RosarioBarangayRecord(name: 'Antipolo'),
  RosarioBarangayRecord(name: 'Bagong Pook'),
  RosarioBarangayRecord(name: 'Balibago'),
  RosarioBarangayRecord(name: 'Bayawang'),
  RosarioBarangayRecord(name: 'Baybayin'),
  RosarioBarangayRecord(name: 'Bulihan'),
  RosarioBarangayRecord(name: 'Cahigam'),
  RosarioBarangayRecord(name: 'Calantas'),
  RosarioBarangayRecord(name: 'Colnelis'),
  RosarioBarangayRecord(name: 'Dagatan'),
  RosarioBarangayRecord(name: 'Itlugan'),
  RosarioBarangayRecord(name: 'Macalamcam A'),
  RosarioBarangayRecord(name: 'Macalamcam B'),
  RosarioBarangayRecord(name: 'Malaya'),
  RosarioBarangayRecord(name: 'Maligaya'),
  RosarioBarangayRecord(name: 'Marilag'),
  RosarioBarangayRecord(name: 'Masaya'),
  RosarioBarangayRecord(name: 'Matamis'),
  RosarioBarangayRecord(name: 'Mavalor'),
  RosarioBarangayRecord(name: 'Mayuro'),
  RosarioBarangayRecord(name: 'Namuco'),
  RosarioBarangayRecord(name: 'Namunga'),
  RosarioBarangayRecord(name: 'Natu'),
  RosarioBarangayRecord(name: 'Palakpak'),
  RosarioBarangayRecord(name: 'Pinagsibaan'),
  RosarioBarangayRecord(name: 'Putingkahoy'),
  RosarioBarangayRecord(name: 'Quilib'),
  RosarioBarangayRecord(name: 'Salao'),
  RosarioBarangayRecord(name: 'San Alejandro'),
  RosarioBarangayRecord(name: 'San Carlos'),
  RosarioBarangayRecord(name: 'San Isidro'),
  RosarioBarangayRecord(name: 'San Jose'),
  RosarioBarangayRecord(name: 'San Juan'),
  RosarioBarangayRecord(name: 'San Roque'),
  RosarioBarangayRecord(name: 'Santa Cruz'),
  RosarioBarangayRecord(name: 'Santiago'),
  RosarioBarangayRecord(name: 'Timbugan'),
  RosarioBarangayRecord(name: 'Tiquiwan'),
  RosarioBarangayRecord(name: 'Tulos'),
  RosarioBarangayRecord(name: 'Poblacion A'),
  RosarioBarangayRecord(name: 'Poblacion B'),
  RosarioBarangayRecord(name: 'Poblacion C'),
  RosarioBarangayRecord(name: 'Poblacion D'),
  RosarioBarangayRecord(name: 'Poblacion E'),
  RosarioBarangayRecord(name: 'Poblacion F'),
  RosarioBarangayRecord(name: 'Poblacion G'),
  RosarioBarangayRecord(name: 'Poblacion H'),
];

List<String> get rosarioBarangays => [
  for (final barangay in rosarioBarangayRecords) barangay.name,
];

// These two names were first saved without a space, so their ids stay the
// same and existing accounts, reports and barangay docs keep matching.
const _legacyBarangayIds = {
  'bagong_pook': 'bagongpook',
  'macalamcam_b': 'macalamcamb',
};

String barangayIdFor(String name) {
  final normalized = name.trim().toLowerCase();
  final compact = normalized
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return _legacyBarangayIds[compact] ?? compact;
}

/// The listed spelling of [name], so old values such as "BagongPook" show as
/// "Bagong Pook". Returns null when the barangay is not in the list.
String? canonicalBarangayName(String name) {
  final id = barangayIdFor(name);
  for (final record in rosarioBarangayRecords) {
    if (barangayIdFor(record.name) == id) return record.name;
  }
  return null;
}

class EmergencyHotline {
  const EmergencyHotline(this.name, this.numbers);

  final String name;

  /// Numbers as printed on the official posters.
  final List<String> numbers;
}

/// Rosario, Batangas contacts from the Rosario MPS "Emergency Contact Numbers"
/// poster.
const rosarioEmergencyHotlines = <EmergencyHotline>[
  EmergencyHotline('Fire (BFP Rosario)', ['043.312.1102', '0915.602.4435']),
  EmergencyHotline('Police (Rosario MPS)', ['043.724.7026', '0927-237-0519']),
  EmergencyHotline('MDRRMO', ['043.311.2935', '0917.133.9605']),
  EmergencyHotline('Health', ['043.740.1338', '0908.280.1497']),
  EmergencyHotline('Red Cross', ['043.740.0768', '0917.142.9378']),
  EmergencyHotline('MSWDO', ['0917.816.4863', '0939.038.0295']),
  EmergencyHotline('RTMPSO', ['0981.222.5047']),
  EmergencyHotline('BATELEC II', ['0998.548.6153', '0917.132.1523']),
];

/// National agencies from the "Emergency Hotlines" poster.
const nationalEmergencyHotlines = <EmergencyHotline>[
  EmergencyHotline('National Emergency Hotline', ['911']),
  EmergencyHotline('Bureau of Fire Protection', [
    '(02) 8426-0219',
    '(02) 8426-0246',
  ]),
  EmergencyHotline('Philippine National Police', ['117', '(02) 8722-0650']),
  EmergencyHotline('Philippine Red Cross', [
    '143',
    '(02) 527-0000',
    '(02) 527-8385 to 95',
  ]),
  EmergencyHotline('NDRRMC', [
    '911-5061 to 65',
    '(+632) 9114016',
    '(+632) 9122665',
  ]),
  EmergencyHotline('Philippine Coast Guard', ['(02) 8527-3877']),
  EmergencyHotline('PAGASA', ['(02) 8284-0800']),
  EmergencyHotline('MMDA', ['136', '(02) 8882-4151 to 77']),
  EmergencyHotline('MERALCO', [
    '16211',
    '0920 971 6211 (Smart)',
    '0917 551 6211 (Globe)',
  ]),
];

/// The digits to dial for a printed number: "(02) 8882-4151 to 77" dials the
/// first number of the range, a network label such as "(Smart)" is dropped,
/// and "(+632) 9114016" keeps its plus sign.
String hotlineDialString(String printed) {
  final number = printed
      .split(' to ')
      .first
      .replaceAll(RegExp(r'\([A-Za-z]+\)'), '')
      .trim();
  final digits = number.replaceAll(RegExp(r'[^0-9]'), '');
  return number.contains('+') ? '+$digits' : digits;
}
