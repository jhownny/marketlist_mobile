import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

class HistoricoScreen extends StatefulWidget {
  final int grupoId;
  final String nomeGrupo;

  const HistoricoScreen({super.key, required this.grupoId, required this.nomeGrupo});

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  bool _carregandoInicial = true;
  bool _carregandoMais = false;
  bool _temMaisDados = true;
  String _erro = '';
  int _paginaAtual = 1;

  Map<String, List<dynamic>> _comprasAgrupadas = {};
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _buscarHistorico();
    
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50) {
        if (!_carregandoMais && _temMaisDados) {
          _buscarHistorico(isCarregandoMais: true);
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _headersAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';
    final apiKey = dotenv.env['API_KEY'] ?? '';
    return {'Content-Type': 'application/json', 'x-api-key': apiKey, 'Authorization': 'Bearer $token'};
  }

  Future<void> _buscarHistorico({bool isCarregandoMais = false}) async {
    if (isCarregandoMais) {
      setState(() => _carregandoMais = true);
    }

    try {
      final baseUrl = dotenv.env['API_URL'] ?? '';
      final url = Uri.parse('$baseUrl/historico?grupo_id=${widget.grupoId}&pagina=$_paginaAtual');

      final headers = await _headersAuth();
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> dados = jsonDecode(response.body);
        
        if (dados.isEmpty) {
          setState(() {
            _temMaisDados = false;
            _carregandoInicial = false;
            _carregandoMais = false;
          });
          return;
        }

        Map<String, List<dynamic>> novosAgrupados = {};
        for (var item in dados) {
          String dataRaw = item['data_finalizacao'] ?? 'Data Desconhecida';
          if (!novosAgrupados.containsKey(dataRaw)) novosAgrupados[dataRaw] = [];
          novosAgrupados[dataRaw]!.add(item);
        }

        if (!mounted) return;

        setState(() {
          novosAgrupados.forEach((key, value) {
            if (_comprasAgrupadas.containsKey(key)) {
              _comprasAgrupadas[key]!.addAll(value);
            } else {
              _comprasAgrupadas[key] = value;
            }
          });

          _paginaAtual++;
          _carregandoInicial = false;
          _carregandoMais = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (!isCarregandoMais) _erro = 'Não foi possível carregar o histórico.';
        _carregandoInicial = false;
        _carregandoMais = false;
      });
    }
  }

  String _formatarData(String dataBanco) {
    if (dataBanco == 'Data Desconhecida') return dataBanco;
    try {
      DateTime dt = DateTime.parse(dataBanco);
      String dia = dt.day.toString().padLeft(2, '0');
      String mes = dt.month.toString().padLeft(2, '0');
      String ano = dt.year.toString();
      String hora = dt.hour.toString().padLeft(2, '0');
      String min = dt.minute.toString().padLeft(2, '0');
      return "$dia/$mes/$ano às $hora:$min";
    } catch (e) {
      return dataBanco;
    }
  }

  // FUNÇÃO DE COMPARTILHAR CORRIGIDA: Agora recebe a LISTA de itens e o TOTAL
  void _compartilharReciboWhatsApp(List<dynamic> itens, double total, String dataFormatada) {
    String listaProdutos = "";
    for (var item in itens) {
      final nome = item['produto'] ?? 'Item';
      final preco = double.tryParse(item['preco'].toString()) ?? 0.0;
      listaProdutos += "• ${nome.toUpperCase()} - R\$ ${preco.toStringAsFixed(2)}\n";
    }

    final String reciboTexto = 
      "🧾 *MARKETLIST S/A*\n"
      "_Cupom Fiscal Não Oficial_\n"
      "----------------------------------\n"
      "📅 *Data:* $dataFormatada\n"
      "----------------------------------\n"
      "🛒 *PRODUTOS:*\n"
      "$listaProdutos"
      "\n💰 *TOTAL: R\$ ${total.toStringAsFixed(2)}*\n"
      "----------------------------------\n"
      "_Gerado pelo App MarketList_";

    Share.share(reciboTexto);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 80,
        elevation: 8, 
        shadowColor: Colors.black.withValues(alpha: 0.4), 
        backgroundColor: Colors.green.shade600, 
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        ),
        title: Text(
          'Histórico: ${widget.nomeGrupo}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
      ),
      body: _carregandoInicial
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : _erro.isNotEmpty
              ? Center(child: Text(_erro, style: const TextStyle(color: Colors.red)))
              : _comprasAgrupadas.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long, size: 80, color: onSurface.withValues(alpha: 0.3)),
                          const SizedBox(height: 10),
                          Text('Nenhuma compra finalizada aqui.', style: TextStyle(color: onSurface.withValues(alpha: 0.6), fontSize: 16)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _comprasAgrupadas.length + (_carregandoMais ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _comprasAgrupadas.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20.0),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        String dataOriginal = _comprasAgrupadas.keys.elementAt(index);
                        List<dynamic> itensDestaCompra = _comprasAgrupadas[dataOriginal]!;
                        
                        double totalCompra = 0;
                        for (var item in itensDestaCompra) {
                          totalCompra += double.tryParse(item['preco'].toString()) ?? 0.0;
                        }

                        return _construirCupomFiscal(context, dataOriginal, itensDestaCompra, totalCompra);
                      },
                    ),
    );
  }

  Widget _construirCupomFiscal(BuildContext context, String data, List<dynamic> itens, double total) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paperColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFDFBF7);
    final textColor = isDark ? Colors.grey[300] : Colors.black87;
    final mutedColor = isDark ? Colors.grey[700] : Colors.grey[300];
    final String dataFormatada = _formatarData(data);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: paperColor,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CABEÇALHO COM BOTÃO DE COMPARTILHAR
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MARKETLIST S/A', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1, color: textColor)),
                  const Text('CUPOM FISCAL NÃO OFICIAL', style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
              // BOTÃO DE COMPARTILHAR
              IconButton(
                icon: const Icon(Icons.share_outlined, color: Colors.green, size: 24),
                onPressed: () => _compartilharReciboWhatsApp(itens, total, dataFormatada),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text('DATA: $dataFormatada', style: TextStyle(fontSize: 12, color: textColor?.withValues(alpha: 0.7))),
          const SizedBox(height: 10),
          Divider(color: mutedColor, thickness: 1),
          const SizedBox(height: 10),
          
          // LISTA DE PRODUTOS
          ...itens.map((item) {
            String nome = item['produto'] ?? 'Item';
            double preco = double.tryParse(item['preco'].toString()) ?? 0.0;
            
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Expanded(child: Text(nome.toUpperCase(), style: TextStyle(fontSize: 13, color: textColor, fontWeight: FontWeight.w500))),
                  Text('R\$ ${preco.toStringAsFixed(2)}', style: TextStyle(fontSize: 13, color: textColor, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }),
          
          const SizedBox(height: 15),
          Divider(color: mutedColor, thickness: 1),
          const SizedBox(height: 10),
          
          // TOTAL
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TOTAL:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor)),
              Text('R\$ ${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.green)),
            ],
          ),
          
          const SizedBox(height: 25),
          Center(child: Text('VOLTE SEMPRE!', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.withValues(alpha: 0.5)))),
        ],
      ),
    );
  }
}