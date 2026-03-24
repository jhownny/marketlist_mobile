import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class RecuperacaoScreen extends StatefulWidget {
  const RecuperacaoScreen({super.key});

  @override
  State<RecuperacaoScreen> createState() => _RecuperacaoScreenState();
}

class _RecuperacaoScreenState extends State<RecuperacaoScreen> {
  final _emailController = TextEditingController();
  final _codigoController = TextEditingController();
  final _novaSenhaController = TextEditingController();
  
  bool _carregando = false;
  bool _ocultarNovaSenha = true;
  int _etapaAtual = 1; // 1 = Pede Email | 2 = Pede Código e Nova Senha

  Future<void> _solicitarCodigo() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _carregando = true);
    try {
      final baseUrl = dotenv.env['API_URL'] ?? '';
      final apiKey = dotenv.env['API_KEY'] ?? '';
      
      final response = await http.post(
        Uri.parse('$baseUrl/recuperar_senha'),
        headers: {'Content-Type': 'application/json', 'x-api-key': apiKey},
        body: jsonEncode({"email": email}),
      );

      if (response.statusCode == 200) {
        setState(() => _etapaAtual = 2);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código enviado para o seu e-mail!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
      } else {
        throw Exception();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao conectar com o servidor.'), backgroundColor: Colors.red));
    } finally {
      setState(() => _carregando = false);
    }
  }

  Future<void> _redefinirSenha() async {
    final email = _emailController.text.trim();
    final codigo = _codigoController.text.trim();
    final novaSenha = _novaSenhaController.text.trim();
    
    if (codigo.isEmpty || novaSenha.isEmpty) return;

    setState(() => _carregando = true);
    try {
      final baseUrl = dotenv.env['API_URL'] ?? '';
      final apiKey = dotenv.env['API_KEY'] ?? '';
      
      final response = await http.put(
        Uri.parse('$baseUrl/recuperar_senha'),
        headers: {'Content-Type': 'application/json', 'x-api-key': apiKey},
        body: jsonEncode({"email": email, "codigo": codigo, "nova_senha": novaSenha}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Senha atualizada com sucesso! Faça login.'), backgroundColor: Colors.green));
        Navigator.pop(context); // Volta para a tela de login
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código inválido ou expirado.'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao redefinir a senha.'), backgroundColor: Colors.red));
    } finally {
      setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onBackgroundColor = theme.colorScheme.onBackground;
    final surfaceColor = theme.colorScheme.surface;
    final isDark = theme.brightness == Brightness.dark;
    final fillColor = isDark ? Colors.grey[800] : Colors.grey[50]; // Cor de fundo do campo de texto

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, // Fundo adaptável
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: onBackgroundColor), // Ícone de voltar adaptável
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
                child: Icon(_etapaAtual == 1 ? Icons.lock_reset : Icons.mark_email_read, size: 60, color: Colors.green),
              ),
              const SizedBox(height: 20),
              Text(
                _etapaAtual == 1 ? 'Esqueceu sua senha?' : 'Verifique seu e-mail',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: onBackgroundColor), // Título adaptável
              ),
              const SizedBox(height: 8),
              Text(
                _etapaAtual == 1 
                  ? 'Digite seu e-mail para receber o código.' 
                  : 'Enviamos um código para ${_emailController.text}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: onBackgroundColor.withOpacity(0.7)), // Legenda adaptável
              ),
              const SizedBox(height: 30),

              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: surfaceColor, // Cor do cartão adaptável
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
                ),
                child: Column(
                  children: [
                    if (_etapaAtual == 1) ...[
                      // ETAPA 1: PEDIR E-MAIL
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: onBackgroundColor), // Texto digitado adaptável
                        decoration: InputDecoration(
                          labelText: 'Seu E-mail Cadastrado',
                          labelStyle: TextStyle(color: onBackgroundColor.withOpacity(0.6)), // Rótulo adaptável
                          prefixIcon: Icon(Icons.email_outlined, color: onBackgroundColor.withOpacity(0.6)), // Ícone adaptável
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          filled: true,
                          fillColor: fillColor, // Fundo do campo adaptável
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _carregando ? null : _solicitarCodigo,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                          ),
                          child: _carregando 
                              ? const CircularProgressIndicator(color: Colors.white) 
                              : const Text('Enviar Código', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ] else ...[
                      // ETAPA 2: CÓDIGO E NOVA SENHA
                      TextField(
                        controller: _codigoController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        style: TextStyle(color: onBackgroundColor),
                        decoration: InputDecoration(
                          labelText: 'Código de 6 dígitos',
                          labelStyle: TextStyle(color: onBackgroundColor.withOpacity(0.6)),
                          counterText: "",
                          prefixIcon: Icon(Icons.pin_outlined, color: onBackgroundColor.withOpacity(0.6)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          filled: true,
                          fillColor: fillColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _novaSenhaController,
                        obscureText: _ocultarNovaSenha,
                        style: TextStyle(color: onBackgroundColor),
                        decoration: InputDecoration(
                          labelText: 'Nova Senha',
                          labelStyle: TextStyle(color: onBackgroundColor.withOpacity(0.6)),
                          prefixIcon: Icon(Icons.lock_outline, color: onBackgroundColor.withOpacity(0.6)),
                          suffixIcon: IconButton(
                            icon: Icon(_ocultarNovaSenha ? Icons.visibility_off : Icons.visibility, color: onBackgroundColor.withOpacity(0.6)),
                            onPressed: () {
                              setState(() { _ocultarNovaSenha = !_ocultarNovaSenha; });
                            },
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          filled: true,
                          fillColor: fillColor,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _carregando ? null : _redefinirSenha,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                          ),
                          child: _carregando 
                              ? const CircularProgressIndicator(color: Colors.white) 
                              : const Text('Redefinir Senha', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ]
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