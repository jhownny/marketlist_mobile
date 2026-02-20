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
      home: const ListaComprasScreen(),
    );
  }
}

class ListaComprasScreen extends StatefulWidget {
  const ListaComprasScreen({super.key});

  @override
  State<ListaComprasScreen> createState() => _ListaComprasScreenState();
}

class _ListaComprasScreenState extends State<ListaComprasScreen> {
  List<dynamic> _itens = [];
  List<dynamic> _listaUsuariosApi = []; // Armazena os usuários vindos do banco
  bool _carregando = true;
  bool _modoOffline = false;
  String _erro = '';

  String _usuarioId = '3'; // Valor inicial (até carregar ou selecionar outro)
  String _nomeUsuarioAtual = 'Carregando...'; // Exibição visual
  int _grupoId = 1; 
  String _nomeGrupoAtual = 'Mercado'; 

  @override
  void initState() {
    super.initState();
    _inicializarDados();
  }

  // Função para carregar usuários e depois os itens
  Future<void> _inicializarDados() async {
    await _buscarUsuariosDaApi();
    await buscarItens();
  }

  // --- NOVA FUNÇÃO: BUSCAR USUÁRIOS DINAMICAMENTE ---
  Future<void> _buscarUsuariosDaApi() async {
    try {
      final baseUrl = dotenv.env['API_URL'] ?? '';
      final apiKey = dotenv.env['API_KEY'] ?? '';

      final url = Uri.parse('$baseUrl/usuarios');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final dados = jsonDecode(response.body);
        setState(() {
          _listaUsuariosApi = dados is List ? dados : [];
          
          // Se a lista carregou, define o nome do usuário atual baseado no ID padrão
          if (_listaUsuariosApi.isNotEmpty) {
            final userMatch = _listaUsuariosApi.firstWhere(
              (u) => u['id'].toString() == _usuarioId, 
              orElse: () => _listaUsuariosApi[0]
            );
            _usuarioId = userMatch['id'].toString();
            _nomeUsuarioAtual = userMatch['nome'];
          }
        });
      }
    } catch (e) {
      print("Erro ao buscar usuários da API: $e");
      // Se der erro (ex: offline), deixamos a lista vazia e o app usa o ID padrão do cache
    }
  }

  // --- FUNÇÃO DE MUDAR USUÁRIO ---
  void _trocarUsuario(String novoId, String novoNome) {
    setState(() {
      _usuarioId = novoId;
      _nomeUsuarioAtual = novoNome;
    });
    buscarItens(); // Recarrega a lista para o novo usuário
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Trocado para o usuário: $novoNome')),
    );
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

      if (baseUrl.isEmpty || apiKey.isEmpty) {
        throw Exception('Configuração do .env incompleta.');
      }

      final url = Uri.parse('$baseUrl/itens?usuario_id=$_usuarioId&grupo_id=$_grupoId&status=pendente');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
        },
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
    if (nome.isEmpty || preco.isEmpty) return;

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
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
        },
        body: jsonEncode(novoItem),
      );

      final resultado = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (resultado is Map && resultado['status'] == 'item adicionado') {
          buscarItens();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item adicionado com sucesso!'), backgroundColor: Colors.green),
          );
        } else {
          throw Exception(resultado['erro'] ?? 'Erro desconhecido');
        }
      } else {
        throw Exception('Erro ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao salvar. Verifique sua conexão.'), backgroundColor: Colors.red),
      );
    }
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
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('$_nomeGrupoAtual', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (_modoOffline) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.cloud_off, size: 16, color: Colors.yellow),
                ]
              ],
            ),
            Text('Usuário: $_nomeUsuarioAtual', style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          // Menu de Usuários (AGORA DINÂMICO)
          PopupMenuButton<Map<String, String>>(
            onSelected: (Map<String, String> userSelec) {
              _trocarUsuario(userSelec['id']!, userSelec['nome']!);
            },
            itemBuilder: (context) {
              if (_listaUsuariosApi.isEmpty) {
                return [
                  const PopupMenuItem(
                    enabled: false,
                    child: Text('Nenhum usuário encontrado'),
                  )
                ];
              }
              // Mapeia a lista recebida da API para itens do menu
              return _listaUsuariosApi.map<PopupMenuItem<Map<String, String>>>((user) {
                return PopupMenuItem<Map<String, String>>(
                  value: {'id': user['id'].toString(), 'nome': user['nome']},
                  child: Text(user['nome']),
                );
              }).toList();
            },
            icon: const Icon(Icons.people_alt),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _buscarUsuariosDaApi();
              buscarItens();
            },
          )
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.green),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.shopping_basket, color: Colors.white, size: 40),
                  SizedBox(height: 10),
                  Text('Minhas Listas', style: TextStyle(color: Colors.white, fontSize: 24)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.shopping_cart),
              title: const Text('Mercado'),
              selected: _grupoId == 1,
              selectedColor: Colors.green,
              onTap: () => _trocarGrupo(1, 'Mercado'),
            ),
            ListTile(
              leading: const Icon(Icons.outdoor_grill),
              title: const Text('Churrasco'),
              selected: _grupoId == 2,
              selectedColor: Colors.green,
              onTap: () => _trocarGrupo(2, 'Churrasco'),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Casa'),
              selected: _grupoId == 3,
              selectedColor: Colors.green,
              onTap: () => _trocarGrupo(3, 'Casa'),
            ),
          ],
        ),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _exibirDialogoAdicionar,
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
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