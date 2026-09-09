import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../state/app_state.dart';

/// RF04 — fluxo de recuperação de senha. Sem servidor de e-mail no
/// protótipo: a API devolve o token de redefinição diretamente na resposta,
/// e este fluxo o usa aqui mesmo (em produção ele viria por e-mail).
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  String? _resetToken;
  bool _loading = false;
  String? _error;
  String? _message;

  Future<void> _requestToken() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AppState>().api;
      final token = await api.requestPasswordReset(_emailCtrl.text.trim());
      setState(() {
        _resetToken = token.isNotEmpty ? token : null;
        _message = token.isNotEmpty
            ? 'Token gerado (modo demonstração — em produção isso chegaria por e-mail).'
            : 'Se esse e-mail estiver cadastrado, enviaremos instruções.';
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmReset() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AppState>().api;
      await api.resetPassword(_resetToken!, _newPasswordCtrl.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Senha redefinida com sucesso. Faça login.')),
        );
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar senha')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Coloque aqui o e-mail cadastrado para receber o token de alteração de senha.'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailCtrl,
                    enabled: _resetToken == null,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                  ),
                  const SizedBox(height: 12),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_message!, style: const TextStyle(color: Colors.black54)),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                    ),
                  if (_resetToken == null)
                    FilledButton(
                      onPressed: _loading ? null : _requestToken,
                      child: const Text('Confirmar'),
                    )
                  else ...[
                    TextField(
                      controller: _newPasswordCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Nova senha'),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _loading ? null : _confirmReset,
                      child: const Text('Redefinir senha'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
