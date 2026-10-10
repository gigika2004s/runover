import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';
import '../models.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../widgets/centered_content.dart';
import '../widgets/cosmetics.dart';

/// Tela de ajustes da equipe (dono/admin).
/// Formulário completo com perfil, modos de entrada, convites e avisos.
/// A personalização visual (emblema, nome, efeito) é feita pela Loja da equipe.
class TeamSettingsScreen extends StatefulWidget {
  const TeamSettingsScreen({
    super.key,
    required this.initial,
    required this.memberCount,
    required this.onSave,
    required this.onLeave,
    required this.onDelete,
    this.inviteLink,
    this.onRegenerateInvite,
  });

  final TeamSettings initial;
  final int memberCount;
  final String? inviteLink;

  // A tela não conhece o backend: quem a usa decide o que acontece em cada ação.
  final Future<void> Function(TeamSettings settings) onSave;
  final Future<void> Function() onLeave;
  final Future<void> Function() onDelete;
  final Future<void> Function()? onRegenerateInvite;

  @override
  State<TeamSettingsScreen> createState() => _TeamSettingsScreenState();
}

/// Modos de quem pode entrar na equipe.
enum JoinMode {
  approval('Por aprovação', 'Quem pedir entrada espera você aceitar'),
  open('Aberta', 'Qualquer pessoa entra na hora'),
  inviteOnly('Só por convite', 'Entra quem tiver o seu link');

  const JoinMode(this.title, this.subtitle);
  final String title, subtitle;
}

/// Estado editável da tela. Imutável: cada mudança gera uma cópia nova,
/// o que permite saber se há alterações comparando com a versão salva.
@immutable
class TeamSettings {
  const TeamSettings({
    required this.name,
    this.joinMode = JoinMode.approval,
    this.listed = true,
    this.notifyRisk = true,
    this.notifyRequests = true,
  });

  final String name;
  final JoinMode joinMode;
  final bool listed, notifyRisk, notifyRequests;

  TeamSettings copyWith({
    String? name,
    JoinMode? joinMode,
    bool? listed,
    bool? notifyRisk,
    bool? notifyRequests,
  }) =>
      TeamSettings(
        name: name ?? this.name,
        joinMode: joinMode ?? this.joinMode,
        listed: listed ?? this.listed,
        notifyRisk: notifyRisk ?? this.notifyRisk,
        notifyRequests: notifyRequests ?? this.notifyRequests,
      );

  @override
  bool operator ==(Object other) =>
      other is TeamSettings &&
      other.name == name &&
      other.joinMode == joinMode &&
      other.listed == listed &&
      other.notifyRisk == notifyRisk &&
      other.notifyRequests == notifyRequests;

  @override
  int get hashCode =>
      Object.hash(name, joinMode, listed, notifyRisk, notifyRequests);
}

class _TeamSettingsScreenState extends State<TeamSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late TeamSettings _baseline; // última versão salva
  late TeamSettings _s; // versão que está sendo editada
  bool _saving = false;

  bool get _dirty => _s != _baseline;
  bool get _onlyMember => widget.memberCount <= 1;

  @override
  void initState() {
    super.initState();
    _baseline = widget.initial;
    _s = widget.initial;
    _name = TextEditingController(text: _s.name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _set(TeamSettings next) => setState(() => _s = next);

  void _toast(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  Future<bool> _confirm({
    required String title,
    required String body,
    required String action,
    bool destructive = false,
  }) async {
    final cs = Theme.of(context).colorScheme;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError)
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(_s);
      if (!mounted) return;
      setState(() => _baseline = _s);
      _toast('Alterações salvas');
    } catch (_) {
      if (mounted) _toast('Não foi possível salvar. Tente de novo.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _cancel() {
    setState(() => _s = _baseline);
    _name.text = _baseline.name;
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: widget.inviteLink!));
    if (mounted) _toast('Link copiado');
  }

  Future<void> _regenerate() async {
    final ok = await _confirm(
      title: 'Gerar novo link?',
      body: 'O link antigo deixa de funcionar.',
      action: 'Gerar',
    );
    if (ok) await widget.onRegenerateInvite!();
  }

  Future<void> _leave() async {
    final ok = await _confirm(
      title: 'Sair da equipe?',
      body: _onlyMember
          ? 'Como você é a única pessoa, a equipe será apagada.'
          : 'Você deixa de ver os pontos e territórios da equipe.',
      action: 'Sair',
      destructive: true,
    );
    if (ok) await widget.onLeave();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteDialog(teamName: _baseline.name),
    );
    if (ok == true) await widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      // Se houver alterações não salvas, pergunta antes de voltar.
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await _confirm(
          title: 'Descartar alterações?',
          body: 'Você tem alterações que ainda não foram salvas.',
          action: 'Descartar',
          destructive: true,
        );
        if (discard && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Ajustes da equipe'), backgroundColor: Colors.transparent),
        body: Center(
          // Largura máxima: a mesma tela serve para celular e web.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  _Section(title: 'Perfil da equipe', children: [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              child: const Icon(Icons.star, color: Colors.white, size: 30),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Emblema e cor', style: Theme.of(context).textTheme.titleMedium),
                                  Text('Personalize pela Loja da equipe',
                                      style: TextStyle(color: cs.onSurfaceVariant)),
                                ],
                              ),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          // Visual current - vindo da equipe/loja, sem seletor próprio
                          const Text(
            'Emblema, moldura e efeito da equipe são itens da Loja da equipe. '
            'Use a aba "Loja da equipe" para comprar/equipar.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _name,
                            maxLength: 24,
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            decoration: const InputDecoration(
                              labelText: 'Nome da equipe',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Dê um nome à equipe' : null,
                            onChanged: (v) => _set(_s.copyWith(name: v.trim())),
                          ),
                        ],
                      ),
                    ),
                  ]),
                  _Section(title: 'Quem pode entrar', children: [
                    for (final mode in JoinMode.values)
                      _OptionTile(
                        mode: mode,
                        selected: _s.joinMode == mode,
                        onTap: () => _set(_s.copyWith(joinMode: mode)),
                      ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Aparecer em "Equipes disponíveis"'),
                      subtitle: const Text('Desligado, só quem tem o link encontra a equipe'),
                      value: _s.listed,
                      onChanged: (v) => _set(_s.copyWith(listed: v)),
                    ),
                  ]),
                  _Section(title: 'Convites', children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                      child: Row(children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: cs.outlineVariant),
                            ),
                            child: Text(
                              widget.inviteLink ?? 'Seu link de convite aparece aqui',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: widget.inviteLink == null ? null : _copyLink,
                          child: const Text('Copiar'),
                        ),
                      ]),
                    ),
                    ListTile(
                      title: const Text('Gerar novo link'),
                      subtitle: const Text('O link antigo deixa de funcionar'),
                      trailing: OutlinedButton(
                        onPressed: widget.onRegenerateInvite == null ? null : _regenerate,
                        child: const Text('Gerar'),
                      ),
                    ),
                  ]),
                  _Section(title: 'Membros', children: [
                    ListTile(
                      title: const Text('Pedidos de entrada'),
                      subtitle: const Text('Nenhum pedido no momento'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {}, // TODO: abrir a lista de pedidos
                    ),
                    ListTile(
                      title: const Text('Gerenciar membros'),
                      subtitle: const Text('Tornar líder ou remover alguém'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {}, // TODO: abrir a lista de membros
                    ),
                    ListTile(
                      enabled: !_onlyMember,
                      title: const Text('Passar a liderança'),
                      subtitle: const Text('Disponível quando houver outro membro'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _onlyMember ? null : () {}, // TODO: escolher o novo líder
                    ),
                  ]),
                  _Section(title: 'Avisos da equipe', children: [
                    SwitchListTile(
                      title: const Text('Território em risco'),
                      subtitle: const Text('Avisar quando alguém tomar uma zona nossa'),
                      value: _s.notifyRisk,
                      onChanged: (v) => _set(_s.copyWith(notifyRisk: v)),
                    ),
                    SwitchListTile(
                      title: const Text('Novos pedidos de entrada'),
                      subtitle: const Text('Receber aviso a cada pedido'),
                      value: _s.notifyRequests,
                      onChanged: (v) => _set(_s.copyWith(notifyRequests: v)),
                    ),
                  ]),
                  _Section(title: 'Zona de risco', danger: true, children: [
                    ListTile(
                      title: const Text('Sair da equipe'),
                      subtitle: Text(_onlyMember
                          ? 'Como você é a única pessoa, sair apaga a equipe'
                          : 'Você deixa de ver os pontos e territórios da equipe'),
                      trailing: _DangerButton(label: 'Sair', onPressed: _leave),
                    ),
                    ListTile(
                      title: const Text('Excluir equipe'),
                      subtitle: const Text(
                          'Remove a equipe, os pontos e os membros. Não dá para desfazer'),
                      trailing: _DangerButton(label: 'Excluir', onPressed: _delete),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
        // Fixa embaixo: a pessoa não precisa rolar até o fim para salvar.
        bottomNavigationBar: _SaveBar(
          canSave: _dirty,
          saving: _saving,
          onSave: _save,
          onCancel: _cancel,
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ Peças

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.danger = false});

  final String title;
  final List<Widget> children;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(letterSpacing: 0.8, color: cs.onSurfaceVariant),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: danger ? BorderSide(color: cs.error.withAlpha(120)) : BorderSide.none,
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

/// Opção de escolha única. Usei ListTile em vez de RadioListTile para não
/// depender de qual versão do Flutter você usa (a API do Radio mudou).
class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.mode, required this.selected, required this.onTap});

  final JoinMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      child: ListTile(
        selected: selected,
        onTap: onTap,
        leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked),
        title: Text(mode.title),
        subtitle: Text(mode.subtitle),
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  const _DangerButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(foregroundColor: error, side: BorderSide(color: error)),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.canSave,
    required this.saving,
    required this.onSave,
    required this.onCancel,
  });

  final bool canSave, saving;
  final VoidCallback onSave, onCancel;

  @override
  Widget build(BuildContext context) {
    final enabled = canSave && !saving;
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: enabled ? onCancel : null,
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: enabled ? onSave : null,
                    child: saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Salvar alterações'),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Diálogo de confirmação de exclusão: pede o nome da equipe para confirmar.
class _DeleteDialog extends StatefulWidget {
  const _DeleteDialog({required this.teamName});

  final String teamName;

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final matches = _controller.text.trim() == widget.teamName;
    return AlertDialog(
      title: const Text('Excluir equipe?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Isso remove a equipe, os pontos e os membros. Não dá para desfazer.'),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Digite ${widget.teamName} para confirmar',
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError),
          onPressed: matches ? () => Navigator.pop(context, true) : null,
          child: const Text('Excluir'),
        ),
      ],
    );
  }
}