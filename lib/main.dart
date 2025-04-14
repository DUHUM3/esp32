import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Employee Attendance',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: AttendancePage(),
    );
  }
}

class AttendancePage extends StatefulWidget {
  @override
  _AttendancePageState createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  BluetoothDevice? _device;
  String attendanceStatus = "Initializing...";
  bool isScanning = false;
  bool isConnected = false;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _stateSubscription;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    try {
      // Request Bluetooth permissions
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      bool allGranted = statuses.values.every((status) => status.isGranted);

      if (allGranted) {
        _initializeBluetooth();
      } else {
        setState(() {
          attendanceStatus = "Please grant all required permissions";
        });
      }
    } catch (e) {
      setState(() {
        attendanceStatus = "Permission error: ${e.toString()}";
      });
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _stateSubscription?.cancel();
    _disconnectDevice();
    super.dispose();
  }

  Future<void> _initializeBluetooth() async {
    try {
      // Check if Bluetooth is available
      bool isAvailable = await FlutterBluePlus.isSupported;
      if (!isAvailable) {
        setState(() => attendanceStatus = "Bluetooth is not available");
        return;
      }

      // Check if Bluetooth is on
      bool isOn = await FlutterBluePlus.isOn;
      if (!isOn) {
        setState(() => attendanceStatus = "Please turn on Bluetooth");
        return;
      }

      _startScanning();
    } catch (e) {
      setState(() => attendanceStatus = "Error: ${e.toString()}");
    }
  }

  void _startScanning() {
    setState(() {
      isScanning = true;
      attendanceStatus = "Scanning for devices...";
    });

    _scanSubscription?.cancel();
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult result in results) {
        if (result.device.platformName == "ESP32_Device") {
          _stopScanning();
          _connectToDevice(result.device);
          break;
        }
      }
    }, onError: (error) {
      setState(() {
        isScanning = false;
        attendanceStatus = "Scan error: ${error.toString()}";
      });
    });

    FlutterBluePlus.startScan(timeout: Duration(seconds: 4));
  }

  void _stopScanning() {
    FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
    setState(() => isScanning = false);
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      setState(() {
        _device = device;
        attendanceStatus = "Connecting...";
      });

      // Listen to device connection state
      _stateSubscription = device.connectionState.listen((state) {
        setState(() {
          isConnected = state == BluetoothConnectionState.connected;
          if (isConnected) {
            attendanceStatus = "Connected";
            _discoverServices();
          } else {
            attendanceStatus = "Disconnected";
          }
        });
      });

      await device.connect(timeout: Duration(seconds: 5));
    } catch (e) {
      setState(() => attendanceStatus = "Connection error: ${e.toString()}");
    }
  }

  Future<void> _discoverServices() async {
    try {
      List<BluetoothService> services = await _device!.discoverServices();

      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.read) {
            List<int> value = await characteristic.read();
            setState(() {
              attendanceStatus = String.fromCharCodes(value);
            });
          }
        }
      }
    } catch (e) {
      setState(
          () => attendanceStatus = "Service discovery error: ${e.toString()}");
    }
  }

  Future<void> _disconnectDevice() async {
    try {
      await _device?.disconnect();
    } catch (e) {
      print("Disconnection error: ${e.toString()}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Employee Attendance'),
        actions: [
          IconButton(
            icon: Icon(isScanning ? Icons.stop : Icons.refresh),
            onPressed: isScanning ? _stopScanning : _startScanning,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              attendanceStatus,
              style: TextStyle(fontSize: 24),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            if (isConnected)
              ElevatedButton(
                onPressed: _disconnectDevice,
                child: Text('Disconnect'),
              ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _checkPermissions,
              child: Text('Check Permissions'),
            ),
          ],
        ),
      ),
    );
  }
}
