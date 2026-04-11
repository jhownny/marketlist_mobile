import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScannerNotaScreen extends StatefulWidget {
  final int grupoId;
  const ScannerNotaScreen({super.key, required this.grupoId});

  @override
  State<ScannerNotaScreen> createState() => _ScannerNotaScreenState();
}

class _ScannerNotaScreenState extends State<ScannerNotaScreen> {
  bool _processando = false;
  final MobileScannerController _cameraController = MobileScannerController();

  Future<void> _enviarUrlParaApi(String url) async {
    if (_processando) return; // Evita ler o mesmo código 10 vezes num segundo
    setState(() => _processando = true);
    
    // Pausa a câmera enquanto processa
    _cameraController.stop();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';
      final baseUrl = dotenv.env['API_URL'] ?? '';

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lendo cupom fiscal... Aguarde.'), backgroundColor: Colors.blue));

      final response = await http.post(
        Uri.parse('$baseUrl/itens'), // Substitua pela sua rota correta se for diferente
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': dotenv.env['API_KEY'] ?? '',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode({
          "acao": "importar_nota",
          "url": url
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final dados = jsonDecode(response.body);
        List<dynamic> itens = dados['itens'] ?? [];
        
        if (itens.isEmpty) {
          _mostrarErro("Nenhum item encontrado. O layout deste estado pode não ser suportado.");
          return;
        }

        _exibirResumoImportacao(itens);
      } else {
        _mostrarErro("Erro no servidor ao ler a nota.");
      }
    } catch (e) {
      _mostrarErro("Erro de conexão ou tempo esgotado.");
    }
  }

  void _mostrarErro(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    setState(() => _processando = false);
    _cameraController.start(); // Volta a câmera se der erro
  }

  void _exibirResumoImportacao(List<dynamic> itens) {
    double total = itens.fold(0.0, (soma, item) => soma + (item['preco'] ?? 0.0));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Cupom Encontrado!', style: TextStyle(color: Colors.green)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Detectamos ${itens.length} produtos.\nTotal: R\$ ${total.toStringAsFixed(2)}'),
              const SizedBox(height: 10),
              const Text('Deseja importar todos para a lista?', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Fecha diálogo
              Navigator.pop(context); // Volta pra tela anterior abandonando a câmera
            }, 
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, itens); // Retorna a lista de itens para a tela que chamou!
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Importar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear QR Code da Nota', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _cameraController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final code = barcode.rawValue ?? "";
                if (code.startsWith('http') && !_processando) {
                  _enviarUrlParaApi(code);
                  break;
                }
              }
            },
          ),
          // Quadrado de foco visual (Overlay)
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green, width: 3),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          if (_processando)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator(color: Colors.green)),
            ),
        ],
      ),
    );
  }
}