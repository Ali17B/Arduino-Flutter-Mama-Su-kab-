import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class BluetoothManager {
  BluetoothConnection? connection;

  Future<List<BluetoothDevice>> getBondedDevices() async {
    //Bu fonksiyon eşleşmiş cihazların listesini getirir
    return await FlutterBluetoothSerial.instance.getBondedDevices();
  }

  //Bu fonksiyon eşleşmiş cihazlar arasından ismi HC-06 olan device'ın adresi ile cihaza bağlanır.
  Future<void> connectToDevice(BluetoothDevice device) async {
    connection = await BluetoothConnection.toAddress(device.address);
  }

  //Bluetooth modülünden cihaza data gönderir
  void sendData(String message) {
    if (connection != null) {
      //Kablosuz ağ iletişiminde 8 bitlik veriler gönderir
      connection!.output.add(Uint8List.fromList(utf8.encode(message + '\r\n')));
    }
  }

  //Gelen 8 bitlik datayı ayrıştırır. yani modülden datayı alır.
  Stream<Uint8List>? get onDataReceived => connection?.input;

  void dispose() {
    connection?.close();
  }
}

class PetFeederControlPage extends StatefulWidget {
  @override
  _PetFeederControlPageState createState() => _PetFeederControlPageState();
}

class _PetFeederControlPageState extends State<PetFeederControlPage> {
  final bluetoothManager = BluetoothManager();
  bool isConnected = false;
  String suSeviyesi = 'Bilinmiyor';

  @override
  void initState() {
    //uygulama başladığında cihaza bağlanır.
    super.initState();
    _connectToBluetoothDevice();
  }

  String suSeviyesiIsleme(int suSeviyesi) {
    if (suSeviyesi < 80) {
      return 'Su kabı az derecede dolu';
    } else if (suSeviyesi < 150) {
      return 'Su kabı orta derecede dolu';
    } else {
      return 'Su kabı dolu';
    }
  }


  //HC-06 cihazına bağlanır ve veri alımını dinler.
  void _connectToBluetoothDevice() async {
    List<BluetoothDevice> devices = await bluetoothManager.getBondedDevices();
    try {
      BluetoothDevice hc06 =
          devices.firstWhere((device) => device.name == 'HC-06');
      await bluetoothManager.connectToDevice(hc06);
      bluetoothManager.onDataReceived?.listen((data) {
        String receivedData = utf8.decode(data);
        int suSeviyesiDegeri = int.tryParse(receivedData.trim()) ?? 0;
        setState(() {
          suSeviyesi = suSeviyesiIsleme(suSeviyesiDegeri);
        });
      });

      setState(() {
        isConnected = true;
      });
    } catch (e) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Hata'),
            content: Text('Bluetooth cihazına bağlanılamadı.'),
            actions: [
              TextButton(
                child: Text('Tamam'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  //komutu Bluetooth üzerinden gönderir
  void _sendCommand(String command) {
    bluetoothManager.sendData(command);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Evcil Hayvan Mama ve Su Kabı \nKontrolü'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: isConnected ? () => _sendCommand('M') : null,
              child: Text('Mama Doldur'),
            ),
            ElevatedButton(
              onPressed: isConnected ? () => _sendCommand('S') : null,
              child: Text('Su Doldur'),
            ),
            Text('Su Seviyesi: $suSeviyesi'),
          ],
        ),
      ),
    );
  }
}
