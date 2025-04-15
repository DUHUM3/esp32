import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

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
  bool isCheckedIn = false;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _stateSubscription;
  Timer? _attendanceTimer;
  Duration _attendanceDuration = Duration.zero;
  DateTime? _checkInTime;
  DateTime? _checkOutTime;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _stateSubscription?.cancel();
    _attendanceTimer?.cancel();
    _disconnectDevice();
    super.dispose();
  }

  void _startTimer() {
    _attendanceTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _attendanceDuration += Duration(seconds: 1);
      });
    });
  }

  void _stopTimer() {
    _attendanceTimer?.cancel();
    _attendanceDuration = Duration.zero;
  }

  Future<void> _checkPermissions() async {
    try {
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

  Future<void> _initializeBluetooth() async {
    try {
      bool isAvailable = await FlutterBluePlus.isSupported;
      if (!isAvailable) {
        setState(() => attendanceStatus = "Bluetooth is not available");
        return;
      }

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

      _stateSubscription = device.connectionState.listen((state) {
        setState(() {
          isConnected = state == BluetoothConnectionState.connected;
          if (isConnected) {
            attendanceStatus = "Connected";
            _showCheckInSuccess();
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

  void _showCheckInSuccess() {
    _checkInTime = DateTime.now();
    _startTimer();
    setState(() {
      isCheckedIn = true;
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Success'),
        content: Text('Check-in Successful!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _checkOut() {
    _checkOutTime = DateTime.now();
    _stopTimer();
    setState(() {
      isCheckedIn = false;
    });

    // Here you would typically save the attendance record to a database
    _saveAttendanceRecord();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Check-out Complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Check-out Time: ${DateFormat('HH:mm:ss').format(_checkOutTime!)}'),
            Text('Duration: ${_formatDuration(_attendanceDuration)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  void _saveAttendanceRecord() {
    // TODO: Implement database storage
    print('Saving attendance record:');
    print(
        'Check-in: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(_checkInTime!)}');
    print(
        'Check-out: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(_checkOutTime!)}');
    print('Duration: ${_formatDuration(_attendanceDuration)}');
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
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 40),
            if (isConnected && isCheckedIn)
              Column(
                children: [
                  Text(
                    'Attendance Duration:',
                    style: TextStyle(fontSize: 18),
                  ),
                  Text(
                    _formatDuration(_attendanceDuration),
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            SizedBox(height: 40),
            if (isConnected)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!isCheckedIn)
                    ElevatedButton.icon(
                      onPressed: () => _showCheckInSuccess(),
                      icon: Icon(Icons.login),
                      label: Text('Check-in'),
                      style: ElevatedButton.styleFrom(
                        padding:
                            EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                    ),
                  if (isCheckedIn)
                    ElevatedButton.icon(
                      onPressed: _checkOut,
                      icon: Icon(Icons.logout),
                      label: Text('Check-out'),
                      style: ElevatedButton.styleFrom(
                        padding:
                            EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        backgroundColor: Colors.red,
                      ),
                    ),
                ],
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
