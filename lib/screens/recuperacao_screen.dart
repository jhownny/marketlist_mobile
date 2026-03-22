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
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar Senha')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_etapaAtual == 1) ...[
              const Icon(Icons.lock_reset, size: 80, color: Colors.green),
              const SizedBox(height: 20),
              const Text('Esqueceu sua senha?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text('Digite seu e-mail abaixo e enviaremos um código de 6 dígitos para você criar uma nova senha.', textAlign: TextAlign.center),
              const SizedBox(height: 30),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _carregando ? null : _solicitarCodigo,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  child: _carregando ? const CircularProgressIndicator(color: Colors.white) : const Text('Enviar Código', style: TextStyle(fontSize: 16)),
                ),
              ),
            ] else ...[
              const Icon(Icons.mark_email_read, size: 80, color: Colors.green),
              const SizedBox(height: 20),
              Text('Código enviado para ${_emailController.text}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              TextField(
                controller: _codigoController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'Código de 6 dígitos', border: OutlineInputBorder(), prefixIcon: Icon(Icons.pin)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _novaSenhaController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Nova Senha', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _carregando ? null : _redefinirSenha,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  child: _carregando ? const CircularProgressIndicator(color: Colors.white) : const Text('Redefinir Senha', style: TextStyle(fontSize: 16)),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}