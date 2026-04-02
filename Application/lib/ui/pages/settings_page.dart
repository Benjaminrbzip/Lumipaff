vb          import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../res/colors.dart';
import '../../res/assets.dart';
import '../widgets/main_navigation_bar.dart';
import '../widgets/secondary_button.dart';
import '../../services/auth_service.dart';
import '../../services/bluetooth_service.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../app_routes.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  double _volume = 0.8;
  final AppBleService _bleService = AppBleService();

  @override
  void initState() {
    super.initState();
    _bleService.init();
  }

  Widget _buildPodWidget(String name, bool isConnected, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kCyanColor, width: 2),
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white, 
                fontSize: 14,
                height: 1.3,
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: SvgPicture.asset(
              isConnected ? AppAssets.iconBluetooth : AppAssets.iconErrorX,
              width: 14,
              height: 14,
            ),
          ),
        ],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPrimaryBackgroundColor,
      bottomNavigationBar: const MainNavigationBar(currentIndex: 2),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),
            // Logo
            Image.asset(
              AppAssets.logoNeon,
              height: 280,
              fit: BoxFit.contain,
            ),
            const Spacer(),
            // Pod Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: ValueListenableBuilder<List<BluetoothDevice>>(
                valueListenable: _bleService.connectedDevicesNotifier,
                builder: (context, connectedDevices, _) {
                  return ValueListenableBuilder<List<ScanResult>>(
                    valueListenable: _bleService.scanResultsNotifier,
                    builder: (context, scanResults, _) {
                      // On fusionne les pods connectés et les pods trouvés (sans doublon)
                      final allDevices = <BluetoothDevice>{};
                      allDevices.addAll(connectedDevices);
                      allDevices.addAll(scanResults.map((e) => e.device));
                      final deviceList = allDevices.toList();

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 1.0,
                        ),
                        // Afficher 6 cases minimum (esthétique)
                        itemCount: deviceList.length > 6 ? deviceList.length : 6,
                        itemBuilder: (context, index) {
                          if (index < deviceList.length) {
                            final device = deviceList[index];
                            final isConnected = connectedDevices.contains(device);
                            return _buildPodWidget(
                              device.advName.isEmpty ? 'Pod\n${index + 1}' : device.advName.replaceAll('_', '\n'),
                              isConnected,
                              onTap: () {
                                if (!isConnected) {
                                  _bleService.connectToDevice(device);
                                }
                              },
                            );
                          } else {
                            // Cases vides pour remplir la grille
                            return _buildPodWidget('Vide', false);
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const Spacer(),
            // Volume Slider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Row(
                children: [
                  const Text(
                    'Volume :',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: kCyanColor,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: kCyanColor,
                        trackHeight: 12.0, // thick track as in mockup
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0),
                        overlayColor: kCyanColor.withOpacity(0.2),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20.0),
                      ),
                      child: Slider(
                        value: _volume,
                        onChanged: (val) {
                          setState(() {
                            _volume = val;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Déconnexion
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: SecondaryButton(
                label: 'Déconnexion',
                color: Colors.redAccent,
                onPressed: () async {
                  await AuthService().signOut();
                  if (!context.mounted) return;
                  Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
                },
              ),
            ),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}
