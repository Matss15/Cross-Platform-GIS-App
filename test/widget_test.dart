import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bfp_gis_rosario/app.dart';
import 'package:bfp_gis_rosario/config/rosario_data.dart';

void main() {
  test('Rosario barangay list has all 48 records', () {
    expect(rosarioBarangays.length, 48);
    expect(rosarioBarangays, contains('Alupay'));
    expect(rosarioBarangays, contains('Poblacion H'));
  });

  test('Firestore role mapping supports admin aliases', () {
    expect(roleFromFirestore('resident'), UserRole.citizen);
    expect(roleFromFirestore('barangay'), UserRole.barangay);
    expect(roleFromFirestore('bfp'), UserRole.bfp);
    expect(roleFromFirestore('sub_admin'), UserRole.admin);
  });

  test('barangay names become stable Firestore ids', () {
    expect(barangayIdFor('Macalamcam A'), 'macalamcam_a');
    expect(barangayIdFor('Poblacion H'), 'poblacion_h');
  });

  test('incident reports are counted per barangay', () {
    final counts = countIncidentsByBarangay([
      {'barangayName': 'Alupay'},
      {'barangayName': 'alupay'},
      {'barangayName': 'Itlugan'},
      {'barangayName': ''},
    ]);

    expect(counts['Alupay'], 2);
    expect(counts['Itlugan'], 1);
    expect(counts['Antipolo'], 0);
  });

  test('role navigation exposes only assigned workspaces', () {
    final citizenKeys = destinationsFor(
      UserRole.citizen,
    ).map((destination) => destination.key);
    final adminKeys = destinationsFor(
      UserRole.admin,
    ).map((destination) => destination.key);
    final bfpKeys = destinationsFor(
      UserRole.bfp,
    ).map((destination) => destination.key);

    expect(citizenKeys, containsAll(['home', 'report', 'map', 'profile']));
    expect(citizenKeys, isNot(contains('admins')));
    expect(adminKeys, containsAll(['home', 'admins', 'logs']));
    expect(adminKeys, isNot(contains('report')));
    expect(adminKeys, isNot(contains('personnel')));
    expect(
      destinationsFor(
        UserRole.admin,
      ).firstWhere((destination) => destination.key == 'barangays').label,
      'Barangay',
    );
    expect(
      bfpKeys,
      orderedEquals([
        'home',
        'map',
        'incidents',
        'reports',
        'analytics',
        'profile',
      ]),
    );
  });

  testWidgets('session guard expires an inactive session', (tester) async {
    var expired = false;

    await tester.pumpWidget(
      MaterialApp(
        home: SessionGuard(
          onTimeout: () async => expired = true,
          child: const Scaffold(body: Text('Protected workspace')),
        ),
      ),
    );

    await tester.pump(sessionInactivityTimeout);
    await tester.pump();

    expect(expired, isTrue);
  });

  testWidgets('user activity renews the session timeout', (tester) async {
    var expired = false;

    await tester.pumpWidget(
      MaterialApp(
        home: SessionGuard(
          onTimeout: () async => expired = true,
          child: Scaffold(
            body: TextButton(onPressed: () {}, child: const Text('Action')),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(minutes: 20));
    await tester.tap(find.text('Action'));
    await tester.pump(const Duration(minutes: 20));
    expect(expired, isFalse);

    await tester.pump(const Duration(minutes: 10));
    await tester.pump();
    expect(expired, isTrue);
  });

  testWidgets('equal-height layout aligns desktop analytics panels', (
    tester,
  ) async {
    const leftKey = Key('left-panel');
    const rightKey = Key('right-panel');
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1000,
            child: LayoutSwitcher(
              equalHeight: true,
              left: SizedBox(key: leftKey, height: 120),
              right: SizedBox(key: rightKey, height: 240),
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(leftKey)).height, 240);
    expect(tester.getSize(find.byKey(rightKey)).height, 240);
  });

  testWidgets('admin incident details renders citizen evidence', (
    tester,
  ) async {
    const onePixelPng =
        'data:image/png;base64,'
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdminIncidentDetailsDialog(
            data: {
              'type': 'Structural fire',
              'status': 'Pending',
              'priority': 'High',
              'reporterName': 'Citizen Reporter',
              'barangayName': 'Alupay',
              'address': 'Alupay landmark',
              'description': 'Visible smoke',
              'latitude': 13.88,
              'longitude': 121.16,
              'evidenceFileName': 'fire.jpg',
              'evidenceImage': onePixelPng,
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Incident evidence'), findsOneWidget);
    expect(find.text('fire.jpg'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('admin incident row fits an iPhone-sized viewport', (
    tester,
  ) async {
    const onePixelPng =
        'data:image/png;base64,'
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdminIncidentMobileRow(
            data: {
              'type': 'Structural fire',
              'status': 'Pending',
              'priority': 'High',
              'reporterName': 'Citizen Reporter',
              'barangayName': 'Alupay',
              'address': 'A long location near the Alupay barangay landmark',
              'evidenceImage': onePixelPng,
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Structural fire'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
