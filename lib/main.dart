import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppBootstrap());
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late Future<FirebaseApp> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = _initializeFirebase();
  }

  Future<FirebaseApp> _initializeFirebase() {
    return Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 30));
  }

  void _retryInitialization() {
    setState(() {
      _initialization = _initializeFirebase();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FirebaseApp>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return const BFPGISApp();
        }

        return MaterialApp(
          title: 'BFP Rosario GIS',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF11171A),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF20A36A),
              brightness: Brightness.dark,
            ),
          ),
          home: Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BfpBadge(size: 76, accent: Color(0xFF20A36A)),
                    const SizedBox(height: 18),
                    const Text(
                      'BFP ROSARIO GIS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      snapshot.hasError
                          ? 'Unable to start the secure workspace.'
                          : 'Preparing secure workspace...',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFAAB5BA)),
                    ),
                    const SizedBox(height: 22),
                    if (snapshot.hasError)
                      FilledButton.icon(
                        onPressed: _retryInitialization,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      )
                    else
                      const SizedBox(
                        width: 180,
                        child: LinearProgressIndicator(minHeight: 3),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
