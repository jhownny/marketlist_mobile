import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import '../main.dart';

class ConfiguracoesScreen extends StatefulWidget {
  const ConfiguracoesScreen({super.key});

  @override
  State<ConfiguracoesScreen> createState() => _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends State<ConfiguracoesScreen> {
  // Variáveis para o formulário de senha
  final _senhaAtualController = TextEditingController();
  final _novaSenhaController = TextEditingController();
  bool _ocultarSenha = true;
  bool _carregandoSenha = false;

  Future<Map<String, String>> _headersAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';
    final apiKey = dotenv.env['API_KEY'] ?? '';
    return {'Content-Type': 'application/json', 'x-api-key': apiKey, 'Authorization': 'Bearer $token'};
  }

  // =======================================
  // LÓGICA DE MUDAR SENHA (NOVA)
  // =======================================
  void _exibirDialogoMudarSenha() {
    _senhaAtualController.clear();
    _novaSenhaController.clear();
    _ocultarSenha = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder( // StatefulBuilder permite usar setState dentro do Dialog
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Mudar Senha'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _senhaAtualController,
                    obscureText: _ocultarSenha,
                    decoration: const InputDecoration(labelText: 'Senha Atual', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _novaSenhaController,
                    obscureText: _ocultarSenha,
                    decoration: InputDecoration(
                      labelText: 'Nova Senha',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_ocultarSenha ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setStateDialog(() => _ocultarSenha = !_ocultarSenha),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  onPressed: _carregandoSenha ? null : () => _salvarNovaSenha(setStateDialog),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  child: _carregandoSenha ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Salvar'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _salvarNovaSenha(Function setStateDialog) async {
    final senhaAtual = _senhaAtualController.text;
    final novaSenha = _novaSenhaController.text;

    if (senhaAtual.isEmpty || novaSenha.isEmpty) return;

    setStateDialog(() => _carregandoSenha = true);

    try {
      final baseUrl = dotenv.env['API_URL'] ?? '';
      final response = await http.put(
        Uri.parse('$baseUrl/mudar_senha'),
        headers: await _headersAuth(),
        body: jsonEncode({"senha_atual": senhaAtual, "nova_senha": novaSenha}),
      );

      setStateDialog(() => _carregandoSenha = false);

      if (response.statusCode == 200) {
        Navigator.pop(context); // Fecha o dialog
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Senha alterada com sucesso!'), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Senha atual incorreta.'), backgroundColor: Colors.red));
      }
    } catch (e) {
      setStateDialog(() => _carregandoSenha = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao conectar ao servidor.'), backgroundColor: Colors.red));
    }
  }

  // Lógica de Sair (Logout)
  Future<void> _fazerLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
  }

  // Lógica de Excluir Conta (LGPD)
  Future<void> _excluirConta() async {
    // 1. O Alerta de Confirmação (Double Opt-in)
    bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Atenção!', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: const Text(
          'Tem certeza que deseja apagar sua conta?\n\n'
          'Isso apagará TODOS os seus grupos, itens e histórico de compras permanentemente. '
          'Essa ação NÃO pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Excluir Definitivamente'),
          ),
        ],
      ),
    );

    // 2. Se o usuário confirmou, chama a API
    if (confirmar == true) {
      try {
        final baseUrl = dotenv.env['API_URL'] ?? '';
        final response = await http.delete(
          Uri.parse('$baseUrl/conta'),
          headers: await _headersAuth(), // Envia o Token de segurança!
        );

        if (response.statusCode == 200) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
          
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Sua conta foi excluída com sucesso.'), backgroundColor: Colors.grey
            ));
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Erro ao excluir conta. Tente novamente.'), backgroundColor: Colors.red
          ));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Erro de conexão com o servidor.'), backgroundColor: Colors.red
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações', style: TextStyle(fontSize: 18))),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: Text('Preferências', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeNotifier, 
                  builder: (context, currentMode, child) {
                    final isDarkMode = currentMode == ThemeMode.dark;
                    
                    return SwitchListTile(
                      title: const Text('Modo Escuro'),
                      secondary: Icon(
                        isDarkMode ? Icons.dark_mode : Icons.light_mode, 
                        color: isDarkMode ? Colors.yellow : Colors.orange
                      ),
                      value: isDarkMode,
                      activeColor: Colors.green,
                      onChanged: (bool value) {

                        themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                        
                        SharedPreferences.getInstance().then((prefs) {
                          prefs.setBool('isDark', value);
                        });
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: Text('Conta', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.password),
                  title: const Text('Mudar Senha'),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: _exibirDialogoMudarSenha,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.exit_to_app),
                  title: const Text('Sair do Aplicativo'),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: _fazerLogout,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: Text('Zona de Perigo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red)),
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Excluir Minha Conta', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              subtitle: const Text('Apaga todos os seus dados para sempre.'),
              onTap: _excluirConta,
            ),
          ),
        ],
      ),
    );
  }
}