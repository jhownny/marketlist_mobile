import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'login_screen.dart'; 

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _carregando = true;
  String _erro = '';
  
  double _totalGastoMes = 0.0;
  List<dynamic> _gastosPorGrupo = [];
  List<dynamic> _periodosDisponiveis = [];

  int _mesSelecionado = DateTime.now().month;
  int _anoSelecionado = DateTime.now().year;

  final List<String> _nomesMeses = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
  ];

  final List<Color> _coresGrafico = [
    const Color(0xFF2196F3), 
    const Color(0xFFE57373), 
    Colors.green.shade400,
    Colors.orange.shade400, 
    Colors.purple.shade400, 
    Colors.teal.shade400,
  ];

  @override
  void initState() {
    super.initState();
    _carregarDadosDashboard();
  }

  Future<void> _carregarDadosDashboard() async {
    setState(() {
      _carregando = true;
      _erro = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final tokenJwt = prefs.getString('jwt_token') ?? '';
      
      if (tokenJwt.isEmpty) {
        _fazerLogout();
        return;
      }

      final baseUrl = dotenv.env['API_URL'] ?? '';
      final apiKey = dotenv.env['API_KEY'] ?? '';

      final urlFiltro = Uri.parse('$baseUrl/dashboard?mes=$_mesSelecionado&ano=$_anoSelecionado');

      final response = await http.get(
        urlFiltro,
        headers: {'Content-Type': 'application/json', 'x-api-key': apiKey, 'Authorization': 'Bearer $tokenJwt'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final dados = jsonDecode(response.body);
        setState(() {
          _totalGastoMes = double.tryParse(dados['total_gasto_mes'].toString()) ?? 0.0;
          _gastosPorGrupo = dados['grafico_pizza'] is List ? dados['grafico_pizza'] : [];
          _periodosDisponiveis = dados['periodos_disponiveis'] is List ? dados['periodos_disponiveis'] : [];
          _carregando = false;
        });
      } else if (response.statusCode == 401) {
        _fazerLogout();
      } else {
        throw Exception('Erro ao carregar dados do servidor.');
      }
    } catch (e) {
      setState(() {
        _erro = 'Não foi possível carregar o dashboard. Verifique sua conexão.';
        _carregando = false;
      });
    }
  }

  void _fazerLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
  }

  void _exibirFiltroDeData() {
    if (_periodosDisponiveis.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum dado financeiro para filtrar ainda.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.orange),
      );
      return;
    }

    String periodoSelecionadoTemp = "$_mesSelecionado-$_anoSelecionado";

    bool existe = _periodosDisponiveis.any((p) => "${p['mes']}-${p['ano']}" == periodoSelecionadoTemp);
    if (!existe && _periodosDisponiveis.isNotEmpty) {
      periodoSelecionadoTemp = "${_periodosDisponiveis[0]['mes']}-${_periodosDisponiveis[0]['ano']}";
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [Icon(Icons.calendar_month, color: Colors.green), SizedBox(width: 10), Text('Histórico')],
              ),
              content: DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Período disponível',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                value: periodoSelecionadoTemp,
                items: _periodosDisponiveis.map((periodo) {
                  int m = periodo['mes'];
                  int a = periodo['ano'];
                  String nomeBonito = "${_nomesMeses[m - 1]} de $a";
                  
                  return DropdownMenuItem(value: "$m-$a", child: Text(nomeBonito));
                }).toList(),
                onChanged: (novoValor) {
                  if (novoValor != null) setDialogState(() => periodoSelecionadoTemp = novoValor);
                },
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    final partes = periodoSelecionadoTemp.split('-');
                    setState(() {
                      _mesSelecionado = int.parse(partes[0]);
                      _anoSelecionado = int.parse(partes[1]);
                    });
                    _carregarDadosDashboard(); 
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: const Text('Aplicar'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Widget _buildNeutralIconContainer(IconData icon, {Color? color}) {
    final onBackgroundColor = Theme.of(context).colorScheme.onBackground;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: onBackgroundColor.withOpacity(0.06), 
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Icon(icon, color: color ?? onBackgroundColor.withOpacity(0.7), size: 18),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onBackgroundColor = theme.colorScheme.onBackground;
    final surfaceColor = theme.colorScheme.surface;
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 70,
        elevation: 8, 
        shadowColor: Colors.black.withOpacity(0.4), 
        backgroundColor: Colors.green.shade600, 
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(25),
          ),
        ),
        title: const Text(
          'Dashboard Financeiro', 
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(top: 15, bottom: 15, right: 16),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: IconButton(
              icon: const Icon(Icons.filter_alt, size: 20),
              tooltip: 'Filtrar por Mês',
              onPressed: _exibirFiltroDeData, 
            ),
          )
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : _erro.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 60),
                      const SizedBox(height: 10),
                      Text(_erro, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(onPressed: _carregarDadosDashboard, icon: const Icon(Icons.refresh), label: const Text('Tentar Novamente'))
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _carregarDadosDashboard,
                  color: Colors.green,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24.0),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.grey.shade900 : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text('Total Gasto (${_nomesMeses[_mesSelecionado - 1]} de $_anoSelecionado)', style: TextStyle(fontSize: 14, color: onBackgroundColor.withOpacity(0.6), fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Text(
                              'R\$ ${_totalGastoMes.toStringAsFixed(2)}',
                              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: onBackgroundColor),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 30),

                      if (_gastosPorGrupo.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Text('Nenhum gasto registrado em ${_nomesMeses[_mesSelecionado - 1]}.', style: TextStyle(color: onBackgroundColor.withOpacity(0.6))),
                          ),
                        )
                      else ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text('Gastos por Grupo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: onBackgroundColor)),
                        ),
                        const SizedBox(height: 20),

                        SizedBox(
                          height: 220,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 45,
                              sections: List.generate(_gastosPorGrupo.length, (index) {
                                final grupo = _gastosPorGrupo[index];
                                final valor = double.tryParse(grupo['total'].toString()) ?? 0.0;
                                final cor = _coresGrafico[index % _coresGrafico.length];
                                final porcentagem = (valor / _totalGastoMes) * 100;

                                return PieChartSectionData(
                                  color: cor,
                                  value: valor,
                                  title: '${porcentagem.toStringAsFixed(1)}%',
                                  radius: 55, // Espessura do anel menor
                                  titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                );
                              }),
                            ),
                            swapAnimationDuration: const Duration(milliseconds: 800),
                            swapAnimationCurve: Curves.easeInOut,
                          ),
                        ),

                        const SizedBox(height: 30),

                        Container(
                          padding: const EdgeInsets.all(20.0),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: List.generate(_gastosPorGrupo.length, (index) {
                              final grupo = _gastosPorGrupo[index];
                              final valor = double.tryParse(grupo['total'].toString()) ?? 0.0;
                              final cor = _coresGrafico[index % _coresGrafico.length];

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  children: [
                                    _buildNeutralIconContainer(Icons.shopping_bag_rounded, color: cor),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(grupo['grupo'] ?? 'Desconhecido', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: onBackgroundColor)),
                                    ),
                                    Text('R\$ ${valor.toStringAsFixed(2)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: onBackgroundColor)),
                                  ],
                                ),
                              );
                            }),
                          ),
                        )
                      ],
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
    );
  }
}