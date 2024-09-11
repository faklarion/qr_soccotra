import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Table Selector',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const TableGridScreen(),
    );
  }
}

class TableGridScreen extends StatefulWidget {
  const TableGridScreen({super.key});

  @override
  _TableGridScreenState createState() => _TableGridScreenState();
}

class _TableGridScreenState extends State<TableGridScreen> {
  String _selectedImage = ''; // Menyimpan path gambar yang dipilih
  BlueThermalPrinter printer = BlueThermalPrinter.instance;
  BluetoothDevice? _selectedDevice;
  List<BluetoothDevice> _devices = [];

  @override
  void initState() {
    super.initState();
    _getBluetoothDevices();
  }

  Future<void> _getBluetoothDevices() async {
    try {
      List<BluetoothDevice> devices = await printer.getBondedDevices();
      setState(() {
        _devices = devices;
      });
    } catch (e) {
      print("Error getting devices: $e");
    }
  }

  Future<void> _connectToPrinter(BluetoothDevice device) async {
    try {
      await printer.connect(device);
      setState(() {
        _selectedDevice = device;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected to ${device.name}')),
      );
    } catch (e) {
      print("Error connecting to device: $e");
      _showErrorDialog('Failed to connect to the printer. Please try again.');
    }
  }

  Future<void> _printImage() async {
    if (_selectedDevice == null) {
      _showErrorDialog('Please select a printer first.');
      return;
    }

    try {
      bool? isConnected = await printer.isConnected;
      if (isConnected == true) {
        // Load gambar dari assets untuk logo
        String logoFilePath = 'assets/images/soccotra.png';
        ByteData logoImageBytes = await rootBundle.load(logoFilePath);
        Uint8List logoImageData = logoImageBytes.buffer.asUint8List();

        // Load gambar dari assets untuk table
        String filePath =
            'assets/images/qr_meja_soccotra-cafe-restaurant_table-$_selectedImage.png';
        ByteData imageBytes = await rootBundle.load(filePath);
        Uint8List imageData = imageBytes.buffer.asUint8List();

        // Mengubah gambar menjadi image.Image
        img.Image? logoImage = img.decodeImage(logoImageData);
        img.Image? tableImage = img.decodeImage(imageData);

        if (logoImage != null && tableImage != null) {
          // Mengubah ukuran gambar logo menjadi sesuai (opsional)
          img.Image resizedLogoImage = img.copyResize(logoImage,
              width: 200); // Contoh ukuran, sesuaikan jika perlu

          // Mengubah ukuran gambar table menjadi dua kali lipat
          img.Image resizedTableImage = img.copyResize(tableImage,
              width: (tableImage.width * 2).toInt(),
              height: (tableImage.height * 2).toInt());

          // Mengonversi gambar yang telah diresize ke format yang bisa dicetak
          List<int> logoBytes = img.encodePng(resizedLogoImage);
          List<int> tableBytes = img.encodePng(resizedTableImage);

          // Mulai mencetak
          printer.printNewLine();
          printer.printImageBytes(Uint8List.fromList(logoBytes));
          printer.printNewLine(); // Mencetak logo
          printer.printCustom('Table : $_selectedImage', 0, 1); // Header
          await printer.printImageBytes(Uint8List.fromList(
              tableBytes)); // Mencetak gambar table yang diperbesar
          printer.printNewLine();
          printer.printCustom('Scan to Order Menu', 0, 1); // Footer
          printer.printNewLine();
          printer.paperCut(); // Memotong kertas (jika printer mendukung)
        } else {
          _showErrorDialog('Failed to load images.');
        }
      }
    } catch (e) {
      print("Error printing: $e");
      _showErrorDialog('Failed to print. Please try again.');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showDeviceSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Printer'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _devices.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_devices[index].name ?? 'Unknown Device'),
                  subtitle: Text(_devices[index].address.toString()),
                  onTap: () {
                    _connectToPrinter(_devices[index]);
                    Navigator.of(context).pop(); // Menutup dialog
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(
                    top: 5.0), // Tambahkan padding jika diperlukan
                child: Image.asset(
                  'assets/images/soccotra_logo.png',
                  height: 30, // Sesuaikan ukuran logo
                ),
              ),
            ),
            Positioned(
              right: 0,
              child: IconButton(
                icon: Image.asset(
                  'assets/images/connect.png',
                  width: 16,
                  height: 16,
                ),
                onPressed: _devices.isNotEmpty
                    ? _showDeviceSelectionDialog
                    : () {
                        _showErrorDialog(
                            'No devices found. Please pair your printer.');
                      },
              ),
            ),
          ],
        ),
        centerTitle: true, // Ini menjaga agar posisi title di tengah.
      ),
      body: Column(
        children: [
          // Bagian untuk menampilkan gambar dengan background di atas grid table
          Expanded(
            flex: 3, // Atur flex sesuai kebutuhan
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/bg.jpg', // Gambar background
                    fit: BoxFit.cover,
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _selectedImage.isEmpty
                          ? const Text('Select a table to see the image')
                          : Image.asset(
                              'assets/images/qr_meja_soccotra-cafe-restaurant_table-$_selectedImage.png',
                            ),
                      const SizedBox(
                          height:
                              20), // Jarak antara gambar QR dan tombol print
                      if (_selectedImage.isNotEmpty)
                        ElevatedButton(
                          onPressed: () async {
                            await _printImage();
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 40, vertical: 20),
                            textStyle: const TextStyle(fontSize: 16),
                          ),
                          child: Column(
                            children: [
                              const Text('Print'),
                              Text('Table $_selectedImage'),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                // Teks "Table Selector" di bawah tombol print dan di atas grid table
                const Positioned(
                  bottom:
                      0, // Posisikan di bagian bawah dari stack (di atas grid)
                  left: 16, // Jarak dari kiri
                  child: Text(
                    'Table Selector',
                    style: TextStyle(
                      color: Colors.white, // Warna teks putih
                      fontSize: 18, // Ukuran font
                      fontWeight: FontWeight.bold, // Font tebal
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Grid untuk tombol-tombol
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4, // Empat tombol per baris
                  crossAxisSpacing: 16.0, // Jarak horizontal antar tombol
                  mainAxisSpacing: 16.0, // Jarak vertikal antar tombol
                  childAspectRatio: 1, // Perbandingan aspek tombol
                ),
                itemCount: 55, // Total tombol (4 VIP + 51 biasa)
                itemBuilder: (context, index) {
                  bool isVIP = index < 4; // Tabel VIP untuk index 0-3
                  int tableNumber = index + 1; // Nomor tabel mulai dari 1

                  return ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedImage = tableNumber.toString();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isVIP
                          ? Colors.amber
                          : Colors.lightBlueAccent, // Warna tombol
                      padding: const EdgeInsets.all(16.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15.0),
                      ),
                    ),
                    child: Text(
                      isVIP ? 'VIP $tableNumber' : 'Table $tableNumber',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
