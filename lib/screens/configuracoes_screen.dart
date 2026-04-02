import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
  bool _isDarkMode = false;
  String _nomeUsuario = "Usuário";
  String _emailUsuario = "Carregando...";

  @override
  void initState() {
    super.initState();
    _carregarDadosLocais();
  }

  Future<void> _carregarDadosLocais() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nomeUsuario = prefs.getString('usuario_nome') ?? 'Usuário';
      _emailUsuario = prefs.getString('usuario_email') ?? 'marketlist@app.com';
      
      _isDarkMode = themeNotifier.value == ThemeMode.dark; 
    });
  }

  // ==========================================
  // LÓGICA DE API E AÇÕES (MANTIDA IGUAL)
  // ==========================================
  Future<void> _fazerLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
  }

  Future<void> _confirmarExclusaoConta() async {
    bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30), SizedBox(width: 10), Text('Excluir Conta?', style: TextStyle(color: Colors.red))]),
        content: const Text('Esta ação é irreversível.\n\nTodos os seus dados serão apagados permanentemente.', style: TextStyle(fontSize: 16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Sim, Excluir')),
        ],
      ),
    );
    if (confirmar == true) _excluirContaNaApi();
  }

  Future<void> _excluirContaNaApi() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tokenJwt = prefs.getString('jwt_token') ?? '';
      final baseUrl = dotenv.env['API_URL'] ?? '';

      showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.red)));

      final response = await http.delete(
        Uri.parse('$baseUrl/conta'),
        headers: {'x-api-key': dotenv.env['API_KEY'] ?? '', 'Authorization': 'Bearer $tokenJwt'},
      );
      if (!mounted) return; 

      Navigator.pop(context);
      if (response.statusCode == 200) {
        _fazerLogout();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao excluir conta.'), backgroundColor: Colors.red));
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sem conexão.'), backgroundColor: Colors.red));
    }
  }

  void _exibirDialogoMudarSenha() {
    final senhaAtualController = TextEditingController();
    final novaSenhaController = TextEditingController();
    bool obscureAtual = true;
    bool obscureNova = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Alterar Senha'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: senhaAtualController,
                obscureText: obscureAtual,
                decoration: InputDecoration(
                  labelText: 'Senha Atual',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(icon: Icon(obscureAtual ? Icons.visibility_off : Icons.visibility), onPressed: () => setDialogState(() => obscureAtual = !obscureAtual)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: novaSenhaController,
                obscureText: obscureNova,
                decoration: InputDecoration(
                  labelText: 'Nova Senha',
                  prefixIcon: const Icon(Icons.lock_reset),
                  suffixIcon: IconButton(icon: Icon(obscureNova ? Icons.visibility_off : Icons.visibility), onPressed: () => setDialogState(() => obscureNova = !obscureNova)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            ElevatedButton(onPressed: () { Navigator.pop(context); _mudarSenhaNaApi(senhaAtualController.text, novaSenhaController.text); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Salvar')),
          ],
        ),
      ),
    );
  }

  Future<void> _mudarSenhaNaApi(String atual, String nova) async {
    if (atual.isEmpty || nova.isEmpty) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final baseUrl = dotenv.env['API_URL'] ?? '';
      final tokenJwt = prefs.getString('jwt_token') ?? '';

      final response = await http.put(
        Uri.parse('$baseUrl/mudar_senha'),
        headers: {
          'Content-Type': 'application/json', 
          'x-api-key': dotenv.env['API_KEY'] ?? '', 
          'Authorization': 'Bearer $tokenJwt'
        },
        body: jsonEncode({"senha_atual": atual, "nova_senha": nova}),
      );

      if (!mounted) return;

      final dados = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(dados['status'] ?? 'Senha alterada!'), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(dados['erro'] ?? 'Erro ao alterar senha'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sem conexão com o servidor.'), backgroundColor: Colors.red));
    }
  }

  // ==========================================
  // CONSTRUÇÃO DA UI (CORREÇÃO DE ÍCONES)
  // ==========================================
  Widget _buildConfigCard({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildNeutralIconContainer(IconData icon, {Color? color}) {
    final onBackgroundColor = Theme.of(context).colorScheme.onSurface;
    
    return Container(
      width: 42,  
      height: 42, 
      decoration: BoxDecoration(
        color: onBackgroundColor.withValues(alpha:0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(icon, color: color ?? onBackgroundColor.withValues(alpha:0.7), size: 22),
      ),
    );
  }
  // ==========================================
  // O NOSSO NOVO BOTÃO ANIMADO SOL/LUA (CORREÇÃO LENTIDÃO)
  // ==========================================
  Widget _buildAnimatedToggle() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isDarkMode = !_isDarkMode;
        });
        

        Future.delayed(const Duration(milliseconds: 250), () {
          themeNotifier.value = _isDarkMode ? ThemeMode.dark : ThemeMode.light;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350), 
        curve: Curves.easeInOut,
        width: 75,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          color: _isDarkMode ? Colors.indigo.shade900 : Colors.lightBlue.shade300,
          boxShadow: [
            BoxShadow(
              color: (_isDarkMode ? Colors.indigo : Colors.lightBlue).withValues(alpha:0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ]
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          alignment: _isDarkMode ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, animation) => RotationTransition(turns: animation, child: child),
                child: _isDarkMode
                    ? const Icon(Icons.nightlight_round, color: Colors.indigo, size: 20, key: ValueKey('moon'))
                    : const Icon(Icons.wb_sunny_rounded, color: Colors.orange, size: 20, key: ValueKey('sun')),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Configurações', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, elevation: 0, foregroundColor: theme.colorScheme.onSurface, centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          // CABEÇALHO DO PERFIL
          Center(
            child: Column(
              children: [
                CircleAvatar(radius: 50, backgroundColor: Colors.green.withValues(alpha:0.15), child: Text(_nomeUsuario.isNotEmpty ? _nomeUsuario[0].toUpperCase() : 'U', style: const TextStyle(fontSize: 40, color: Colors.green, fontWeight: FontWeight.bold))),
                const SizedBox(height: 16),
                Text(_nomeUsuario, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                Text(_emailUsuario, style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
                const SizedBox(height: 30),
              ],
            ),
          ),

          // PREFERÊNCIAS E CONTA
          const Padding(padding: EdgeInsets.only(left: 8, bottom: 8), child: Text('PREFERÊNCIAS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2))),
          _buildConfigCard(
            children: [
              ListTile(
                leading: _buildNeutralIconContainer(Icons.palette_rounded, color: Colors.purple),
                title: const Text('Aparência', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: _buildAnimatedToggle(), 
              ),
              Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, indent: 60),
              ListTile(
                leading: _buildNeutralIconContainer(Icons.lock_outline, color: Colors.blue),
                title: const Text('Alterar Senha', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: _exibirDialogoMudarSenha,
              ),
            ],
          ),

          // ZONA DE PERIGO E SAÍDA
          const Padding(padding: EdgeInsets.only(left: 8, bottom: 8), child: Text('ZONA DE PERIGO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2))),
          _buildConfigCard(
            children: [
              ListTile(
                leading: _buildNeutralIconContainer(Icons.delete_forever, color: Colors.red),
                title: const Text('Excluir minha conta', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
                onTap: _confirmarExclusaoConta,
              ),
              Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, indent: 60),
              ListTile(
                leading: _buildNeutralIconContainer(Icons.logout), // Logout neutro
                title: const Text('Sair do Aplicativo', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: _fazerLogout,
              ),
            ],
          ),

          const SizedBox(height: 20),
          Center(child: Text('MarketList v2.0.0', style: TextStyle(color: Colors.grey.shade400, fontSize: 12))),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}