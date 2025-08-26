import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:kardix_flutter/pages/ecg.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothConnectionScreen extends StatefulWidget {
  const BluetoothConnectionScreen({super.key});

  @override
  State<StatefulWidget> createState() {
    return _BluetoothConnectionScreenState();
  }
}

class _BluetoothConnectionScreenState
    extends State<BluetoothConnectionScreen> {
  ConnectionState _connectionState = ConnectionState.none;
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  String _statusMessage = "Подготовка Bluetooth...";
  IconData _statusIcon = Icons.bluetooth;
  Color _statusColor = Colors.blue;
  Timer? _connectionTimer;

  static const String ecgServiceUuid =
      "0000ffe0-0000-1000-8000-00805f9b34fb";
  bool _permissionsGranted = false;
  bool _bluetoothEnabled = false;

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  Future<void> _initBluetooth() async {
    try {
      if (!await FlutterBluePlus.isSupported) {
        _updateStatus(
          "Bluetooth LE не поддерживается",
          Icons.bluetooth_disabled,
          Colors.red,
        );
        return;
      }

      await _checkBluetoothState();

      await _requestPermissions();

      // Если всё в порядке, начинаем сканирование
      if (_bluetoothEnabled && _permissionsGranted) {
        _startScanning();
      }
    } catch (e) {
      _updateStatus(
        "Ошибка инициализации: ${e.toString()}",
        Icons.error,
        Colors.red,
      );
    }
  }

  Future<void> _checkBluetoothState() async {
    try {
      // Получаем текущее состояние Bluetooth
      BluetoothAdapterState state =
          await FlutterBluePlus.adapterState.first;

      if (state == BluetoothAdapterState.on) {
        setState(() => _bluetoothEnabled = true);
      } else {
        _updateStatus(
          "Включите Bluetooth",
          Icons.bluetooth_disabled,
          Colors.orange,
        );
        setState(() => _bluetoothEnabled = false);

        // Слушаем изменения состояния Bluetooth
        FlutterBluePlus.adapterState.listen((newState) {
          if (newState == BluetoothAdapterState.on && mounted) {
            setState(() => _bluetoothEnabled = true);
            _initBluetooth();
          }
        });
      }
    } catch (e) {
      _updateStatus(
        "Ошибка проверки Bluetooth: ${e.toString()}",
        Icons.error,
        Colors.red,
      );
    }
  }

  Future<void> _requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        // Запрашиваем пакет разрешений
        Map<Permission, PermissionStatus> statuses = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.location,
        ].request();

        // Проверяем результат
        final newPermissionsGranted =
            statuses[Permission.bluetoothScan]?.isGranted ==
                true &&
            statuses[Permission.bluetoothConnect]?.isGranted ==
                true;

        setState(() {
          _permissionsGranted = newPermissionsGranted;
        });

        if (newPermissionsGranted) {
          _updateStatus(
            "Разрешения получены!",
            Icons.check_circle,
            Colors.green,
          );

          if (_bluetoothEnabled) {
            await Future.delayed(const Duration(seconds: 1));
            _startScanning();
          }
        } else {
          _updateStatus(
            "Разрешения не получены. Нажмите ещё раз или предоставьте разрешения в настройках",
            Icons.warning,
            Colors.orange,
          );
        }
      } else if (Platform.isIOS) {
        var status = await Permission.bluetooth.request();
        final newPermissionsGranted = status.isGranted;

        setState(() {
          _permissionsGranted = newPermissionsGranted;
        });

        if (newPermissionsGranted) {
          _updateStatus(
            "Разрешения получены!",
            Icons.check_circle,
            Colors.green,
          );

          if (_bluetoothEnabled) {
            await Future.delayed(const Duration(seconds: 1));
            _startScanning();
          }
        } else {
          _updateStatus(
            "Разрешения не получены. Нажмите ещё раз или предоставьте разрешения в настройках",
            Icons.warning,
            Colors.orange,
          );
        }
      }
    } catch (e) {
      _updateStatus(
        "Ошибка запроса разрешений: ${e.toString()}",
        Icons.error,
        Colors.red,
      );
    }
  }

  void _updateStatus(
    String message,
    IconData icon,
    Color color,
  ) {
    if (mounted) {
      setState(() {
        _statusMessage = message;
        _statusIcon = icon;
        _statusColor = color;
      });
    }
  }

  Future<void> _startScanning() async {
    _updateStatus(
      "Поиск кардиографа...",
      Icons.search,
      Colors.blue,
    );

    setState(() {
      _connectionState = ConnectionState.active;
      _devices.clear();
    });

    // Обработчик результатов сканирования
    StreamSubscription<List<ScanResult>>? scanSubscription;
    scanSubscription = FlutterBluePlus.scanResults.listen((
      results,
    ) {
      if (!mounted) return;

      Set<BluetoothDevice> newDevices = {};
      for (var result in results) {
        final device = result.device;
        final advData = result.advertisementData;

        if (device.platformName == "BT05" ||
            advData.advName == "BT05") {
          newDevices.add(device);
        }
      }

      if (mounted) {
        setState(() {
          _devices = newDevices.toList();
        });
      }
    });

    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        withServices: [Guid(ecgServiceUuid)],
      );

      Timer(const Duration(seconds: 15), () async {
        await scanSubscription?.cancel();
        await FlutterBluePlus.stopScan();

        if (mounted && _devices.isEmpty) {
          _updateStatus(
            "Устройства не найдены",
            Icons.search_off,
            Colors.blue,
          );
        }
      });
    } catch (e) {
      _updateStatus(
        "Ошибка запуска сканирования: ${e.toString()}",
        Icons.error,
        Colors.red,
      );
    }
  }

  Future<void> _stopScanning() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      debugPrint("Ошибка остановки сканирования: $e");
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    _updateStatus(
      "Подключение к ${device.platformName}...",
      Icons.bluetooth_searching,
      Colors.orange,
    );

    setState(() {
      _connectionState = ConnectionState.waiting;
      _selectedDevice = device;
    });

    try {
      await _stopScanning();
      await device.connect(timeout: const Duration(seconds: 10));

      _updateStatus(
        "Подключено к ${device.platformName}",
        Icons.bluetooth_connected,
        Colors.green,
      );

      setState(() {
        _connectionState = ConnectionState.done;
      });

      // Переходим на экран ЭКГ
      _connectionTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => EcgScreen(device: device),
          ),
        );
      });
    } catch (e) {
      _updateStatus(
        "Ошибка подключения: ${e.toString()}",
        Icons.error,
        Colors.red,
      );

      setState(() {
        _connectionState = ConnectionState.none;
      });

      // Перезапускаем сканирование
      _startScanning();
    }
  }

  Widget _deviceList() {
    if (_devices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            // mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _connectionState == ConnectionState.active
                    ? "Поиск кардиографа..."
                    : "Устройства не найдены",
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              if (!_bluetoothEnabled)
                ElevatedButton.icon(
                  icon: const Icon(Icons.bluetooth),
                  label: const Text("Включить Bluetooth"),
                  onPressed: () => openAppSettings(),
                ),
              if (!_permissionsGranted)
                ElevatedButton.icon(
                  icon: const Icon(Icons.settings),
                  label: const Text("Запросить разрешения"),
                  onPressed: _requestPermissions,
                ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text("Повторить сканирование"),
                onPressed: _startScanning,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _devices.length,
      itemBuilder: (context, index) {
        final device = _devices[index];
        final isConnecting =
            _selectedDevice?.remoteId == device.remoteId &&
            _connectionState == ConnectionState.waiting;
        final isConnected =
            _selectedDevice?.remoteId == device.remoteId &&
            _connectionState == ConnectionState.done;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            leading: const Icon(Icons.heart_broken),
            title: Text(
              device.platformName.isNotEmpty
                  ? device.platformName
                  : "Неизвестное устройство",
            ),
            subtitle: Text(
              isConnected
                  ? "Подключено"
                  : isConnecting
                  ? "Подключение..."
                  : "Нажмите для подключения",
              style: TextStyle(
                color: isConnected
                    ? Colors.green
                    : isConnecting
                    ? Colors.orange
                    : Colors.grey,
              ),
            ),
            trailing: isConnected
                ? const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                  )
                : isConnecting
                ? const CircularProgressIndicator()
                : null,
            onTap: isConnected || isConnecting
                ? null
                : () => _connectToDevice(device),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _stopScanning();
    _connectionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Подключение к кардиографу",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Статусная панель
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    _statusIcon,
                    size: 50,
                    color: _statusColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _statusMessage,
                    style: TextStyle(
                      fontSize: 18,
                      color: _statusColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_connectionState == ConnectionState.done)
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 3.0, end: 0.0),
                      duration: const Duration(seconds: 3),
                      builder: (context, value, _) {
                        return Text(
                          "Запуск через ${value.toInt()} сек...",
                          style: const TextStyle(
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Список устройств
            Expanded(child: _deviceList()),
          ],
        ),
      ),
    );
  }
}
