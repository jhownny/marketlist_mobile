import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController controller = MobileScannerController(
    formats: [BarcodeFormat.ean13, BarcodeFormat.ean8],
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  // --- A TRAVA ---
  bool _jaDetectou = false; 

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scanWindow = Rect.fromCenter(
      center: Offset(MediaQuery.of(context).size.width / 2, MediaQuery.of(context).size.height / 2),
      width: 280,
      height: 150,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear Produto'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            scanWindow: scanWindow,
            onDetect: (capture) {
              // Verificamos se já detectamos algo nesta sessão
              if (_jaDetectou) return; 

              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final String code = barcodes.first.rawValue ?? "";
                if (code.isNotEmpty) {
                  // Ativamos a trava imediatamente
                  _jaDetectou = true; 
                  
                  // Paramos o controlador para garantir que a câmera pare de processar
                  controller.stop(); 
                  Navigator.pop(context, code);
                }
              }
            },
          ),
          _buildHUD(scanWindow), 
        ],
      ),
    );
  }

  Widget _buildHUD(Rect scanWindow) {
     return Stack(
       children: [
          ColorFiltered(
            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.srcOut),
            child: Stack(
              children: [
                Container(color: Colors.black),
                Center(
                  child: Container(
                    width: scanWindow.width,
                    height: scanWindow.height,
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: Container(
              width: scanWindow.width,
              height: scanWindow.height,
              decoration: BoxDecoration(border: Border.all(color: Colors.green, width: 3), borderRadius: BorderRadius.circular(12)),
            ),
          ),
       ],
     );
  }
}