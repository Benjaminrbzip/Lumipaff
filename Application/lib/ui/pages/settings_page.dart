import 'package:flutter/material.dart';
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
  double _ledBrightness = 255.0; // Par défaut à 100%
  final AppBleService _bleService = AppBleService();
  String? _savedPodMac;
  bool _isLoadingSaved = true;

  @override
  void initState() {
    super.initState();
    _bleService.init();
    _loadSavedPod().then((_) {
      _bleService.autoConnectSavedPod();
    });
  }

  Future<void> _loadSavedPod() async {
    final mac = await AuthService().getPodMac();
    if (mounted) {
      setState(() {
        _savedPodMac = mac;
        _isLoadingSaved = false;
      });
    }
  }

  Future<void> _saveCurrentPod(String mac) async {
    await AuthService().savePodMac(mac);
    if (mounted) {
      setState(() {
        _savedPodMac = mac;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pod enregistré comme favori !')),
      );
    }
  }

  Future<void> _removeCurrentPod() async {
    await AuthService().removePodMac();
    if (mounted) {
      setState(() {
        _savedPodMac = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Favori supprimé !')),
      );
    }
  }

  Widget _buildPodWidget(String name, bool isConnected, bool isSaved, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSaved ? Colors.amber : kCyanColor, 
          width: isSaved ? 3 : 2,
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSaved ? Colors.amber : Colors.white, 
                fontSize: 14,
                fontWeight: isSaved ? FontWeight.bold : FontWeight.normal,
                height: 1.3,
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSaved) ...[
                  const Icon(Icons.star, color: Colors.amber, size: 14),
                  const SizedBox(width: 4),
                ],
                SvgPicture.asset(
                  isConnected ? AppAssets.iconBluetooth : AppAssets.iconErrorX,
                  width: 14,
                  height: 14,
                  colorFilter: isSaved ? const ColorFilter.mode(Colors.amber, BlendMode.srcIn) : null,
                ),
              ],
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
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 32),
              // Logo
              Image.asset(
                AppAssets.logoNeon,
                height: 280,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 16),
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
                              final isSaved = device.remoteId.toString() == _savedPodMac;
                              
                              return _buildPodWidget(
                                device.advName.isEmpty ? 'Pod\n${index + 1}' : device.advName.replaceAll('_', '\n'),
                                isConnected,
                                isSaved,
                                onTap: () {
                                  if (!isConnected) {
                                    _bleService.connectToDevice(device);
                                  }
                                },
                              );
                            } else {
                              // Cases vides pour remplir la grille
                              return _buildPodWidget('Vide', false, false);
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<List<BluetoothDevice>>(
                valueListenable: _bleService.connectedDevicesNotifier,
                builder: (context, connectedDevices, _) {
                  if (connectedDevices.isEmpty) return const SizedBox.shrink();
                  
                  final currentDevice = connectedDevices.first;
                  final isSaved = currentDevice.remoteId.toString() == _savedPodMac;
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: SecondaryButton(
                      label: isSaved ? 'Retirer ce favori' : 'Enregistrer ce Pod',
                      color: isSaved ? Colors.redAccent : kCyanColor,
                      onPressed: () => isSaved ? _removeCurrentPod() : _saveCurrentPod(currentDevice.remoteId.toString()),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
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
              const SizedBox(height: 24),
              // LED Brightness Slider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Row(
                  children: [
                    const Text(
                      'LEDs :',
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
                          activeTrackColor: Colors.amber,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: Colors.amber,
                          trackHeight: 12.0,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0),
                          overlayColor: Colors.amber.withOpacity(0.2),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 20.0),
                        ),
                        child: Slider(
                          value: _ledBrightness,
                          min: 0.0,
                          max: 255.0,
                          onChanged: (val) {
                            setState(() {
                              _ledBrightness = val;
                            });
                            _bleService.setBrightness(val.toInt());
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
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
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
