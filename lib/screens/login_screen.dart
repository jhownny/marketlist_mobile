import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'lista_screen.dart'; // Para ir para a lista após logar
import 'cadastro_screen.dart'; // Para abrir a tela de cadastro
import 'recuperacao_screen.dart';

// ==========================================================
// TELA DE VERIFICAÇÃO DE LOGIN
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
    // Agora verificamos se o TOKEN existe, não apenas o ID
    final token = prefs.getString('jwt_token');

    if (token != null && token.isNotEmpty) {
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
      body: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}

// ==========================================================
// TELA DE LOGIN
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
  bool _ocultarSenha = true;

  Future<void> _fazerLogin() async {
    final email = _emailController.text.trim();
    final senha = _senhaController.text.trim();

    if (email.isEmpty || senha.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha e-mail e senha!')));
      return;
    }

    setState(() => _carregando = true);

    try {
      final baseUrl = dotenv.env['API_URL'] ?? '';
      final apiKey = dotenv.env['API_KEY'] ?? '';

      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json', 'x-api-key': apiKey},
        body: jsonEncode({"email": email, "senha": senha}),
      ).timeout(const Duration(seconds: 10));

      final resultado = jsonDecode(response.body);

      if (response.statusCode == 200 && resultado['status'] == 'logado') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('usuario_id', resultado['id'].toString());
        await prefs.setString('usuario_nome', resultado['nome'].toString());
        await prefs.setString('jwt_token', resultado['token']); // Salvando o Token JWT!

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
    // VARIÁVEIS DE TEMA INTELIGENTE
    final theme = Theme.of(context);
    final onBackgroundColor = theme.colorScheme.onBackground;
    final surfaceColor = theme.colorScheme.surface;
    final isDark = theme.brightness == Brightness.dark;
    final fillColor = isDark ? Colors.grey[800] : Colors.grey[50];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                isDark 
                    ? 'assets/Text-MarketList-White-logo.png'
                    : 'assets/Text-MarketList-logo2.png',
                height: 180,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
                ),
                child: Column(
                  children: [
                    // Campo E-mail
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: onBackgroundColor),
                      decoration: InputDecoration(
                        labelText: 'E-mail',
                        labelStyle: TextStyle(color: onBackgroundColor.withOpacity(0.6)),
                        prefixIcon: Icon(Icons.email_outlined, color: onBackgroundColor.withOpacity(0.6)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: fillColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Campo Senha
                    TextField(
                      controller: _senhaController,
                      obscureText: _ocultarSenha,
                      style: TextStyle(color: onBackgroundColor),
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        labelStyle: TextStyle(color: onBackgroundColor.withOpacity(0.6)),
                        prefixIcon: Icon(Icons.lock_outline, color: onBackgroundColor.withOpacity(0.6)),
                        suffixIcon: IconButton(
                          icon: Icon(_ocultarSenha ? Icons.visibility_off : Icons.visibility, color: onBackgroundColor.withOpacity(0.6)),
                          onPressed: () {
                            setState(() { _ocultarSenha = !_ocultarSenha; });
                          },
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: fillColor,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Botão Entrar
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _carregando ? null : _fazerLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        child: _carregando
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Entrar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const RecuperacaoScreen()));
                      },
                      child: Text('Esqueci minha senha', style: TextStyle(color: onBackgroundColor.withOpacity(0.7), fontWeight: FontWeight.w600)),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const CadastroScreen()));
                      },
                      child: const Text('Não tem uma conta? Cadastre-se', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}