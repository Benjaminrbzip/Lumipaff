import 'package:flutter/material.dart';
import 'ui/pages/home_page.dart';
import 'ui/pages/leaderboard_page.dart';
import 'ui/pages/settings_page.dart';
import 'ui/pages/lumi_taupe_game_page.dart';
import 'ui/pages/lumi_catch_game_page.dart';
import 'ui/pages/lumi_simon_game_page.dart';
import 'ui/pages/login_page.dart';
import 'ui/pages/signup_page.dart';

class AppRoutes {
  static const String home = '/';
  static const String leaderboard = '/leaderboard';
  static const String settings = '/settings';
  static const String lumiTaupe = '/lumi_taupe';
  static const String lumiCatch = '/lumi_catch';
  static const String lumiSimon = '/lumi_simon';
  static const String login = '/login';
  static const String signup = '/signup';

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      home: (context) => const HomePage(),
      leaderboard: (context) => const LeaderboardPage(),
      settings: (context) => const SettingsPage(),
      lumiTaupe: (context) => const LumiTaupeGamePage(),
      lumiCatch: (context) => const LumiCatchGamePage(),
      lumiSimon: (context) => const LumiSimonGamePage(),
      login: (context) => const LoginPage(),
      signup: (context) => const SignupPage(),
    };
  }
}
