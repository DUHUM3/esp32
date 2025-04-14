import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
  String attendanceStatus = "Loading...";

  FlutterBlue flutterBlue = FlutterBlue.instance;

  @override
  void initState() {
    super.initState();
    _scanForDevices();
  }

  void _scanForDevices() {
    flutterBlue.scan().listen((scanResult) {
      if (scanResult.device.name == "ESP32_Device") {
        setState(() {
          _device = scanResult.device;
        });
        _connectToDevice();
      }
    });
  }

  void _connectToDevice() async {
    await _device?.connect();
    _device?.discoverServices().then((services) {
      services.forEach((service) {
        var characteristics = service.characteristics;
        characteristics.forEach((characteristic) {
          if (characteristic.properties.read) {
            characteristic.read().then((value) {
              setState(() {
                attendanceStatus = String.fromCharCodes(value);
              });
            });
          }
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Employee Attendance')),
      body: Center(
        child: Text(
          attendanceStatus,
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
