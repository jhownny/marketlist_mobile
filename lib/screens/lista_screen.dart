import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'login_screen.dart';
import 'historico_screen.dart';
import 'configuracoes_screen.dart';

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
  String _tokenJwt = '';
  int _grupoId = 0; 
  String _nomeGrupoAtual = 'Carregando...';

  @override
  void initState() {
    super.initState();
    _carregarUsuarioLocal();
    _verificarAtualizacao();
  }

  Future<void> _verificarAtualizacao() async {
    try {
      final baseUrl = dotenv.env['API_URL'] ?? '';
      final apiKey = dotenv.env['API_KEY'] ?? '';
      
      final response = await http.get(
        Uri.parse('$baseUrl/atualizacao'),
        headers: {'Content-Type': 'application/json', 'x-api-key': apiKey},
      );

      if (response.statusCode == 200) {
        final dados = jsonDecode(response.body);
        final buildNuvem = int.tryParse(dados['build_numero'].toString()) ?? 0;
        final urlApk = dados['url_apk'];
        final versaoNuvem = dados['versao_nome'];

        PackageInfo packageInfo = await PackageInfo.fromPlatform();
        final buildApp = int.tryParse(packageInfo.buildNumber) ?? 0;

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
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [Icon(Icons.system_update, color: Colors.green), SizedBox(width: 10), Text('Nova Versão!')],
        ),
        content: Text('A versão $versao do MarketList acabou de sair.\nDeseja baixar a atualização agora?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Depois', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final uri = Uri.parse(url);
              try {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (e) {
                print("Erro ao abrir navegador: $e");
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Atualizar'),
          ),
        ],
      ),
    );
  }

  Future<void> _carregarUsuarioLocal() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _usuarioId = prefs.getString('usuario_id') ?? '';
      _nomeUsuarioAtual = prefs.getString('usuario_nome') ?? 'Usuário';
      _tokenJwt = prefs.getString('jwt_token') ?? ''; // Pega o token do cofre
    });

    if (_usuarioId.isNotEmpty && _tokenJwt.isNotEmpty) {
      await _buscarGruposDaApi();
      await buscarItens();
    } else {
      _fazerLogout(); // Se não tem token, manda pro login
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

  // Gera o cabeçalho padrão com o Crachá JWT para todas as chamadas
  Map<String, String> _headersAuth() {
    final apiKey = dotenv.env['API_KEY'] ?? '';
    return {
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
      'Authorization': 'Bearer $_tokenJwt' 
    };
  }

  Future<void> _buscarGruposDaApi() async {
    try {
      final baseUrl = dotenv.env['API_URL'] ?? '';
      final response = await http.get(
        Uri.parse('$baseUrl/grupos'), // PHP já sabe de quem é pelo JWT!
        headers: _headersAuth(),
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
      } else if (response.statusCode == 401) {
        _fazerLogout(); // Token expirou!
      }
    } catch (e) {
      print("Erro ao buscar grupos: $e");
    }
  }

  void _trocarGrupo(int novoId, String nome) {
    setState(() {
      _grupoId = novoId;
      _nomeGrupoAtual = nome;
    });
    buscarItens(); 
  }

  // ==========================================================
  // FUNÇÕES PARA CRIAR NOVO GRUPO
  // ==========================================================
  void _exibirDialogoNovoGrupo() {
    final nomeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Novo Grupo de Compras'),
        content: TextField(
          controller: nomeController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nome do Grupo',
            hintText: 'Ex: Churrasco, Mês, Festa...',
            prefixIcon: Icon(Icons.shopping_bag),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _criarNovoGrupoNaApi(nomeController.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Criar'),
          ),
        ],
      ),
    );
  }

  Future<void> _criarNovoGrupoNaApi(String nome) async {
    if (nome.isEmpty) return;

    setState(() => _carregando = true);

    try {
      final baseUrl = dotenv.env['API_URL'] ?? '';
      
      final response = await http.post(
        Uri.parse('$baseUrl/grupos'),
        headers: _headersAuth(), // Envia o crachá JWT de segurança!
        body: jsonEncode({
          "nome": nome,
          "icone": "shopping_cart" // Ícone padrão para novos grupos
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        final dados = jsonDecode(response.body);
        final novoId = int.tryParse(dados['id'].toString()) ?? 0;

        // Atualiza a lista de grupos do menu lateral
        await _buscarGruposDaApi();

        // Muda automaticamente a tela para o grupo que acabou de ser criado
        if (novoId > 0) {
          _trocarGrupo(novoId, nome);
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grupo criado com sucesso!'), backgroundColor: Colors.green),
        );
      } else {
        throw Exception('Erro da API');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao criar grupo. Verifique a conexão.'), backgroundColor: Colors.red),
      );
      setState(() => _carregando = false);
    }
  }

  // ==========================================================
  // FUNÇÕES PARA EDITAR E DELETAR GRUPOS
  // ==========================================================
  void _exibirOpcoesGrupo(int idGrupo, String nomeAtual) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Opções do Grupo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('Editar Nome'),
              onTap: () {
                Navigator.pop(context); // Fecha o menu inferior
                _exibirDialogoEditarGrupo(idGrupo, nomeAtual);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Excluir Grupo'),
              subtitle: const Text('Isso apagará todos os itens dentro dele!'),
              onTap: () {
                Navigator.pop(context); // Fecha o menu inferior
                _confirmarExclusaoGrupo(idGrupo, nomeAtual);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _exibirDialogoEditarGrupo(int idGrupo, String nomeAtual) {
    final nomeController = TextEditingController(text: nomeAtual);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Grupo'),
        content: TextField(
          controller: nomeController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Novo nome'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _editarGrupoNaApi(idGrupo, nomeController.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Future<void> _editarGrupoNaApi(int id, String novoNome) async {
    if (novoNome.isEmpty) return;
    try {
      final baseUrl = dotenv.env['API_URL'] ?? '';
      final response = await http.put(
        Uri.parse('$baseUrl/grupos'),
        headers: _headersAuth(),
        body: jsonEncode({"id": id, "nome": novoNome}),
      );
      if (response.statusCode == 200) {
        if (_grupoId == id) setState(() => _nomeGrupoAtual = novoNome);
        await _buscarGruposDaApi();
      }
    } catch (e) {
      print("Erro ao editar grupo: $e");
    }
  }

  Future<void> _confirmarExclusaoGrupo(int idGrupo, String nome) async {
    bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Grupo?', style: TextStyle(color: Colors.red)),
        content: Text('Tem certeza que deseja excluir o grupo "$nome"?\n\nTODOS os itens dentro dele serão perdidos para sempre!'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        final baseUrl = dotenv.env['API_URL'] ?? '';
        final response = await http.delete(
          Uri.parse('$baseUrl/grupos?id=$idGrupo'),
          headers: _headersAuth(),
        );
        if (response.statusCode == 200) {
          await _buscarGruposDaApi();
          // Se o usuário apagou o grupo que ele estava lendo, move ele pro primeiro da lista (ou zera tudo)
          if (_grupoId == idGrupo) {
            if (_listaGruposApi.isNotEmpty) {
              _trocarGrupo(int.parse(_listaGruposApi[0]['id'].toString()), _listaGruposApi[0]['nome']);
            } else {
              setState(() { _grupoId = 0; _nomeGrupoAtual = 'Sem Grupos'; _itens = []; });
            }
          }
        }
      } catch (e) {
        print("Erro ao deletar grupo: $e");
      }
    }
  }

  Future<void> _sincronizarFilaOffline() async {
    final prefs = await SharedPreferences.getInstance();
    final String filaString = prefs.getString('fila_offline_$_usuarioId') ?? '[]';
    List<dynamic> fila = jsonDecode(filaString);
    if (fila.isEmpty) return;

    final baseUrl = dotenv.env['API_URL'] ?? '';
    List<dynamic> itensQueFalharam = [];
    bool sincronizouAlgo = false;

    for (var item in fila) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/itens'),
          headers: _headersAuth(),
          body: jsonEncode(item),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200 || response.statusCode == 201) {
          sincronizouAlgo = true; 
        } else {
          itensQueFalharam.add(item); 
        }
      } catch (e) {
        itensQueFalharam.add(item); 
      }
    }

    await prefs.setString('fila_offline_$_usuarioId', jsonEncode(itensQueFalharam));
    if (sincronizouAlgo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Itens offline sincronizados!'), backgroundColor: Colors.blue),
      );
    }
  }

  Future<void> buscarItens() async {
    if (_grupoId == 0) {
      setState(() { _itens = []; _carregando = false; _erro = 'Sem grupos.'; });
      return;
    }

    setState(() { _carregando = true; _erro = ''; _modoOffline = false; });
    await _sincronizarFilaOffline();

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'lista_cache_${_usuarioId}_$_grupoId';
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
      final url = Uri.parse('$baseUrl/itens?grupo_id=$_grupoId&status=pendente');

      final response = await http.get(url, headers: _headersAuth())
        .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final dados = jsonDecode(response.body);
        if (dados is Map && dados.containsKey('erro')) throw Exception(dados['erro']);
        
        await prefs.setString(cacheKey, response.body);
        List<dynamic> itensFinais = dados is List ? dados : [];
        itensFinais.addAll(filaVisual); 

        setState(() { _itens = itensFinais; _carregando = false; });
      } else if (response.statusCode == 401) {
        _fazerLogout(); // Token expirou!
      } else {
        throw Exception('Erro ${response.statusCode}');
      }
    } catch (e) {
      final dadosEmCache = prefs.getString(cacheKey);
      if (dadosEmCache != null) {
        List<dynamic> itensFinais = jsonDecode(dadosEmCache);
        itensFinais.addAll(filaVisual);
        setState(() { _itens = itensFinais; _modoOffline = true; _carregando = false; });
      } else {
        setState(() {
          _itens = filaVisual;
          _erro = filaVisual.isEmpty ? 'Offline e sem cache.\n$e' : '';
          _modoOffline = true;
          _carregando = false;
        });
      }
    }
  }

  Future<void> _salvarNovoItem(String nomeDigitado, String precoDigitado, String qtdDigitada) async {
    if (nomeDigitado.isEmpty || precoDigitado.isEmpty || _grupoId == 0) return;

    final precoUnitario = double.tryParse(precoDigitado.replaceAll(',', '.')) ?? 0.0;
    final quantidade = int.tryParse(qtdDigitada) ?? 1;
    final precoTotalCalculado = precoUnitario * quantidade;
    String nomeFinal = quantidade > 1 ? "$nomeDigitado (${quantidade}x)" : nomeDigitado;

    final novoItem = {
      // Retirado o usuario_id do body, a API pega direto do JWT por segurança
      "grupo_id": _grupoId,
      "produto": nomeFinal,
      "preco": precoTotalCalculado
    };

    setState(() {
      _itens.add({
        "id": "temp_${DateTime.now().millisecondsSinceEpoch}",
        "produto": nomeFinal,
        "preco": precoTotalCalculado,
        "status": "aguardando_sync"
      });
    });

    final baseUrl = dotenv.env['API_URL'] ?? '';

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/itens'),
        headers: _headersAuth(),
        body: jsonEncode(novoItem),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _sincronizarFilaOffline(); 
        buscarItens(); 
      } else if (response.statusCode == 401) {
        _fazerLogout();
      } else {
        throw Exception('Erro na API');
      }
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      final String filaString = prefs.getString('fila_offline_$_usuarioId') ?? '[]';
      List<dynamic> fila = jsonDecode(filaString);
      fila.add(novoItem);
      await prefs.setString('fila_offline_$_usuarioId', jsonEncode(fila));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offline. Item na fila!'), backgroundColor: Colors.orange),
      );
    }
  }

  Future<bool> _confirmarExclusao(Map item) async {
    bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Item?'),
        content: Text('Tem certeza que deseja remover "${item['produto']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmar == true) return await _deletarItemDaApi(item['id']);
    return false;
  }

  Future<bool> _deletarItemDaApi(dynamic itemId) async {
    if (itemId == null) return false;
    final baseUrl = dotenv.env['API_URL'] ?? '';
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/itens?id=$itemId'),
        headers: _headersAuth(),
      );
      if (response.statusCode == 200) {
        buscarItens();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void _exibirDialogoEditar(Map item) {
    final nomeController = TextEditingController(text: item['produto']);
    final precoController = TextEditingController(text: item['preco'].toString());
    final qtdController = TextEditingController(text: '1'); 

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nomeController, decoration: const InputDecoration(labelText: 'Produto'), textCapitalization: TextCapitalization.sentences),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(flex: 2, child: TextField(controller: precoController, decoration: const InputDecoration(labelText: 'Preço Unitário (R\$)'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                const SizedBox(width: 10),
                Expanded(flex: 1, child: TextField(controller: qtdController, decoration: const InputDecoration(labelText: 'Qtd'), keyboardType: TextInputType.number)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
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
    final precoUnitario = double.tryParse(preco.replaceAll(',', '.')) ?? 0.0;
    final quantidade = int.tryParse(qtd) ?? 1;
    final precoTotal = precoUnitario * quantidade;
    String nomeFinal = quantidade > 1 ? "$nome (${quantidade}x)" : nome;

    final baseUrl = dotenv.env['API_URL'] ?? '';
    final payload = {"id": itemId, "produto": nomeFinal, "preco": precoTotal};

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/itens'),
        headers: _headersAuth(),
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200) buscarItens();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao atualizar item.'), backgroundColor: Colors.red));
    }
  }

  Future<void> _finalizarLista() async {
    bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalizar Compras?'),
        content: const Text('Todos os itens pendentes serão marcados como finalizados.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
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
    final payload = {"grupo_id": _grupoId}; 

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/finalizar'),
        headers: _headersAuth(),
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200) {
        final res = jsonDecode(response.body);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('🛒 Lista Finalizada!', style: TextStyle(color: Colors.green)),
            content: Text('📦 Itens fechados: ${res['itens_fechados']}'),
            actions: [ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
        buscarItens();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    }
  }

  double _calcularTotalParcial() {
    double total = 0;
    for (var item in _itens) {
      if (item['status'] == 'pendente' || item['status'] == 'aguardando_sync') {
        total += double.tryParse(item['preco'].toString()) ?? 0.0;
      }
    }
    return total;
  }

  void _exibirDialogoAdicionar() {
    final nomeController = TextEditingController();
    final precoController = TextEditingController();
    final qtdController = TextEditingController(text: '1'); 

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Novo Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nomeController, decoration: const InputDecoration(labelText: 'Produto'), textCapitalization: TextCapitalization.sentences),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(flex: 2, child: TextField(controller: precoController, decoration: const InputDecoration(labelText: 'Preço (R\$)'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                const SizedBox(width: 10),
                Expanded(flex: 1, child: TextField(controller: qtdController, decoration: const InputDecoration(labelText: 'Qtd'), keyboardType: TextInputType.number)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
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
    final temItensPendentes = _itens.any((i) => i['status'] == 'pendente' || i['status'] == 'aguardando_sync');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(_nomeGrupoAtual, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (_modoOffline) ...[const SizedBox(width: 8), const Icon(Icons.cloud_off, size: 16, color: Colors.yellow)]
              ],
            ),
            Text('Olá, $_nomeUsuarioAtual', style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'Ver Histórico',
            onPressed: () {
              if (_grupoId != 0) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HistoricoScreen(grupoId: _grupoId, nomeGrupo: _nomeGrupoAtual),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () { _buscarGruposDaApi(); _sincronizarFilaOffline(); buscarItens(); },
          )
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
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
                      currentAccountPicture: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person, color: Colors.green, size: 40)),
                    ),
                    if (_listaGruposApi.isEmpty) const ListTile(title: Text('Nenhum grupo encontrado.')),
                    // Renderiza os grupos existentes
                    ..._listaGruposApi.map((grupo) {
                      final idGrupo = int.parse(grupo['id'].toString());
                      return ListTile(
                        leading: const Icon(Icons.list_alt),
                        title: Text(grupo['nome']),
                        selected: _grupoId == idGrupo,
                        selectedColor: Colors.green,
                        onTap: () {
                          Navigator.pop(context); 
                          _trocarGrupo(idGrupo, grupo['nome']);
                        },
                        trailing: IconButton(
                          icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                          onPressed: () {
                            Navigator.pop(context); // Fecha o drawer lateral
                            _exibirOpcoesGrupo(idGrupo, grupo['nome']); // Abre o menu inferior
                          },
                        ),
                      );
                    }),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.add_circle_outline, color: Colors.green),
                      title: const Text('Criar Novo Grupo', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      onTap: () {
                        Navigator.pop(context); // Fecha o menu lateral
                        _exibirDialogoNovoGrupo(); // Abre o Pop-up
                      },
                    ),
                  ],
                ),
              ),
              const Divider(),
                ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('Configurações'),
                    onTap: () {
                      Navigator.pop(context); // Fecha o menu lateral
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ConfiguracoesScreen()),
                      );
                    },
                ),
            ],
          ),
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
                    Text('Total: R\$ ${_calcularTotalParcial().toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    ElevatedButton.icon(
                      onPressed: _modoOffline ? null : _finalizarLista,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Finalizar'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_carregando) return const Center(child: CircularProgressIndicator());
    if (_erro.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 10),
              Text(_erro, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 20),
              ElevatedButton.icon(onPressed: buscarItens, icon: const Icon(Icons.refresh), label: const Text('Tentar Novamente'))
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
            Text('A lista "$_nomeGrupoAtual" está vazia!', style: TextStyle(color: Colors.grey[600], fontSize: 18)),
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
        final isAguardando = status == 'aguardando_sync';

        return Dismissible(
          key: ValueKey(item['id'] ?? UniqueKey().toString()), 
          direction: (isFinalizado || isAguardando) ? DismissDirection.none : DismissDirection.horizontal,
          background: Container(color: Colors.blue, alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 20), child: const Icon(Icons.edit, color: Colors.white, size: 30)),
          secondaryBackground: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.symmetric(horizontal: 20), child: const Icon(Icons.delete, color: Colors.white, size: 30)),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              _exibirDialogoEditar(item); return false; 
            } else if (direction == DismissDirection.endToStart) {
              return await _confirmarExclusao(item); 
            }
            return false;
          },
          child: Card(
            elevation: isAguardando ? 0 : 2,
            color: isFinalizado ? Colors.grey[100] : (isAguardando ? Colors.orange[50] : Colors.white),
            margin: const EdgeInsets.symmetric(vertical: 5),
            shape: isAguardando ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.orange.shade300, width: 1)) : RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isFinalizado ? Colors.grey : (isAguardando ? Colors.orange : Colors.green),
                child: Icon(isFinalizado ? Icons.check : (isAguardando ? Icons.access_time : Icons.shopping_cart), color: Colors.white, size: 20),
              ),
              title: Text(nomeProduto, style: TextStyle(decoration: isFinalizado ? TextDecoration.lineThrough : null, color: isFinalizado ? Colors.grey : (isAguardando ? Colors.orange[900] : Colors.black87), fontWeight: FontWeight.bold)),
              subtitle: Text(isAguardando ? 'Aguardando rede...' : 'Status: ${status.toUpperCase()}', style: TextStyle(fontSize: 12, color: isAguardando ? Colors.orange[800] : Colors.grey[600], fontStyle: isAguardando ? FontStyle.italic : FontStyle.normal)),
              trailing: Text('R\$ ${preco.toStringAsFixed(2)}', style: TextStyle(color: isFinalizado ? Colors.grey : (isAguardando ? Colors.orange[900] : Colors.green[800]), fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        );
      },
    );
  }
}