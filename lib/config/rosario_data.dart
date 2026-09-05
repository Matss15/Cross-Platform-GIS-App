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
  RosarioBarangayRecord(name: 'BagongPook'),
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
  RosarioBarangayRecord(name: 'MacalamcamB'),
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

String barangayIdFor(String name) {
  final normalized = name.trim().toLowerCase();
  final compact = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  return compact.replaceAll(RegExp(r'^_+|_+$'), '');
}
