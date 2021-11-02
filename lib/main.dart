import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Bluetooth Device Scanner'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isScanning = false;
  final List<BluetoothDevice> _devices = [];

  void _addDevice(BluetoothDevice device) {
    if (_devices.any((d) => d.id == device.id)) {
      return;
    }

    setState(() => _devices.add(device));
  }

  Future<void> _addConnectedDevices() async {
    final FlutterBlue flutterBlue = FlutterBlue.instance;

    final List<BluetoothDevice> connectedDevices =
    await flutterBlue.connectedDevices;

    for (final BluetoothDevice device in connectedDevices) {
      _addDevice(device);
    }
  }

  Future<void> _addLocalDevices() async {
    final FlutterBlue flutterBlue = FlutterBlue.instance;
    List<ScanResult> results = [];

    flutterBlue.scanResults.listen((r) {
      results = r;
    });

    await flutterBlue.startScan(
      timeout: Duration(seconds: 10),
      allowDuplicates: false,
    );

    for (final ScanResult result in results) {
      if (!result.advertisementData.connectable || result.device.name.isEmpty) {
        continue;
      }

      _addDevice(result.device);
    }
  }

  Future<void> _scanDevices() async {
    final bool isOn = await FlutterBlue.instance.isOn;
    setState(() => _devices.clear());

    if (!isOn) {
      print('Bluetooth is not enabled.');
      return;
    }

    setState(() => _isScanning = true);

    await _addConnectedDevices();
    await _addLocalDevices();

    setState(() {
      _devices.sort((a, b) => a.name.compareTo(b.name));
      _isScanning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 100.0,
              padding: EdgeInsets.symmetric(
                vertical: _isScanning ? 12.0 : 0.0,
              ),
              alignment: Alignment.center,
              child: _isScanning ? CircularProgressIndicator() : null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                _isScanning
                    ? 'Scanning...'
                    : '${_devices.length} devices found:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                children: _isScanning
                    ? []
                    : _devices.map((device) {
                  return ExpansionTile(
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Name: ${device.name}'),
                        Text('ID: ${device.id.id}'),
                      ],
                    ),
                    children: [
                      BluetoothListItem(device),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isScanning ? null : _scanDevices,
        tooltip: 'Scan',
        child: Icon(Icons.search),
      ),
    );
  }
}

class BluetoothListItem extends StatefulWidget {
  final BluetoothDevice device;

  const BluetoothListItem(this.device, {Key? key}) : super(key: key);

  @override
  _BluetoothListItemState createState() => _BluetoothListItemState();
}

class _BluetoothListItemState extends State<BluetoothListItem> {
  bool _isLoading = false;
  bool _isDisposed = false;
  List<BluetoothService> _services = [];

  @override
  void initState() {
    super.initState();
    _fetchDeviceData();
  }

  _fetchDeviceData() async {
    final BluetoothDevice _device = widget.device;

    setIsLoading(true);

    try {
      await _device.connect();
      print('connected to device');

      List<BluetoothService> services = [];

      _device.services.listen((s) {
        print('services:');
        print(s);
        services = s;
      });

      await _device.discoverServices();
      print('discovered ${services.length} services');

      for (final BluetoothService service in services) {
        addService(service);
      }
    } catch (e) {} finally {
      await _device.disconnect();
    }

    setIsLoading(false);
  }

  void addService(BluetoothService service) {
    if (_isDisposed) {
      return;
    }

    setState(() => _services.add(service));
  }

  void setIsLoading(bool isLoading) {
    if (_isDisposed) {
      return;
    }

    setState(() => _isLoading = isLoading);
  }

  List<Widget> _getChildren() {
    final List<Widget> children =
    _isLoading ? _getLoadingScreen() : _getBluetoothDetails(_services);

    return children;
  }

  @override
  void dispose() async {
    super.dispose();
    _isDisposed = true;
    await widget.device.disconnect();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _getChildren(),
    );
  }
}

List<Widget> _getBluetoothDetails(Iterable<BluetoothService> services) {
  return [
    Text(
      'Services:',
      textAlign: TextAlign.left,
    ),
    ...services.map((BluetoothService service) {
      return Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 12.0),
            Text('UUID: ${service.uuid.toString()}'),
            Text('Characteristics:'),
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: service.characteristics.map((c) {
                  return Text('* ${c.uuid.toString()}');
                }).toList(),
              ),
            ),
          ],
        ),
      );
    }).toList(),
    SizedBox(height: 12.0),
  ];
}

List<Widget> _getLoadingScreen() {
  return [
    Center(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircularProgressIndicator(),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Fetching device details...'),
          ),
        ],
      ),
    ),
  ];
}
