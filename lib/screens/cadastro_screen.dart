import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'login_screen.dart'; 

class CadastroScreen extends StatefulWidget {
  const CadastroScreen({super.key});

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();

  bool _carregando = false;
  bool _ocultarSenha = true;

  Future<void> _cadastrar() async {
    final nome = _nomeController.text.trim();
    final email = _emailController.text.trim();
    final senha = _senhaController.text.trim();

    if (nome.isEmpty || email.isEmpty || senha.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos!')),
      );
      return;
    }

    setState(() => _carregando = true);

    try {
      final baseUrl = dotenv.env['API_URL'] ?? '';
      final apiKey = dotenv.env['API_KEY'] ?? '';

      final response = await http.post(
        Uri.parse('$baseUrl/usuarios'),
        headers: {'Content-Type': 'application/json', 'x-api-key': apiKey},
        body: jsonEncode({"nome": nome, "email": email, "senha": senha}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        if (!mounted) return;
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => VerificacaoEmailScreen(email: email)),
        );
        
      } else {
        final resultado = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(resultado['erro'] ?? 'Erro ao criar conta.'), backgroundColor: Colors.red),
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: onBackgroundColor),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.person_add_alt_1, size: 60, color: Colors.green),
              ),
              const SizedBox(height: 20),
              Text(
                'Criar Nova Conta',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: onBackgroundColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Junte-se ao MarketList e organize suas compras.',
                style: TextStyle(fontSize: 14, color: onBackgroundColor.withOpacity(0.7)),
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
                    // Campo Nome
                    TextField(
                      controller: _nomeController,
                      textCapitalization: TextCapitalization.words,
                      style: TextStyle(color: onBackgroundColor),
                      decoration: InputDecoration(
                        labelText: 'Nome',
                        labelStyle: TextStyle(color: onBackgroundColor.withOpacity(0.6)),
                        prefixIcon: Icon(Icons.person_outline, color: onBackgroundColor.withOpacity(0.6)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: fillColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
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

                    // Botão Cadastrar
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _carregando ? null : _cadastrar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        child: _carregando
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Criar Conta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
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

// ==========================================================
// TELA DE VERIFICAÇÃO DE E-MAIL (OTP)
// ==========================================================
class VerificacaoEmailScreen extends StatefulWidget {
  final String email;
  const VerificacaoEmailScreen({super.key, required this.email});

  @override
  State<VerificacaoEmailScreen> createState() => _VerificacaoEmailScreenState();
}

class _VerificacaoEmailScreenState extends State<VerificacaoEmailScreen> {
  final TextEditingController _codigoController = TextEditingController();
  bool _carregando = false;

  Future<void> _verificarCodigo() async {
    final codigo = _codigoController.text.trim();

    if (codigo.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O código deve ter 6 números!')));
      return;
    }

    setState(() => _carregando = true);

    try {
      final baseUrl = dotenv.env['API_URL'] ?? '';
      final apiKey = dotenv.env['API_KEY'] ?? '';

      final response = await http.post(
        Uri.parse('$baseUrl/verificar_email'),
        headers: {'Content-Type': 'application/json', 'x-api-key': apiKey},
        body: jsonEncode({"email": widget.email, "codigo": codigo}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('E-mail verificado! Você já pode fazer login.'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
      } else {
        final resultado = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resultado['erro'] ?? 'Código inválido.'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro de conexão.'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onBackgroundColor = theme.colorScheme.onBackground;
    final surfaceColor = theme.colorScheme.surface;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: IconThemeData(color: onBackgroundColor)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mark_email_read, size: 80, color: Colors.green),
              const SizedBox(height: 20),
              Text('Verifique seu E-mail', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: onBackgroundColor)),
              const SizedBox(height: 10),
              Text('Enviamos um código de 6 dígitos para:\n${widget.email}', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: onBackgroundColor.withOpacity(0.7))),
              const SizedBox(height: 30),
              Card(
                color: surfaceColor,
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _codigoController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 24, letterSpacing: 10, fontWeight: FontWeight.bold, color: onBackgroundColor),
                        decoration: InputDecoration(
                          counterText: '', 
                          hintText: '000000',
                          hintStyle: TextStyle(color: onBackgroundColor.withOpacity(0.3))
                        ),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _carregando ? null : _verificarCodigo,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          child: _carregando ? const CircularProgressIndicator(color: Colors.white) : const Text('Confirmar Código', style: TextStyle(fontSize: 18)),
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