import 'package:flutter/material.dart';
import '../../res/colors.dart';
import '../../res/assets.dart';
import '../widgets/main_navigation_bar.dart';
import '../widgets/primary_button.dart';
import '../widgets/secondary_button.dart';
import '../../app_routes.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPrimaryBackgroundColor,
      bottomNavigationBar: const MainNavigationBar(currentIndex: 0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              // Official Logo
              Image.asset(
                AppAssets.logoNeon,
                height: 280,
                fit: BoxFit.contain,
              ),
              const Spacer(flex: 2),
              // Game Buttons
              PrimaryButton(
                label: 'Lumi Catch',
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.lumiCatch);
                },
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Lumi Taupe',
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.lumiTaupe);
                },
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Lumi Simon',
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.lumiSimon);
                },
              ),
              const SizedBox(height: 24),
              SecondaryButton(
                label: 'Exit',
                onPressed: () {},
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
