import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      // O app agora inicia no verificador de autenticação
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

    // Se já tem um ID salvo, vai para a lista. Se não, vai para o Login.
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
        // LOGIN COM SUCESSO: Salva os dados no cofre do celular
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('usuario_id', resultado['id'].toString());
        await prefs.setString('usuario_nome', resultado['nome'].toString());

        if (!mounted) return;
        
        // Vai para a tela principal
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ListaComprasScreen()),
        );
      } else {
        // SENHA ERRADA OU USUÁRIO NÃO ENCONTRADO
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
              const Icon(Icons.shopping_basket, size: 100, color: Colors.green),
              const SizedBox(height: 20),
              const Text(
                'MarketList',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green),
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
  }

  // Busca quem está logado direto da memória do celular
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

  // Função de LOGOUT
  Future<void> _fazerLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Limpa todos os dados salvos (ID, Nome, Cache offline)
    
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

        setState(() {
          _itens = dados is List ? dados : [];
          _carregando = false;
        });
      } else {
        throw Exception('Erro do Servidor (${response.statusCode})');
      }
    } catch (e) {
      final dadosEmCache = prefs.getString(cacheKey);

      if (dadosEmCache != null) {
        setState(() {
          _itens = jsonDecode(dadosEmCache);
          _modoOffline = true;
          _carregando = false;
        });
      } else {
        setState(() {
          _erro = 'Falha na conexão e sem dados no cache.\n$e';
          _carregando = false;
        });
      }
    }
  }

  Future<void> _salvarNovoItem(String nome, String preco) async {
    if (nome.isEmpty || preco.isEmpty || _grupoId == 0) return;

    final precoFormatado = preco.replaceAll(',', '.');
    final precoDouble = double.tryParse(precoFormatado) ?? 0.0;

    final novoItem = {
      "usuario_id": int.parse(_usuarioId),
      "grupo_id": _grupoId,
      "produto": nome,
      "preco": precoDouble
    };

    final baseUrl = dotenv.env['API_URL'] ?? '';
    final apiKey = dotenv.env['API_KEY'] ?? '';

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Salvando item...'), duration: Duration(seconds: 1)),
    );

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/itens'),
        headers: {'Content-Type': 'application/json', 'x-api-key': apiKey},
        body: jsonEncode(novoItem),
      );

      final resultado = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (resultado is Map && resultado['status'] == 'item adicionado') {
          buscarItens();
        } else {
          throw Exception(resultado['erro'] ?? 'Erro desconhecido');
        }
      } else {
        throw Exception('Erro ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao salvar.'), backgroundColor: Colors.red),
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
            TextField(
              controller: precoController,
              decoration: const InputDecoration(labelText: 'Preço Total (Ex: 20.50)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              _salvarNovoItem(nomeController.text, precoController.text);
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
              buscarItens();
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
            // Botão Sair no final do Menu
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
        final isFinalizado = status == 'finalizado';

        return Card(
          elevation: 2,
          color: isFinalizado ? Colors.grey[100] : Colors.white,
          margin: const EdgeInsets.symmetric(vertical: 5),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isFinalizado ? Colors.grey : Colors.green,
              child: Icon(
                isFinalizado ? Icons.check : Icons.shopping_cart,
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(
              nomeProduto,
              style: TextStyle(
                decoration: isFinalizado ? TextDecoration.lineThrough : null,
                color: isFinalizado ? Colors.grey : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              'Status: ${status.toUpperCase()}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            trailing: Text(
              'R\$ ${preco.toStringAsFixed(2)}',
              style: TextStyle(
                color: isFinalizado ? Colors.grey : Colors.green[800],
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        );
      },
    );
  }
}