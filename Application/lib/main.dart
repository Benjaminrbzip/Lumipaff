import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_routes.dart';
import 'res/colors.dart';
import 'services/bluetooth_service.dart';
import 'services/audio_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  final currentUser = FirebaseAuth.instance.currentUser;
  final initialRoute = currentUser != null ? AppRoutes.home : AppRoutes.login;
  
  // Initialisation des services
  AppBleService().init();
  AudioService().startMusic('audio/Music/Mainthemel.mp3');
  
  runApp(LumiPaffApp(initialRoute: initialRoute));
}

class LumiPaffApp extends StatelessWidget {
  final String initialRoute;
  
  const LumiPaffApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LumiPaff',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kPrimaryBackgroundColor,
        colorScheme: const ColorScheme.dark(
          primary: kPrimaryButtonColor,
          surface: kNavigationBarColor,
        ),
      ),
      initialRoute: initialRoute,
      routes: AppRoutes.getRoutes(),
    );
  }
}
