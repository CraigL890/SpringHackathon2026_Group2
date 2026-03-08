import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/business_dashboard_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const SafeSpaceApp());
}

class SafeSpaceApp extends StatelessWidget {
  const SafeSpaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeSpace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF9C27B0),
        ),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFF9C27B0),
              body: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            );
          }

          // Not logged in → show landing
          if (!snapshot.hasData) return const LandingScreen();

          // Logged in → check if business or user
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('businesses')
                .doc(snapshot.data!.uid)
                .get()
                .timeout(
                  const Duration(seconds: 10),
                  onTimeout: () => throw Exception('Firestore timeout'),
                ),
            builder: (context, bizSnap) {
              if (bizSnap.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: Color(0xFF9C27B0),
                  body: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                );
              }
              // If business record exists → business dashboard
              if (!bizSnap.hasError && bizSnap.hasData && bizSnap.data!.exists) {
                return const BusinessDashboardScreen();
              }
              // Otherwise → user home (also handles errors/timeouts gracefully)
              return const HomeScreen();
            },
          );
        },
      ),
    );
  }
}