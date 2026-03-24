import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoricoScreen extends StatefulWidget {
  final int grupoId;
  final String nomeGrupo;

  const HistoricoScreen({super.key, required this.grupoId, required this.nomeGrupo});

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  // Controles de estado para a Rolagem Infinita
  bool _carregandoInicial = true;
  bool _carregandoMais = false;
  bool _temMaisDados = true;
  String _erro = '';
  int _paginaAtual = 1;

  Map<String, List<dynamic>> _comprasAgrupadas = {};
  
  // O Sensor que detecta a posição do dedo na tela
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _buscarHistorico();
    
    // Liga o sensor de rolagem
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
    _scrollController.dispose(); // Desliga o sensor ao fechar a tela para poupar memória
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
        
        // Se a API não mandou nada, significa que não tem mais compras no passado
        if (dados.isEmpty) {
          setState(() {
            _temMaisDados = false;
            _carregandoInicial = false;
            _carregandoMais = false;
          });
          return;
        }

        // Agrupa os itens recém-chegados
        Map<String, List<dynamic>> novosAgrupados = {};
        for (var item in dados) {
          String dataRaw = item['data_finalizacao'] ?? 'Data Desconhecida';
          if (!novosAgrupados.containsKey(dataRaw)) novosAgrupados[dataRaw] = [];
          novosAgrupados[dataRaw]!.add(item);
        }

        setState(() {
          // Adiciona os novos recibos aos recibos que já estavam na tela
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
      } else {
        throw Exception('Erro na API');
      }
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onBackgroundColor = theme.colorScheme.onBackground;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, // Fundo adaptável
      appBar: AppBar(
        title: Text('Histórico: ${widget.nomeGrupo}', style: const TextStyle(fontSize: 18)),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _carregandoInicial
          ? const Center(child: CircularProgressIndicator())
          : _erro.isNotEmpty
              ? Center(child: Text(_erro, style: const TextStyle(color: Colors.red)))
              : _comprasAgrupadas.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long, size: 80, color: onBackgroundColor.withOpacity(0.3)), // Ícone adaptável
                          const SizedBox(height: 10),
                          Text('Nenhuma compra finalizada aqui.', style: TextStyle(color: onBackgroundColor.withOpacity(0.6), fontSize: 16)), // Texto adaptável
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
    final mutedColor = isDark ? Colors.grey[600] : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: paperColor,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 3)),
        ],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Text('MARKETLIST S/A', style: TextStyle(fontFamily: 'Courier', fontSize: 16, fontWeight: FontWeight.bold, color: textColor))),
          Center(child: Text('CUPOM FISCAL NÃO OFICIAL', style: TextStyle(fontFamily: 'Courier', fontSize: 12, color: textColor))),
          const SizedBox(height: 10),
          Text('DATA: ${_formatarData(data)}', style: TextStyle(fontFamily: 'Courier', fontSize: 12, color: textColor)),
          const SizedBox(height: 10),
          Text('----------------------------------------', style: TextStyle(fontFamily: 'Courier', fontSize: 12, color: mutedColor)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('PRODUTO', style: TextStyle(fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
              Text('VALOR', style: TextStyle(fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
            ],
          ),
          Text('----------------------------------------', style: TextStyle(fontFamily: 'Courier', fontSize: 12, color: mutedColor)),
          const SizedBox(height: 5),
          
          ...itens.map((item) {
            String nome = item['produto'] ?? 'Item';
            double preco = double.tryParse(item['preco'].toString()) ?? 0.0;
            if (nome.length > 20) nome = '${nome.substring(0, 20)}...'; 

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(nome.toUpperCase(), style: TextStyle(fontFamily: 'Courier', fontSize: 12, color: textColor)),
                  _construirPontilhado(context),
                  Text('R\$ ${preco.toStringAsFixed(2)}', style: TextStyle(fontFamily: 'Courier', fontSize: 12, color: textColor)),
                ],
              ),
            );
          }),
          
          const SizedBox(height: 5),
          Text('----------------------------------------', style: TextStyle(fontFamily: 'Courier', fontSize: 12, color: mutedColor)),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TOTAL:', style: TextStyle(fontFamily: 'Courier', fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
              Text('R\$ ${total.toStringAsFixed(2)}', style: TextStyle(fontFamily: 'Courier', fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
            ],
          ),
          const SizedBox(height: 20),
          Center(child: Text('VOLTE SEMPRE!', style: TextStyle(fontFamily: 'Courier', fontSize: 12, color: textColor))),
          Center(child: Text('***', style: TextStyle(fontFamily: 'Courier', fontSize: 12, color: textColor))),
        ],
      ),
    );
  }

  Widget _construirPontilhado(BuildContext context) {
    // Se for modo escuro os pontinhos ficam mais escuros
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dotColor = isDark ? Colors.grey[700] : Colors.grey[400];

    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final boxWidth = constraints.constrainWidth();
          const dashWidth = 2.0; 
          const dashSpace = 4.0; 
          final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();

          return Padding(
            padding: const EdgeInsets.only(bottom: 3.0, left: 4.0, right: 4.0),
            child: Flex(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              direction: Axis.horizontal,
              children: List.generate(dashCount, (_) {
                return Container(
                  width: dashWidth,
                  height: 2.0,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }

}