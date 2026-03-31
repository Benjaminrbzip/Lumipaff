import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class AppBleService {
  static final AppBleService _instance = AppBleService._internal();

  factory AppBleService() {
    return _instance;
  }

  AppBleService._internal();

  // UUIDs partagés entre l'ESP32 et l'application LumiPaff
  final String deviceNamePrefix = "LumiPod_";
  final String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String buttonCharUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  // Listes pour l'UI
  final ValueNotifier<List<ScanResult>> scanResultsNotifier = ValueNotifier([]);
  final ValueNotifier<List<BluetoothDevice>> connectedDevicesNotifier = ValueNotifier([]);

  // Stream global pour diffuser les appuis sur les boutons à travers tout le jeu
  // Format : { 'deviceId': 'MAC_ADDRESS', 'buttonValue': '1' }
  final StreamController<Map<String, dynamic>> _buttonEventsController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get buttonEvents => _buttonEventsController.stream;

  StreamSubscription<List<ScanResult>>? _scanSubscription;

  void init() {
    // S'abonner aux changements d'état du Bluetooth
    FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
      if (state == BluetoothAdapterState.on) {
        startScan();
      }
    });
  }

  Future<void> startScan() async {
    // Vider les anciens résultats
    scanResultsNotifier.value = [];
    
    // Ecouter les résultats de scan
    _scanSubscription?.cancel();
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      // Filtrer les équipements pour ne garder que ceux qui s'appellent "LumiPod_xxx"
      final pods = results.where((r) => r.device.advName.startsWith(deviceNamePrefix)).toList();
      scanResultsNotifier.value = pods;
    });

    // Lancer le scan (pendant 10 secondes)
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    } catch (e) {
      debugPrint("Erreur de scan: $e");
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect(license: License.free);
      
      // Mettre à jour la liste des appareils connectés
      if (!connectedDevicesNotifier.value.contains(device)) {
        connectedDevicesNotifier.value = List.from(connectedDevicesNotifier.value)..add(device);
      }

      // Scanner les services du device
      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        if (service.uuid.toString() == serviceUuid) {
          // Chercher la caractéristique de bouton
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString() == buttonCharUuid) {
              // Activer la notification (pour écouter l'ESP32 sans avoir à l'interroger sans cesse)
              await characteristic.setNotifyValue(true);
              characteristic.onValueReceived.listen((value) {
                // value est souvent un tableau d'entiers (ex: [1] pour le bouton 1)
                if (value.isNotEmpty) {
                  int buttonPushed = value[0];
                  _buttonEventsController.add({
                    'deviceId': device.remoteId.toString(),
                    'buttonValue': buttonPushed,
                  });
                }
              });
            }
          }
        }
      }
      
      // Ecouter la perte de connexion potentielle pour nettoyer
      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          connectedDevicesNotifier.value = List.from(connectedDevicesNotifier.value)..remove(device);
        }
      });
      
    } catch (e) {
      debugPrint("Erreur lors de la connexion: $e");
    }
  }

  Future<void> disconnectAll() async {
    for (var device in connectedDevicesNotifier.value) {
      await device.disconnect();
    }
    connectedDevicesNotifier.value = [];
  }
}
