import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FinancasScreen extends StatefulWidget {
  const FinancasScreen({super.key});

  @override
  State<FinancasScreen> createState() => _FinancasScreenState();
}

class _FinancasScreenState extends State<FinancasScreen> {
  int _mesAtual = DateTime.now().month;
  int _anoAtual = DateTime.now().year;
  bool _carregando = true;
  double _opacidadeFab = 0.4;
  
  List<dynamic> _despesas = [];
  Map<String, dynamic> _resumo = {"total_mes": 0.0, "total_pago": 0.0, "total_pendente": 0.0};

  final List<String> _mesesNomes = ['', 'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];

  @override
  void initState() {
    super.initState();
    _buscarFinancas();
  }

  Future<Map<String, String>> _headersAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';
    return {
      'Content-Type': 'application/json',
      'x-api-key': dotenv.env['API_KEY'] ?? '',
      'Authorization': 'Bearer $token',
    };
  }

  Future<void> _buscarFinancas({bool silencioso = false}) async {
    if (!silencioso) setState(() => _carregando = true);
    try {
      final baseUrl = dotenv.env['API_URL'] ?? '';
      final response = await http.get(
        Uri.parse('$baseUrl/financas?mes=$_mesAtual&ano=$_anoAtual'),
        headers: await _headersAuth(),
      );

      if (response.statusCode == 200) {
        final dados = jsonDecode(response.body);
        setState(() {
          _despesas = dados['despesas'];
          _resumo = dados['resumo'];
          _carregando = false;
        });
      } else {
        throw Exception('Erro ao buscar finanças');
      }
    } catch (e) {
      if (mounted) {
        if (!silencioso) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro de conexão'), backgroundColor: Colors.red));
        setState(() => _carregando = false);
      }
    }
  }

  Future<void> _alternarPagamento(int idDespesa) async {
    setState(() {
      final index = _despesas.indexWhere((item) => item['id'].toString() == idDespesa.toString());
      if (index != -1) {
        bool isPagoAtual = _despesas[index]['status_pago'] == true || _despesas[index]['status_pago'] == 1 || _despesas[index]['status_pago'] == '1';
        _despesas[index]['status_pago'] = !isPagoAtual; // Inverte o valor localmente
      }
    });

    try {
      final baseUrl = dotenv.env['API_URL'] ?? '';
      final response = await http.put(
        Uri.parse('$baseUrl/financas'),
        headers: await _headersAuth(),
        body: jsonEncode({"despesa_id": idDespesa, "mes": _mesAtual, "ano": _anoAtual}),
      );

      if (response.statusCode == 200) {
        _buscarFinancas(silencioso: true); 
      }
    } catch (e) {
      _buscarFinancas(silencioso: true);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao salvar pagamento'), backgroundColor: Colors.red));
    }
  }

  Future<void> _excluirDespesa(int idDespesa) async {
    try {
      final baseUrl = dotenv.env['API_URL'] ?? '';
      final response = await http.delete(
        Uri.parse('$baseUrl/financas?id=$idDespesa'),
        headers: await _headersAuth(),
      );

      if (response.statusCode == 200) {
        _buscarFinancas();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao excluir'), backgroundColor: Colors.red));
    }
  }

  Future<void> _editarDespesaNaApi(int id, String desc, String cat, double valor) async {
    try {
      final baseUrl = dotenv.env['API_URL'] ?? '';
      final response = await http.put(
        Uri.parse('$baseUrl/financas'),
        headers: await _headersAuth(),
        body: jsonEncode({
          "acao": "editar",
          "id": id,
          "descricao": desc,
          "categoria": cat,
          "valor_total": valor
        }),
      );

      if (response.statusCode == 200) {
        _buscarFinancas();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao editar na API'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro de conexão'), backgroundColor: Colors.red));
    }
  }

  void _mudarMes(int incremento) {
    setState(() {
      _mesAtual += incremento;
      if (_mesAtual > 12) { _mesAtual = 1; _anoAtual++; }
      else if (_mesAtual < 1) { _mesAtual = 12; _anoAtual--; }
    });
    _buscarFinancas();
  }

  void _exibirDialogoNovaDespesa() {
    final descController = TextEditingController();
    final catController = TextEditingController();
    final valorController = TextEditingController();
    final parcelasController = TextEditingController(text: '1');
    bool isFixa = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Nova Conta', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: descController, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Descrição (ex: Luz)', prefixIcon: Icon(Icons.description_outlined))),
                const SizedBox(height: 10),
                TextField(controller: catController, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Categoria (ex: Casa)', prefixIcon: Icon(Icons.category_outlined))),
                const SizedBox(height: 10),
                TextField(controller: valorController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor Total', prefixText: 'R\$ ', prefixIcon: Icon(Icons.monetization_on_outlined))),
                const SizedBox(height: 15),
                SwitchListTile(
                  title: const Text('Despesa Fixa Mensal?', style: TextStyle(fontWeight: FontWeight.w600)),
                  value: isFixa,
                  activeColor: Colors.blue,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setDialogState(() => isFixa = val),
                ),
                if (!isFixa)
                  TextField(controller: parcelasController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Qtd. de Parcelas (1 = à vista)', prefixIcon: Icon(Icons.format_list_numbered))),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final baseUrl = dotenv.env['API_URL'] ?? '';
                await http.post(
                  Uri.parse('$baseUrl/financas'),
                  headers: await _headersAuth(),
                  body: jsonEncode({
                    "descricao": descController.text.trim(),
                    "categoria": catController.text.trim(),
                    "valor_total": double.tryParse(valorController.text.replaceAll(',', '.')) ?? 0.0,
                    "quantidade_parcelas": isFixa ? 0 : (int.tryParse(parcelasController.text) ?? 1),
                    "data_compra": "$_anoAtual-${_mesAtual.toString().padLeft(2, '0')}-01"
                  }),
                );
                _buscarFinancas();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  void _exibirDialogoEditarDespesa(Map<String, dynamic> item) {
    final int idDespesa = int.tryParse(item['id'].toString()) ?? 0;
    final descController = TextEditingController(text: item['descricao']);
    final catController = TextEditingController(text: item['categoria']);
    final double valorTotal = double.tryParse(item['valor_total'].toString()) ?? 0.0;
    final valorController = TextEditingController(text: valorTotal.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Editar Despesa', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: descController, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Descrição', prefixIcon: Icon(Icons.edit))),
              const SizedBox(height: 10),
              TextField(controller: catController, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Categoria', prefixIcon: Icon(Icons.category_outlined))),
              const SizedBox(height: 10),
              TextField(controller: valorController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor Total', prefixText: 'R\$ ', prefixIcon: Icon(Icons.monetization_on_outlined))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              double novoValor = double.tryParse(valorController.text.replaceAll(',', '.')) ?? 0.0;
              _editarDespesaNaApi(idDespesa, descController.text.trim(), catController.text.trim(), novoValor);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Atualizar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.4),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(30))),
        title: const Text('Gestão Financeira', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        centerTitle: true,
      ),
      floatingActionButton: Listener(
        onPointerDown: (_) => setState(() => _opacidadeFab = 1.0),
        onPointerUp: (_) => setState(() => _opacidadeFab = 0.4),
        child: AnimatedOpacity(
          opacity: _opacidadeFab,
          duration: const Duration(milliseconds: 200),
          child: FloatingActionButton.extended(
            onPressed: () {
              setState(() => _opacidadeFab = 0.4);
              _exibirDialogoNovaDespesa();
            },
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Nova Conta', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          // SELETOR DE MÊS
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
            decoration: BoxDecoration(
              color: isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.blue.shade200, width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(icon: Icon(Icons.chevron_left, size: 28, color: Colors.blue.shade700), onPressed: () => _mudarMes(-1)),
                Text('${_mesesNomes[_mesAtual]} $_anoAtual', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.blue.shade700)),
                IconButton(icon: Icon(Icons.chevron_right, size: 28, color: Colors.blue.shade700), onPressed: () => _mudarMes(1)),
              ],
            ),
          ),
          
          // RESUMO DO MÊS
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCardResumo('Total Mês', _resumo['total_mes'], isDark ? Colors.grey.shade400 : Colors.grey.shade700, Icons.account_balance_wallet),
                _buildCardResumo('Pago', _resumo['total_pago'], Colors.green, Icons.check_circle_outline),
                _buildCardResumo('Pendente', _resumo['total_pendente'], Colors.red.shade400, Icons.schedule),
              ],
            ),
          ),

          // LISTA DE CONTAS
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator(color: Colors.blue))
                : _despesas.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.sentiment_satisfied_alt, size: 80, color: Colors.blue.withOpacity(0.3)),
                            const SizedBox(height: 16),
                            Text('Nenhuma conta neste mês! 🎉', style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 100), // Respiro para o botão flutuante
                        itemCount: _despesas.length,
                        itemBuilder: (context, index) {
                          final item = _despesas[index];
                          final bool isPago = item['status_pago'] == true || item['status_pago'] == 1 || item['status_pago'] == '1';
                          final int idDespesa = int.tryParse(item['id'].toString()) ?? 0;
                          
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ]
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Dismissible(
                                key: Key(idDespesa.toString()),
                                direction: DismissDirection.horizontal, 
                                background: Container(
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.only(left: 20),
                                  color: Colors.blue,
                                  child: const Icon(Icons.edit, color: Colors.white, size: 28),
                                ),
                                secondaryBackground: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  color: Colors.red,
                                  child: const Icon(Icons.delete, color: Colors.white, size: 28),
                                ),
                                confirmDismiss: (direction) async {
                                  if (direction == DismissDirection.startToEnd) {
                                    _exibirDialogoEditarDespesa(item);
                                    return false; 
                                  } else {
                                    return await showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        title: const Text('Excluir conta?'),
                                        content: const Text('Isso apagará todas as parcelas futuras desta conta.'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(context, true), 
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                            child: const Text('Excluir')
                                          ),
                                        ],
                                      )
                                    );
                                  }
                                },
                                onDismissed: (direction) => _excluirDespesa(idDespesa),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200), // Mais rápido!
                                  color: isPago ? theme.colorScheme.surface.withOpacity(0.6) : theme.colorScheme.surface,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    leading: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isPago ? Colors.grey.withOpacity(0.15) : Colors.blue.withOpacity(0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 200),
                                        switchInCurve: Curves.easeOutBack, // Dá um leve "pulo" elástico muito satisfatório
                                        switchOutCurve: Curves.easeIn,
                                        transitionBuilder: (child, animation) {
                                          return ScaleTransition(
                                            scale: animation,
                                            child: FadeTransition(
                                              opacity: animation,
                                              child: child,
                                            ),
                                          );
                                        },
                                        child: Icon(
                                          isPago ? Icons.check : Icons.attach_money_rounded,
                                          key: ValueKey(isPago),
                                          color: isPago ? Colors.grey : Colors.blue.shade700,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                    title: AnimatedDefaultTextStyle(
                                      duration: const Duration(milliseconds: 200),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800, 
                                        fontSize: 16,
                                        decoration: isPago ? TextDecoration.lineThrough : TextDecoration.none, 
                                        color: isPago ? Colors.grey : theme.colorScheme.onBackground,
                                        fontFamily: theme.textTheme.bodyLarge?.fontFamily,
                                      ),
                                      child: Text(item['descricao'].toString()),
                                    ),
                                    subtitle: AnimatedDefaultTextStyle(
                                      duration: const Duration(milliseconds: 200),
                                      style: TextStyle(
                                        color: Colors.grey.shade500, 
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                        fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                                      ),
                                      child: Text('${item['categoria']} • Parcela: ${item['info_parcela']}'),
                                    ),
                                    trailing: AnimatedDefaultTextStyle(
                                      duration: const Duration(milliseconds: 200),
                                      style: TextStyle(
                                        fontSize: 17, 
                                        fontWeight: FontWeight.w900, 
                                        color: isPago ? Colors.grey : Colors.blue.shade700,
                                        fontFamily: theme.textTheme.bodyLarge?.fontFamily,
                                      ),
                                      child: Text('R\$ ${double.tryParse(item['valor_exibicao'].toString())?.toStringAsFixed(2) ?? '0.00'}'),
                                    ),
                                    onTap: () => _alternarPagamento(idDespesa),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardResumo(String titulo, dynamic valor, Color cor, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ]
        ),
        child: Column(
          children: [
            Icon(icon, color: cor.withOpacity(0.8), size: 28),
            const SizedBox(height: 8),
            Text(titulo, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'R\$ ${double.parse(valor.toString()).toStringAsFixed(2)}', 
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: cor),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}