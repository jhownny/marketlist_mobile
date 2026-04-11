import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'login_screen.dart';
import 'historico_screen.dart';
import 'configuracoes_screen.dart';
import 'dashboard_screen.dart';
import 'financas_screen.dart';
import 'barcode_scanner_screen.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class ListaComprasScreen extends StatefulWidget {
  const ListaComprasScreen({super.key});

  @override
  State<ListaComprasScreen> createState() => _ListaComprasScreenState();
}

class _ListaComprasScreenState extends State<ListaComprasScreen> {

  // Mapeamento das strings do banco para os ícones do Flutter
  final Map<String, IconData> _iconesDisponiveis = {
    'shopping_cart': Icons.shopping_cart,
    'shopping_basket': Icons.shopping_basket,
    'restaurant': Icons.restaurant,
    'local_pizza': Icons.local_pizza,
    'kebab_dining': Icons.kebab_dining,
    'local_pharmacy': Icons.local_pharmacy,
    'home': Icons.home,
    'pets': Icons.pets,
  };

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
  double _orcamentoAtual = 0.0;
  double _opacidadeFab = 0.4;

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
      debugPrint("Erro ao verificar atualização: $e");
    }
  }

  void _mostrarAlertaAtualizacao(String versao, String url) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [Icon(Icons.system_update, color: Colors.green), SizedBox(width: 10), Text('Nova Versão!')],
      ),
      content: Text('A versão $versao está pronta.\nDeseja baixar e instalar agora?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Depois', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            _iniciarDownloadEInstalacao(url, versao);
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          child: const Text('Atualizar Agora'),
        ),
      ],
    ),
  );
  }

  Future<void> _iniciarDownloadEInstalacao(String url, String versao) async {
  //Pedir permissão para instalar apps
  var status = await Permission.requestInstallPackages.request();
  if (!status.isGranted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permissão necessária para atualizar.')));
    return;
  }

  //Preparar o diálogo de progresso
  double progresso = 0;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Baixando Atualização..."),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: progresso, backgroundColor: Colors.grey[200], color: Colors.green),
            const SizedBox(height: 10),
            Text("${(progresso * 100).toStringAsFixed(0)}%"),
          ],
        ),
      ),
    ),
  );

  try {
    //Definir onde o arquivo será salvo temporariamente
    Directory tempDir = await getTemporaryDirectory();
    String pathCompleto = "${tempDir.path}/marketlist_$versao.apk";

    //Iniciar o download com Dio
    Dio dio = Dio();
    await dio.download(
      url,
      pathCompleto,
      onReceiveProgress: (recebido, total) {
        if (total != -1) {
          progresso = recebido / total;
          (context as Element).markNeedsBuild(); 
        }
      },
    );

    //Fechar o diálogo de progresso e Abrir o instalador
    Navigator.pop(context);
    await OpenFilex.open(pathCompleto);

  } catch (e) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao baixar: $e'), backgroundColor: Colors.red));
  }
  
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
            // Tenta ler o orçamento, se falhar ou não existir, fica 0.0
            _orcamentoAtual = double.tryParse(_listaGruposApi[0]['orcamento']?.toString() ?? '0') ?? 0.0;
          } else {
            _grupoId = 0;
            _nomeGrupoAtual = 'Sem Grupos';
            _orcamentoAtual = 0.0;
          }
        });
      } else if (response.statusCode == 401) {
        _fazerLogout(); // Token expirou!
      }
    } catch (e) {
      debugPrint("Erro ao buscar grupos: $e");
    }
  }

  void _trocarGrupo(int novoId, String nome, double orcamento) {
    setState(() {
      _grupoId = novoId;
      _nomeGrupoAtual = nome;
      _orcamentoAtual = orcamento;
    });
    buscarItens(); 
  }

  Future<void> _gerarCodigoConvite(int idGrupo) async {
    try {
      final baseUrl = dotenv.env['API_URL'] ?? '';
      final response = await http.post(
        Uri.parse('$baseUrl/gerar_convite'),
        headers: _headersAuth(),
        body: jsonEncode({"grupo_id": idGrupo}),
      );

      final dados = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        _exibirDialogoCodigoGerado(dados['codigo']);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(dados['erro'] ?? 'Erro ao gerar convite'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro de conexão.'), backgroundColor: Colors.red));
    }
  }

  Future<void> _entrarEmGrupoComCodigo(String codigo) async {
    if (codigo.isEmpty) return;
    try {
      final baseUrl = dotenv.env['API_URL'] ?? '';
      final response = await http.post(
        Uri.parse('$baseUrl/entrar_grupo'),
        headers: _headersAuth(),
        body: jsonEncode({"codigo": codigo.toUpperCase()}),
      );

      final dados = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(dados['mensagem']), backgroundColor: Colors.green));
        _buscarGruposDaApi();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(dados['erro'] ?? 'Erro ao entrar'), backgroundColor: Colors.orange));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro de conexão.'), backgroundColor: Colors.red));
    }
  }

  // ==========================================================
  // FUNÇÕES PARA CRIAR NOVO GRUPO
  // ==========================================================
  void _exibirDialogoNovoGrupo() {
    final nomeController = TextEditingController();
    final orcamentoController = TextEditingController();
    String iconeSelecionado = 'shopping_cart'; // Ícone padrão

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Novo Grupo de Compras'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nomeController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nome do Grupo', prefixIcon: Icon(Icons.shopping_bag)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: orcamentoController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Orçamento (Opcional)', prefixText: 'R\$ ', prefixIcon: Icon(Icons.account_balance_wallet)),
                ),
                const SizedBox(height: 20),
                const Text('Ícone do Grupo:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _iconesDisponiveis.entries.map((entry) {
                    bool isSelected = iconeSelecionado == entry.key;
                    return GestureDetector(
                      onTap: () => setDialogState(() => iconeSelecionado = entry.key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250), // Tempo da animação
                        curve: Curves.easeInOut, // Curva suave de entrada e saída
                        width: 50,  
                        height: 50,         
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.green.withValues(alpha: 0.2) : Colors.transparent,
                          // Deixei a borda sempre com width 2, mas transparente quando não selecionado para evitar pulos
                          border: Border.all(
                            color: isSelected ? Colors.green : Colors.grey.withValues(alpha: 0.3), 
                            width: 2 
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(entry.value, color: isSelected ? Colors.green : Colors.grey),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                double orcamento = double.tryParse(orcamentoController.text.replaceAll(',', '.')) ?? 0.0;
                _criarNovoGrupoNaApi(nomeController.text.trim(), orcamento, iconeSelecionado);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              child: const Text('Criar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _criarNovoGrupoNaApi(String nome, double orcamento, String icone) async {
    if (nome.isEmpty) return;

    setState(() => _carregando = true);

    try {
      final baseUrl = dotenv.env['API_URL'] ?? '';
      
      final response = await http.post(
        Uri.parse('$baseUrl/grupos'),
        headers: _headersAuth(),
        body: jsonEncode({
          "nome": nome,
          "icone": icone, // Envia o ícone selecionado
          "orcamento": orcamento
        }),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 201) {
        final dados = jsonDecode(response.body);
        final novoId = int.tryParse(dados['id'].toString()) ?? 0;

        await _buscarGruposDaApi();

        if (novoId > 0) {
          _trocarGrupo(novoId, nome, orcamento);
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grupo criado com sucesso!'), backgroundColor: Colors.green),
        );
      } else {
        throw Exception('Erro da API');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao criar grupo. Verifique a conexão.'), backgroundColor: Colors.red),
      );
      setState(() => _carregando = false);
    }
  }

  // ==========================================================
  // FUNÇÕES PARA EDITAR E DELETAR GRUPOS
  // ==========================================================
  void _exibirOpcoesGrupo(int idGrupo, String nomeAtual, double orcamentoAtual) {
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
              title: const Text('Editar Grupo'), // Mudamos o título
              subtitle: const Text('Alterar nome ou orçamento'), // Adicionamos subtítulo
              onTap: () {
                Navigator.pop(context);
                _exibirDialogoEditarGrupo(idGrupo, nomeAtual, orcamentoAtual); // Passa o orçamento para o diálogo
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.green),
              title: const Text('Compartilhar Grupo'),
              subtitle: const Text('Gerar código de convite'),
              onTap: () {
                Navigator.pop(context);
                _gerarCodigoConvite(idGrupo);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Excluir Grupo'),
              subtitle: const Text('Isso apagará todos os itens dentro dele!'),
              onTap: () {
                Navigator.pop(context); 
                _confirmarExclusaoGrupo(idGrupo, nomeAtual);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _exibirDialogoEditarGrupo(int idGrupo, String nomeAtual, double orcamentoAtual) {
    final nomeController = TextEditingController(text: nomeAtual);
    // Ele preenche o campo com o orçamento exato do grupo clicado
    final orcamentoController = TextEditingController(
      text: orcamentoAtual > 0 ? orcamentoAtual.toStringAsFixed(2) : ''
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Grupo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nome do grupo', prefixIcon: Icon(Icons.edit)),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: orcamentoController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Orçamento (R\$)', prefixIcon: Icon(Icons.account_balance_wallet)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              double orc = double.tryParse(orcamentoController.text.replaceAll(',', '.')) ?? 0.0;
              _editarGrupoNaApi(idGrupo, nomeController.text.trim(), orc); 
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Future<void> _editarGrupoNaApi(int id, String novoNome, double novoOrcamento) async {
    if (novoNome.isEmpty) return;
    try {
      final baseUrl = dotenv.env['API_URL'] ?? '';
      final response = await http.put(
        Uri.parse('$baseUrl/grupos'),
        headers: _headersAuth(),
        // Envia o orçamento junto no pacote (JSON) para o PHP!
        body: jsonEncode({"id": id, "nome": novoNome, "orcamento": novoOrcamento}),
      );
      if (response.statusCode == 200) {
        if (_grupoId == id) {
          setState(() { 
            _nomeGrupoAtual = novoNome; 
            _orcamentoAtual = novoOrcamento; 
          });
        }
        await _buscarGruposDaApi();
      }
    } catch (e) {
      debugPrint("Erro ao editar grupo: $e");
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
              _trocarGrupo(int.parse(_listaGruposApi[0]['id'].toString()), _listaGruposApi[0]['nome'], double.tryParse(_listaGruposApi[0]['orcamento']?.toString() ?? '0') ?? 0.0);
            } else {
              setState(() { _grupoId = 0; _nomeGrupoAtual = 'Sem Grupos'; _itens = []; });
            }
          }
        }
      } catch (e) {
        debugPrint("Erro ao deletar grupo: $e");
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
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 10,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.elasticOut,
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: child,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_rounded, size: 64, color: Colors.green),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Text(
                    'Lista Finalizada!',
                    style: TextStyle(
                      fontSize: 22, 
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onBackground
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Todos os itens pendentes foram processados.\nVocê fechou ${res['itens_fechados']} itens.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15, 
                      color: Colors.grey.shade500,
                      height: 1.3
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Botão Largo e Elegante
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Excelente', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    ),
                  ),
                ],
              ),
            ),
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
      builder: (context) => StatefulBuilder( // Adicionei isso para a animação de texto funcionar
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Novo Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Produto',
                  prefixIcon: const Icon(Icons.shopping_basket),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.barcode_reader, color: Colors.green),
                    onPressed: () async {
                      final String? code = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
                      );

                      if (code != null && code.isNotEmpty) {
                        setDialogState(() {
                          nomeController.text = "Buscando...";
                        });

                        final nomeIdentificado = await _buscarNomePeloEAN(code);

                        setDialogState(() {
                          nomeController.text = nomeIdentificado;
                        });

                        // Se encontrou o nome, já pula o foco para o campo de preço.
                        if (nomeIdentificado != "Não encontrado (digite o nome)" && 
                            nomeIdentificado != "Erro na busca (API)") {
                           // O Flutter pode precisar de um micro-delay para o foco funcionar
                           Future.delayed(const Duration(milliseconds: 100), () {
                           });
                        }
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: precoController,
                      decoration: const InputDecoration(labelText: 'Preço (R\$)'),
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
      ),
    );
  }

  Widget _construirBarraOrcamento() {
    if (_orcamentoAtual <= 0) return const SizedBox.shrink(); 

    double totalAtual = _calcularTotalParcial(); 
    double percentagem = totalAtual / _orcamentoAtual;
    bool estourou = percentagem > 1.0;
    
    double percentagemBarra = percentagem > 1.0 ? 1.0 : percentagem;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Orçamento: R\$ ${_orcamentoAtual.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                'R\$ ${totalAtual.toStringAsFixed(2)}',
                style: TextStyle(fontWeight: FontWeight.bold, color: estourou ? Colors.red : Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percentagemBarra,
              minHeight: 10,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(estourou ? Colors.red : (percentagem > 0.8 ? Colors.orange : Colors.green)),
            ),
          ),
          if (estourou)
            const Padding(
              padding: EdgeInsets.only(top: 4.0),
              child: Text('Atenção: Orçamento ultrapassado!', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
            )
        ],
      ),
    );
  }

  void _exibirDialogoCodigoGerado(String codigo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Convite Gerado!', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Passe este código para quem vai dividir o grupo com você:', textAlign: TextAlign.center),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green)),
              child: SelectableText(
                codigo, // Permite o usuário segurar o dedo para copiar
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2.0, color: Colors.green),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        ],
      ),
    );
  }

  void _exibirDialogoEntrarGrupo() {
    final codigoController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Entrar em um Grupo'),
        content: TextField(
          controller: codigoController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Código do Convite (ex: MKT-1234)', prefixIcon: Icon(Icons.group_add)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _entrarEmGrupoComCodigo(codigoController.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Entrar'),
          ),
        ],
      ),
    );
  }

  Future<String> _buscarNomePeloEAN(String code) async {
    try {
      final baseUrl = dotenv.env['API_URL'] ?? '';
      final response = await http.get(
        Uri.parse('$baseUrl/produtos?ean=$code'), 
        headers: _headersAuth(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final dados = jsonDecode(response.body);
        return dados['nome'] ?? "Produto não identificado";
      } else if (response.statusCode == 404) {
        return "Não encontrado (digite o nome)";
      } else {
        return "Erro na busca (API)";
      }
    } catch (e) {
      debugPrint("Erro na busca: $e");
      return "Sem conexão com o servidor";
    }
  }

  Widget _buildEmptyState(String nomeGrupo, ThemeData theme) {
    final onBackgroundColor = theme.colorScheme.onBackground;
    final surfaceColor = theme.colorScheme.surface;

    return Center(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(theme.brightness == Brightness.dark ? 0.2 : 0.04),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            child: Column(
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 1.0, end: 1.1),
                  duration: const Duration(seconds: 2),
                  curve: Curves.easeInOut,
                  builder: (context, scale, child) {
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: Icon(Icons.add_shopping_cart_outlined, size: 80, color: Colors.green.withOpacity(0.5)),
                ),
                const SizedBox(height: 30),
                Text(
                  'Sua lista "$nomeGrupo" está vazia!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: onBackgroundColor),
                ),
                const SizedBox(height: 10),
                Text(
                  'Clique no botão verde (+) para adicionar os itens que você quer comprar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: onBackgroundColor.withOpacity(0.6)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 100), 
        ],
      ),
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
      return _buildEmptyState(_nomeGrupoAtual, Theme.of(context));
    }

    return Column(
      children: [
        _construirBarraOrcamento(),
        
        Expanded(
          child: ListView.builder(
            itemCount: _itens.length,
            padding: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 100), 
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
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  decoration: BoxDecoration(
                    color: isFinalizado 
                        ? Theme.of(context).colorScheme.surface.withOpacity(0.5) 
                        : (isAguardando ? Colors.orange.withOpacity(0.05) : Theme.of(context).colorScheme.surface),
                    borderRadius: BorderRadius.circular(16), 
                    boxShadow: isAguardando ? [] : [
                      BoxShadow(
                        color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ],
                    border: isAguardando ? Border.all(color: Colors.orange.shade300, width: 1) : Border.all(color: Colors.transparent),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isFinalizado ? Colors.grey.withOpacity(0.15) : (isAguardando ? Colors.orange.withOpacity(0.15) : Colors.green.withOpacity(0.15)),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFinalizado ? Icons.check : (isAguardando ? Icons.cloud_upload : Icons.shopping_bag_outlined), 
                        color: isFinalizado ? Colors.grey : (isAguardando ? Colors.orange : Colors.green), 
                        size: 24
                      ),
                    ),
                    title: Text(
                      nomeProduto, 
                      style: TextStyle(
                        decoration: isFinalizado ? TextDecoration.lineThrough : null, 
                        color: isFinalizado ? Colors.grey : (isAguardando ? Colors.orange[900] : Theme.of(context).colorScheme.onBackground), 
                        fontWeight: FontWeight.w700, 
                        fontSize: 16
                      )
                    ),
                    subtitle: Text(
                      isAguardando ? 'Aguardando rede...' : 'Qtd/Peso ajustável', 
                      style: TextStyle(fontSize: 12, color: isAguardando ? Colors.orange[800] : Colors.grey[500], fontStyle: isAguardando ? FontStyle.italic : FontStyle.normal)
                    ),
                    trailing: Text(
                      'R\$ ${preco.toStringAsFixed(2)}', 
                      style: TextStyle(
                        color: isFinalizado ? Colors.grey : (isAguardando ? Colors.orange[900] : Colors.green), 
                        fontWeight: FontWeight.w900, 
                        fontSize: 17
                      )
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final temItensPendentes = _itens.any((i) => i['status'] == 'pendente' || i['status'] == 'aguardando_sync');

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.4), 
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(30),
          ),
        ),
        title: Padding(
          padding: const EdgeInsets.only(left: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(_nomeGrupoAtual, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  if (_modoOffline) ...[const SizedBox(width: 8), const Icon(Icons.cloud_off, size: 18, color: Colors.yellowAccent)]
                ],
              ),
              const SizedBox(height: 2),
              Text('Olá, $_nomeUsuarioAtual', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: IconButton(
              icon: const Icon(Icons.receipt_long, size: 20),
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
          ),
          const SizedBox(width: 10),
          Container(
            margin: const EdgeInsets.only(top: 18, right: 16),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: 'Sincronizar',
              onPressed: () async { 
                await _buscarGruposDaApi();
                await buscarItens(); 
              },
            ),
          )
        ],
      ),
      drawer: Drawer(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CABEÇALHO CUSTOMIZADO E MODERNO
            Container(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.grey.shade900 
                    : Colors.green.shade50,
                border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1), width: 1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.green,
                    child: Text(
                      _nomeUsuarioAtual.isNotEmpty ? _nomeUsuarioAtual[0].toUpperCase() : 'U',
                      style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _nomeUsuarioAtual,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onBackground),
                  ),
                  Text(
                    'Meus Grupos de Compras',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: _listaGruposApi.isEmpty 
                ? Center(child: Text('Nenhum grupo encontrado.', style: TextStyle(color: Colors.grey.shade500)))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 20), 
                    itemCount: _listaGruposApi.length,
                    itemBuilder: (context, index) {
                      final grupo = _listaGruposApi[index];
                      final idGrupo = int.parse(grupo['id'].toString());
                      final isSelected = _grupoId == idGrupo;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.green.withOpacity(0.12) : Colors.transparent,
                          borderRadius: BorderRadius.circular(30), 
                        ),
                        child: ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          leading: Icon(
                            _iconesDisponiveis[grupo['icone']] ?? Icons.folder, // Busca no mapa ou usa pasta como fallback
                            color: isSelected ? Colors.green : Colors.grey.shade600,
                          ),
                          title: Text(
                            grupo['nome'],
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? Colors.green.shade700 : Theme.of(context).colorScheme.onBackground,
                            ),
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.more_vert, size: 20, color: isSelected ? Colors.green.shade700 : Colors.grey.shade400),
                            onPressed: () {
                              Navigator.pop(context);
                              // Pegamos o orçamento correto daquele item da lista!
                              double orcamentoDoItem = double.tryParse(grupo['orcamento']?.toString() ?? '0') ?? 0.0;
                              _exibirOpcoesGrupo(idGrupo, grupo['nome'], orcamentoDoItem);
                            },
                          ),
                          onTap: () {
                            Navigator.pop(context); 
                            double orc = double.tryParse(grupo['orcamento']?.toString() ?? '0') ?? 0.0;
                            _trocarGrupo(idGrupo, grupo['nome'], orc);
                          },
                        ),
                      );
                    },
                  ),
            ),
            
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, -5))],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Botão Destacado de Novo Grupo
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _exibirDialogoNovoGrupo();
                      },
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Criar Novo Grupo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: BorderSide(color: Colors.green.shade300, width: 2),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    ListTile(
                      leading: const Icon(Icons.group_add, color: Colors.blue),
                      title: const Text('Entrar via Código', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                      onTap: () {
                        Navigator.pop(context);
                        _exibirDialogoEntrarGrupo();
                      },
                    ),

                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.account_balance_wallet, color: Colors.blue),
                      title: const Text('Finanças Mensais', style: TextStyle(fontWeight: FontWeight.bold)),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const FinancasScreen()),
                        );
                      },
                    ),
                    // Dashboard
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      leading: const Icon(Icons.pie_chart_outline, color: Colors.blue),
                      title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.w600)),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const DashboardScreen()));
                      },
                    ),
                    
                    // Configurações
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      leading: const Icon(Icons.settings_outlined),
                      title: const Text('Configurações', style: TextStyle(fontWeight: FontWeight.w600)),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const ConfiguracoesScreen()));
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: _buildBody(),
      floatingActionButton: Listener(
        onPointerDown: (_) => setState(() => _opacidadeFab = 1.0),
        onPointerUp: (_) => setState(() => _opacidadeFab = 0.4),
        child: AnimatedOpacity(
          opacity: _opacidadeFab,
          duration: const Duration(milliseconds: 200),
          child: FloatingActionButton(
           onPressed: () {
              setState(() => _opacidadeFab = 0.4); 
              _exibirDialogoAdicionar();
            },
            backgroundColor: Colors.green, 
            foregroundColor: Colors.white,
            child: const Icon(Icons.add),
          ),
        ),
      ),
      bottomNavigationBar: temItensPendentes && !_carregando
          ? SafeArea(
              child: Container(
                margin: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0), 
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(25), 
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.08),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Pendente', style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                        Text(
                          'R\$ ${_calcularTotalParcial().toStringAsFixed(2)}', 
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.green),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: _modoOffline ? null : _finalizarLista,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Finalizar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green, 
                        foregroundColor: Colors.white, 
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0, 
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}