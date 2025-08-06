import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:kardix/pages/ecg.dart';

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
  String _statusMessage = "Поиск устройств...";
  IconData _statusIcon = Icons.search;
  Color _statusColor = Colors.blue;
  Timer? _connectionTimer;

  @override
  void initState() {
    super.initState();
    _startScanning();
  }

  @override
  void dispose() {
    _stopScanning();
    _connectionTimer?.cancel();
    super.dispose();
  }

  Future _startScanning() async {
    setState(() {
      _connectionState = ConnectionState.active;
      _statusMessage = "Поиск устройств...";
      _statusIcon = Icons.search;
      _statusColor = Colors.blue;
      _devices.clear();
    });

    FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return; // Всё еще на экране?

      setState(() {
        _devices = results
            .map((r) => r.device)
            .where(
              (device) => device.platformName.contains("BT05"),
            )
            .toList();
      });
    });

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 30),
    );
  }

  Future _stopScanning() async {
    await FlutterBluePlus.stopScan();
  }

  Future _connectToDevice(BluetoothDevice device) async {
    setState(() {
      _connectionState = ConnectionState.waiting;
      _statusMessage = "Подключение к ${device.platformName}...";
      _statusIcon = Icons.bluetooth_searching;
      _statusColor = Colors.orange;
      _selectedDevice = device;
    });

    try {
      await _stopScanning();
      await device.connect();

      setState(() {
        _connectionState = ConnectionState.done;
        _statusMessage = "Подключено к ${device.platformName}";
        _statusIcon = Icons.bluetooth_connected;
        _statusColor = Colors.green;
      });

      _connectionTimer = Timer(const Duration(seconds: 3), () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => EcgScreen()),
        );
      });
    } catch (e) {
      setState(() {
        _connectionState = ConnectionState.none;
        _statusMessage = "Ошибка при подключении.";
        _statusIcon = Icons.error;
        _statusColor = Colors.red;
      }); // Таймер?
      _startScanning();
    }
  }

  Widget _deviceList() {
    if (_devices.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(
          _connectionState == ConnectionState.active
              ? "Поиск кардиографа..."
              : "Не найдено устройств по близости.",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      children: _devices.map((device) {
        final isConnected =
            _connectionState == ConnectionState.done &&
            _selectedDevice?.remoteId == device.remoteId;
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            leading: const Icon(Icons.devices),
            title: Text(device.platformName),
            subtitle: Text(
              isConnected ? "Подключено" : "Подключиться",
              style: TextStyle(
                color: isConnected ? Colors.green : Colors.grey,
              ),
            ),
            trailing: isConnected
                ? const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                  )
                : null,
            onTap: isConnected
                ? null
                : () => _connectToDevice(device),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Подключение к устройству",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Icon(
                    _statusIcon,
                    size: 60,
                    color: _statusColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _statusMessage,
                    style: const TextStyle(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  if (_connectionState == ConnectionState.done)
                    TweenAnimationBuilder<double>(
                      builder: (context, value, _) {
                        return Text(
                          "Старт процедуры через ${value.toInt()}...",
                          style: const TextStyle(
                            color: Colors.grey,
                          ),
                        );
                      },
                      tween: Tween(begin: 3.0, end: 0.0),
                      duration: Duration(seconds: 3),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Список устройств
            const Text(
              "Доступные устройства",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(child: _deviceList()),
          ],
        ),
      ),
    );
  }
}
