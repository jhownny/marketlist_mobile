import 'package:flutter/material.dart';
import 'dart:convert'; // Para converter o JSON
import 'package:http/http.dart' as http; // Para fazer as requisições
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Para ler o arquivo .env

Future<void> main() async {
  // Garante que o Flutter esteja inicializado antes de carregar configurações
  WidgetsFlutterBinding.ensureInitialized();

  // Carrega as variáveis de ambiente do arquivo .env
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
  bool _carregando = true;
  String _erro = '';

  @override
  void initState() {
    super.initState();
    buscarItens();
  }

  // Função responsável por conectar API PHP
  Future<void> buscarItens() async {
    setState(() {
      _carregando = true;
      _erro = '';
    });

    try {
      // Recupera as configurações do .env
      final baseUrl = dotenv.env['API_URL'] ?? '';
      final apiKey = dotenv.env['API_KEY'] ?? '';
      
      // ID fixo para teste (criar uma lógica de login depois)
      const String usuarioId = '3'; 

      // Validação simples para evitar crash se o .env estiver vazio
      if (baseUrl.isEmpty || apiKey.isEmpty) {
        throw Exception('Configuração do .env incompleta (API_URL ou API_KEY faltando).');
      }

      final url = Uri.parse('$baseUrl/itens?usuario_id=$usuarioId');

      print('Buscando dados em: $url'); // Log para ajudar no debug

      // Requisição GET
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey, // Envia a chave segura no cabeçalho
        },
      );

      // 4. Verifica a resposta
      if (response.statusCode == 200) {
        final dados = jsonDecode(response.body);
        
        setState(() {
          _itens = dados;
          _carregando = false;
        });
      } else {
        // Erro vindo do servidor (ex: 403 Acesso Negado, 500 Erro PHP)
        setState(() {
          _erro = 'Erro do Servidor (${response.statusCode}):\n${response.body}';
          _carregando = false;
        });
      }
    } catch (e) {
      // Erro de conexão (sem internet, URL errada e etc...)
      setState(() {
        _erro = 'Falha na conexão:\n$e';
        _carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MarketList Mobile'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: buscarItens, // Botão para recarregar a lista
          )
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Adicionar item: Em breve!'))
          );
        },
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // Função auxiliar para decidir o que mostrar na tela
  Widget _buildBody() {
    // Estado 1: Carregando
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    // Estado 2: Erro
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

    // Estado 3: Lista Vazia
    if (_itens.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_basket_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 10),
            Text(
              'Sua lista está vazia!',
              style: TextStyle(color: Colors.grey[600], fontSize: 18),
            ),
          ],
        ),
      );
    }

    // Estado 4: Lista com Itens
    return ListView.builder(
      itemCount: _itens.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final item = _itens[index];
        
        // Mapeamento seguro dos dados (evita erro se vier null do PHP)
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
            onTap: () {
              print('Item clicado: ID ${item['id']}');
            },
          ),
        );
      },
    );
  }
}