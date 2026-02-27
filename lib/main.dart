import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("Erro ao carregar .env: $e");
  }

  runApp(const MarketListApp());
}

class MarketListApp extends StatelessWidget {
  const MarketListApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MarketList',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const AuthCheck(),
    );
  }
}

// ==========================================================
// 1. TELA DE VERIFICAÇÃO DE LOGIN (Splash Screen invisível)
// ==========================================================
class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  @override
  void initState() {
    super.initState();
    _verificarLogin();
  }

  Future<void> _verificarLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final usuarioId = prefs.getString('usuario_id');

    if (usuarioId != null && usuarioId.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ListaComprasScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.green,
      body: Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}

// ==========================================================
// 2. TELA DE LOGIN REAL
// ==========================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  bool _carregando = false;

  Future<void> _fazerLogin() async {
    final email = _emailController.text.trim();
    final senha = _senhaController.text.trim();

    if (email.isEmpty || senha.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha e-mail e senha!')),
      );
      return;
    }

    setState(() => _carregando = true);

    try {
      final baseUrl = dotenv.env['API_URL'] ?? '';
      final apiKey = dotenv.env['API_KEY'] ?? '';

      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json', 'x-api-key': apiKey},
        body: jsonEncode({
          "email": email,
          "senha": senha,
        }),
      ).timeout(const Duration(seconds: 10));

      final resultado = jsonDecode(response.body);

      if (response.statusCode == 200 && resultado['status'] == 'logado') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('usuario_id', resultado['id'].toString());
        await prefs.setString('usuario_nome', resultado['nome'].toString());

        if (!mounted) return;
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ListaComprasScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(resultado['erro'] ?? 'E-mail ou senha inválidos'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro de conexão. Tente novamente.'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/Text-MarketList-logo2.png',
                height: 220,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 40),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          prefixIcon: Icon(Icons.email),
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: _senhaController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: Icon(Icons.lock),
                        ),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _carregando ? null : _fazerLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _carregando
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Entrar', style: TextStyle(fontSize: 18)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================================
// 3. TELA PRINCIPAL (LISTA DE COMPRAS)
// ==========================================================
class ListaComprasScreen extends StatefulWidget {
  const ListaComprasScreen({super.key});

  @override
  State<ListaComprasScreen> createState() => _ListaComprasScreenState();
}

class _ListaComprasScreenState extends State<ListaComprasScreen> {
  List<dynamic> _itens = [];
  List<dynamic> _listaGruposApi = []; 
  
  bool _carregando = true;
  bool _modoOffline = false;
  String _erro = '';

  String _usuarioId = '';
  String _nomeUsuarioAtual = '';
  int _grupoId = 0; 
  String _nomeGrupoAtual = 'Carregando...';

  @override
  void initState() {
    super.initState();
    _carregarUsuarioLocal();
    _verificarAtualizacao();
  }

  Future<void> _carregarUsuarioLocal() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _usuarioId = prefs.getString('usuario_id') ?? '';
      _nomeUsuarioAtual = prefs.getString('usuario_nome') ?? 'Usuário';
    });

    if (_usuarioId.isNotEmpty) {
      await _buscarGruposDaApi();
      await buscarItens();
    }
  }

  Future<void> _fazerLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); 
    
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Future<void> _buscarGruposDaApi() async {
    try {
      final baseUrl = dotenv.env['API_URL'] ?? '';
      final apiKey = dotenv.env['API_KEY'] ?? '';

      final url = Uri.parse('$baseUrl/grupos?usuario_id=$_usuarioId');
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json', 'x-api-key': apiKey},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final dados = jsonDecode(response.body);
        setState(() {
          _listaGruposApi = dados is List ? dados : [];
          
          if (_listaGruposApi.isNotEmpty) {
            _grupoId = int.parse(_listaGruposApi[0]['id'].toString());
            _nomeGrupoAtual = _listaGruposApi[0]['nome'];
          } else {
            _grupoId = 0;
            _nomeGrupoAtual = 'Sem Grupos';
          }
        });
      }
    } catch (e) {
      print("Erro ao buscar grupos da API: $e");
    }
  }

  void _trocarGrupo(int novoId, String nome) {
    setState(() {
      _grupoId = novoId;
      _nomeGrupoAtual = nome;
    });
    Navigator.pop(context); 
    buscarItens(); 
  }

  Future<void> buscarItens() async {
    if (_grupoId == 0) {
      setState(() {
        _itens = [];
        _carregando = false;
        _erro = 'Você não possui grupos cadastrados.';
      });
      return;
    }

    setState(() {
      _carregando = true;
      _erro = '';
      _modoOffline = false;
    });

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'lista_cache_${_usuarioId}_$_grupoId';

    // Lê a fila offline atual para não esconder os itens da tela
    final String filaString = prefs.getString('fila_offline_$_usuarioId') ?? '[]';
    List<dynamic> fila = jsonDecode(filaString);
    List<dynamic> filaVisual = fila.map((item) => {
      "id": "temp_${item['produto']}",
      "produto": item['produto'],
      "preco": item['preco'],
      "status": "aguardando_sync"
    }).toList();

    try {
      final baseUrl = dotenv.env['API_URL'] ?? '';
      final apiKey = dotenv.env['API_KEY'] ?? '';

      final url = Uri.parse('$baseUrl/itens?usuario_id=$_usuarioId&grupo_id=$_grupoId&status=pendente');

      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json', 'x-api-key': apiKey},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final dados = jsonDecode(response.body);

        if (dados is Map && dados.containsKey('erro')) {
          throw Exception(dados['erro']);
        }

        await prefs.setString(cacheKey, response.body);

        List<dynamic> itensFinais = dados is List ? dados : [];
        itensFinais.addAll(filaVisual); // Junta os itens do banco e os itens travados na fila

        setState(() {
          _itens = itensFinais;
          _carregando = false;
        });
      } else {
        throw Exception('Erro do Servidor (${response.statusCode})');
      }
    } catch (e) {
      final dadosEmCache = prefs.getString(cacheKey);

      if (dadosEmCache != null) {
        List<dynamic> itensFinais = jsonDecode(dadosEmCache);
        itensFinais.addAll(filaVisual); // Junta o cache com a fila

        setState(() {
          _itens = itensFinais;
          _modoOffline = true;
          _carregando = false;
        });
      } else {
        setState(() {
          _itens = filaVisual; // Mostra pelo menos a fila na tela
          _erro = filaVisual.isEmpty ? 'Falha na conexão e sem dados no cache.\n$e' : '';
          _modoOffline = true;
          _carregando = false;
        });
      }
    }
  }

  Future<void> _salvarNovoItem(String nomeDigitado, String precoDigitado, String qtdDigitada) async {
    if (nomeDigitado.isEmpty || precoDigitado.isEmpty || _grupoId == 0) return;

    final precoFormatado = precoDigitado.replaceAll(',', '.');
    final precoUnitario = double.tryParse(precoFormatado) ?? 0.0;
    final quantidade = int.tryParse(qtdDigitada) ?? 1;

    final precoTotalCalculado = precoUnitario * quantidade;
    String nomeFinal = nomeDigitado;
    
    if (quantidade > 1) {
      nomeFinal = "$nomeDigitado (${quantidade}x)";
    }

    final novoItem = {
      "usuario_id": int.parse(_usuarioId),
      "grupo_id": _grupoId,
      "produto": nomeFinal,
      "preco": precoTotalCalculado
    };

    // tela provisoriamente
    setState(() {
      _itens.add({
        "id": "temp_${DateTime.now().millisecondsSinceEpoch}",
        "produto": nomeFinal,
        "preco": precoTotalCalculado,
        "status": "aguardando_sync"
      });
    });

    final baseUrl = dotenv.env['API_URL'] ?? '';
    final apiKey = dotenv.env['API_KEY'] ?? '';

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/itens'),
        headers: {'Content-Type': 'application/json', 'x-api-key': apiKey},
        body: jsonEncode(novoItem),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Tenta enviar a fila travada antes de recarregar a tela
        await _sincronizarFilaOffline(); 
        buscarItens(); 
      } else {
        throw Exception('Erro na resposta da API');
      }
    } catch (e) {
      // Guarda na fila offline
      final prefs = await SharedPreferences.getInstance();
      final String filaString = prefs.getString('fila_offline_$_usuarioId') ?? '[]';
      List<dynamic> fila = jsonDecode(filaString);
      
      fila.add(novoItem);
      await prefs.setString('fila_offline_$_usuarioId', jsonEncode(fila));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sem internet. Item salvo na fila!'), backgroundColor: Colors.orange),
      );
    }
  }

  // ==========================================================
  // LÓGICA OFFLINE: SINCRONIZAÇÃO E FILA
  // ==========================================================
  Future<void> _sincronizarFilaOffline() async {
    final prefs = await SharedPreferences.getInstance();
    final String filaString = prefs.getString('fila_offline_$_usuarioId') ?? '[]';
    
    List<dynamic> fila = jsonDecode(filaString);
    if (fila.isEmpty) return; // Nada para sincronizar

    final baseUrl = dotenv.env['API_URL'] ?? '';
    final apiKey = dotenv.env['API_KEY'] ?? '';

    List<dynamic> itensQueFalharam = [];
    bool sincronizouAlgo = false;

    // Tenta enviar cada item da fila para o servidor
    for (var item in fila) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/itens'),
          headers: {'Content-Type': 'application/json', 'x-api-key': apiKey},
          body: jsonEncode(item),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200 || response.statusCode == 201) {
          sincronizouAlgo = true; // Sucesso! O item foi pro MySQL
        } else {
          itensQueFalharam.add(item); // API deu erro, mantém na fila
        }
      } catch (e) {
        itensQueFalharam.add(item); // Sem internet, mantém na fila
      }
    }

    // Atualiza a gaveta offline apenas com os que falharam
    await prefs.setString('fila_offline_$_usuarioId', jsonEncode(itensQueFalharam));

    // Se pelo menos um item subiu, recarregamos a lista oficial
    if (sincronizouAlgo) {
      buscarItens();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Itens offline sincronizados!'), backgroundColor: Colors.blue),
      );
    }
  }

  // ==========================================================
  // FUNÇÕES DE SWIPE: EDITAR E DELETAR
  // ==========================================================
  Future<bool> _confirmarExclusao(Map item) async {
    bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Item?'),
        content: Text('Tem certeza que deseja remover "${item['produto']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      return await _deletarItemDaApi(item['id']);
    }
    return false;
  }

  Future<bool> _deletarItemDaApi(dynamic itemId) async {
    if (itemId == null) return false;
    
    final baseUrl = dotenv.env['API_URL'] ?? '';
    final apiKey = dotenv.env['API_KEY'] ?? '';

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/itens?id=$itemId'),
        headers: {'Content-Type': 'application/json', 'x-api-key': apiKey},
      );

      if (response.statusCode == 200) {
        buscarItens();
        return true;
      }
      return false;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao excluir item.'), backgroundColor: Colors.red),
      );
      return false;
    }
  }

  void _exibirDialogoEditar(Map item) {
    final TextEditingController nomeController = TextEditingController(text: item['produto']);
    final TextEditingController precoController = TextEditingController(text: item['preco'].toString());
    final TextEditingController qtdController = TextEditingController(text: '1'); 

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeController,
              decoration: const InputDecoration(labelText: 'Produto'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: precoController,
                    decoration: const InputDecoration(labelText: 'Preço Unitário (R\$)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: qtdController,
                    decoration: const InputDecoration(labelText: 'Qtd'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Agora envia os 3 campos para a função de salvar a edição
              _salvarEdicaoNaApi(item['id'], nomeController.text, precoController.text, qtdController.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            child: const Text('Atualizar'),
          ),
        ],
      ),
    );
  }

  Future<void> _salvarEdicaoNaApi(dynamic itemId, String nome, String preco, String qtd) async {
    if (itemId == null || nome.isEmpty || preco.isEmpty) return;

    // 1. Tratamento do Preço Unitário
    final precoFormatado = preco.replaceAll(',', '.');
    final precoUnitario = double.tryParse(precoFormatado) ?? 0.0;
    
    // 2. Tratamento da Quantidade
    final quantidade = int.tryParse(qtd) ?? 1;

    // 3. Aplica a mesma matemática da criação
    final precoTotalCalculado = precoUnitario * quantidade;
    String nomeFinal = nome;
    
    if (quantidade > 1) {
      nomeFinal = "$nome (${quantidade}x)";
    }

    final baseUrl = dotenv.env['API_URL'] ?? '';
    final apiKey = dotenv.env['API_KEY'] ?? '';

    // Monta o pacote de dados atualizado
    final payload = {
      "id": itemId,
      "produto": nomeFinal,
      "preco": precoTotalCalculado
    };

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/itens'),
        headers: {'Content-Type': 'application/json', 'x-api-key': apiKey},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        buscarItens();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao atualizar item.'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _finalizarLista() async {
    bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalizar Compras?'),
        content: const Text('Todos os itens pendentes desta lista serão marcados como finalizados.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final baseUrl = dotenv.env['API_URL'] ?? '';
    final apiKey = dotenv.env['API_KEY'] ?? '';

    final payload = {
      "usuario_id": int.parse(_usuarioId),
      "grupo_id": _grupoId
    };

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/finalizar'),
        headers: {'Content-Type': 'application/json', 'x-api-key': apiKey},
        body: jsonEncode(payload),
      );

      final resultado = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final totalGasto = resultado['total_gasto']?.toString() ?? '0.00';
        final itensFechados = resultado['itens_fechados'] ?? 0;

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('🛒 Lista Finalizada!', style: TextStyle(color: Colors.green)),
            content: Text('📦 Itens fechados: $itensFechados\n💸 Total Gasto: R\$ $totalGasto'),
            actions: [
              ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))
            ],
          ),
        );
        buscarItens();
      } else {
        throw Exception(resultado['erro'] ?? 'Erro ao finalizar');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao finalizar: $e'), backgroundColor: Colors.red),
      );
    }
  }

  double _calcularTotalParcial() {
    double total = 0;
    for (var item in _itens) {
      if (item['status'] == 'pendente') {
        total += double.tryParse(item['preco'].toString()) ?? 0.0;
      }
    }
    return total;
  }

  void _exibirDialogoAdicionar() {
    final TextEditingController nomeController = TextEditingController();
    final TextEditingController precoController = TextEditingController();
    final TextEditingController qtdController = TextEditingController(text: '1'); 

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Novo Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeController,
              decoration: const InputDecoration(labelText: 'Produto (Ex: Arroz)'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: precoController,
                    decoration: const InputDecoration(labelText: 'Preço Unitário (R\$)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: qtdController,
                    decoration: const InputDecoration(labelText: 'Qtd'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _salvarNovoItem(nomeController.text, precoController.text, qtdController.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool temItensPendentes = _itens.any((item) => item['status'] == 'pendente');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(_nomeGrupoAtual, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (_modoOffline) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.cloud_off, size: 16, color: Colors.yellow),
                ]
              ],
            ),
            Text('Olá, $_nomeUsuarioAtual', style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _buscarGruposDaApi();
              _sincronizarFilaOffline(); // Tenta enviar os pendentes
              buscarItens(); // Puxa os novos
            },
          )
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  UserAccountsDrawerHeader(
                    decoration: const BoxDecoration(color: Colors.green),
                    accountName: Text(_nomeUsuarioAtual, style: const TextStyle(fontSize: 18)),
                    accountEmail: const Text('MarketList User'),
                    currentAccountPicture: const CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, color: Colors.green, size: 40),
                    ),
                  ),
                  if (_listaGruposApi.isEmpty)
                    const ListTile(title: Text('Nenhum grupo encontrado.')),
                  ..._listaGruposApi.map((grupo) {
                    final idGrupo = int.parse(grupo['id'].toString());
                    return ListTile(
                      leading: const Icon(Icons.list_alt),
                      title: Text(grupo['nome']),
                      selected: _grupoId == idGrupo,
                      selectedColor: Colors.green,
                      onTap: () => _trocarGrupo(idGrupo, grupo['nome']),
                    );
                  }),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.red),
              title: const Text('Sair', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: _fazerLogout,
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _exibirDialogoAdicionar,
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: temItensPendentes && !_carregando
          ? BottomAppBar(
              color: Colors.white,
              elevation: 10,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total: R\$ ${_calcularTotalParcial().toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    ElevatedButton.icon(
                      onPressed: _modoOffline ? null : _finalizarLista,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Finalizar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  // ==========================================================
  // SISTEMA DE ATUALIZAÇÃO AUTOMÁTICA
  // ==========================================================
  Future<void> _verificarAtualizacao() async {
    try {
      final baseUrl = dotenv.env['API_URL'] ?? '';
      
      // 1. Consulta a API para saber qual é a última versão
      final response = await http.get(Uri.parse('$baseUrl/atualizacao'));

      if (response.statusCode == 200) {
        final dados = jsonDecode(response.body);
        final buildNuvem = int.tryParse(dados['build_numero'].toString()) ?? 0;
        final urlApk = dados['url_apk'];
        final versaoNuvem = dados['versao_nome'];

        // 2. Lê a versão instalada atualmente no celular
        PackageInfo packageInfo = await PackageInfo.fromPlatform();
        final buildApp = int.tryParse(packageInfo.buildNumber) ?? 0;

        // 3. Compara: Se a nuvem for maior, mostra o aviso!
        if (buildNuvem > buildApp) {
          _mostrarAlertaAtualizacao(versaoNuvem, urlApk);
        }
      }
    } catch (e) {
      print("Erro ao verificar atualização: $e");
    }
  }

  void _mostrarAlertaAtualizacao(String versao, String url) {
    showDialog(
      context: context,
      barrierDismissible: false, // Impede de fechar clicando fora
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.system_update, color: Colors.green),
            SizedBox(width: 10),
            Text('Nova Versão!'),
          ],
        ),
        content: Text('A versão $versao do MarketList acabou de sair.\nDeseja baixar a atualização agora?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Botão "Depois" fecha o alerta
            child: const Text('Depois', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Fecha o alerta
              final uri = Uri.parse(url);
              
              // Abre o navegador padrão do celular para baixar o APK
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Atualizar'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_erro.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 10),
              Text(
                _erro,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: buscarItens,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar Novamente'),
              )
            ],
          ),
        ),
      );
    }

    if (_itens.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_basket_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 10),
            Text(
              'A lista "$_nomeGrupoAtual" está vazia!',
              style: TextStyle(color: Colors.grey[600], fontSize: 18),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _itens.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final item = _itens[index];
        
        final nomeProduto = item['produto'] ?? 'Produto sem nome';
        final preco = double.tryParse(item['preco'].toString()) ?? 0.0;
        final status = item['status'] ?? 'pendente';
        
        // 3 variáveis de estado
        final isFinalizado = status == 'finalizado';
        final isAguardando = status == 'aguardando_sync'; // O status da fila offline

        return Dismissible(
          key: ValueKey(item['id'] ?? UniqueKey().toString()), 
          
          // BLOQUEIO DE SEGURANÇA: Não deixa arrastar se estiver fechado OU se estiver sem internet (laranja)
          direction: (isFinalizado || isAguardando) ? DismissDirection.none : DismissDirection.horizontal,
          
          background: Container(
            color: Colors.blue,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Icon(Icons.edit, color: Colors.white, size: 30),
          ),
          
          secondaryBackground: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Icon(Icons.delete, color: Colors.white, size: 30),
          ),
          
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              _exibirDialogoEditar(item);
              return false; 
            } else if (direction == DismissDirection.endToStart) {
              return await _confirmarExclusao(item); 
            }
            return false;
          },
          
          child: Card(
            elevation: isAguardando ? 0 : 2, // Tira a sombra se estiver offline
            // Fundo: Cinza (fechado) | Laranja bem clarinho (offline) | Branco (normal)
            color: isFinalizado ? Colors.grey[100] : (isAguardando ? Colors.orange[50] : Colors.white),
            margin: const EdgeInsets.symmetric(vertical: 5),
            
            // Borda laranja se estiver offline
            shape: isAguardando 
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.orange.shade300, width: 1),
                )
              : RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              
            child: ListTile(
              leading: CircleAvatar(
                // Cor da bolinha: Cinza (fechado) | Laranja (offline) | Verde (normal)
                backgroundColor: isFinalizado ? Colors.grey : (isAguardando ? Colors.orange : Colors.green),
                child: Icon(
                  // Ícone: Check (fechado) | Relógio (offline) | Carrinho (normal)
                  isFinalizado ? Icons.check : (isAguardando ? Icons.access_time : Icons.shopping_cart),
                  color: Colors.white,
                  size: 20,
                ),
              ),
              title: Text(
                nomeProduto,
                style: TextStyle(
                  decoration: isFinalizado ? TextDecoration.lineThrough : null,
                  // Cor do texto
                  color: isFinalizado ? Colors.grey : (isAguardando ? Colors.orange[900] : Colors.black87),
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                isAguardando ? 'Aguardando rede...' : 'Status: ${status.toUpperCase()}',
                style: TextStyle(
                  fontSize: 12, 
                  color: isAguardando ? Colors.orange[800] : Colors.grey[600],
                  fontStyle: isAguardando ? FontStyle.italic : FontStyle.normal,
                ),
              ),
              trailing: Text(
                'R\$ ${preco.toStringAsFixed(2)}',
                style: TextStyle(
                  color: isFinalizado ? Colors.grey : (isAguardando ? Colors.orange[900] : Colors.green[800]),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}