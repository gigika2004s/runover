import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/api_client.dart';
import '../services/profile_image_provider.dart';
import '../state/app_state.dart';
import '../widgets/team_exit.dart';
import 'team_shop_screen.dart';

/// Modos de quem pode entrar na equipe. O `apiValue` é a string do servidor.
enum JoinMode {
  approval('Por aprovação', 'Quem pedir entrada espera você aceitar', 'approval'),
  open('Aberta', 'Qualquer pessoa entra na hora', 'open'),
  inviteOnly('Só por convite', 'Entra quem tiver o seu link', 'invite_only');

  const JoinMode(this.title, this.subtitle, this.apiValue);
  final String title, subtitle, apiValue;

  static JoinMode fromApi(String raw) => values.firstWhere(
    (m) => m.apiValue == raw,
    orElse: () => approval,
  );
}

/// Estado editável do formulário (nome, entrada, listagem e avisos).
/// Imutável: cada mudança gera uma cópia nova, o que permite saber se há
/// alterações comparando com a última versão salva.
@immutable
class TeamSettings {
  const TeamSettings({
    required this.name,
    this.joinMode = JoinMode.approval,
    this.listed = true,
    this.notifyRisk = true,
    this.notifyRequests = true,
  });

  factory TeamSettings.of(TeamDetail team) => TeamSettings(
    name: team.name,
    joinMode: JoinMode.fromApi(team.joinMode),
    listed: team.listed,
    notifyRisk: team.notifyRisk,
    notifyRequests: team.notifyRequests,
  );

  final String name;
  final JoinMode joinMode;
  final bool listed, notifyRisk, notifyRequests;

  TeamSettings copyWith({
    String? name,
    JoinMode? joinMode,
    bool? listed,
    bool? notifyRisk,
    bool? notifyRequests,
  }) => TeamSettings(
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

/// Configurações da equipe — a única superfície de ajustes do time.
///
/// O conteúdo muda com o papel de quem abre, porque o servidor também muda:
/// dono e admin editam entrada, convites, avisos, foto e nome; membro sem
/// cargo vê esses dados e só pode sair. Dissolver é exclusivo do dono.
class TeamSettingsScreen extends StatefulWidget {
  const TeamSettingsScreen({
    super.key,
    required this.team,
    required this.onChanged,
  });

  final TeamDetail team;
  final VoidCallback onChanged;

  @override
  State<TeamSettingsScreen> createState() => _TeamSettingsScreenState();
}

class _TeamSettingsScreenState extends State<TeamSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _photoLink;
  late TeamSettings _baseline; // última versão salva no servidor
  late TeamSettings _s; // versão em edição
  late List<TeamJoinRequestInfo> _requests;
  late String? _inviteLink;
  late String? _photoUrl;
  bool _saving = false;
  bool _busy = false;

  bool get _isAdmin => widget.team.isAdmin;
  bool get _isOwner => widget.team.isOwner;
  bool get _dirty => _s != _baseline;

  /// Um avatar pronto é salvo como data URI. Despejar o base64 inteiro na caixa
  /// de link a torna ilegível e fácil de corromper com uma edição.
  bool get _inlinePhoto => (_photoUrl ?? '').startsWith('data:');

  @override
  void initState() {
    super.initState();
    _baseline = TeamSettings.of(widget.team);
    _s = _baseline;
    _requests = List.of(widget.team.pendingRequests);
    _photoUrl = widget.team.photoUrl;
    _inviteLink = _linkOf(widget.team.inviteToken);
    _name = TextEditingController(text: _s.name);
    _photoLink = _inlinePhoto ? TextEditingController() : TextEditingController(text: _photoUrl ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _photoLink.dispose();
    super.dispose();
  }

  static String? _linkOf(String? token) =>
      token == null || token.isEmpty ? null : '/teams/join/$token';

  void _set(TeamSettings next) => setState(() => _s = next);

  void _toast(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  /// Chamada de escrita com o erro do servidor devolvido em mensagem, e o
  /// painel recarregado no fim — nada de botão que falha em silêncio.
  Future<T?> _call<T>(Future<T> Function(ApiClient api) call) async {
    if (_busy) return null;
    setState(() => _busy = true);
    try {
      final result = await call(context.read<AppState>().api);
      widget.onChanged();
      return result;
    } on ApiException catch (e) {
      _toast(e.message);
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_saving) return;
    setState(() => _saving = true);
    final draft = _s;
    try {
      await context.read<AppState>().api.updateTeam(
        id: widget.team.id,
        name: draft.name,
        joinMode: draft.joinMode.apiValue,
        listed: draft.listed,
        notifyRisk: draft.notifyRisk,
        notifyRequests: draft.notifyRequests,
      );
      if (!mounted) return;
      setState(() {
        _baseline = draft;
        _name.text = draft.name;
      });
      widget.onChanged();
      _toast('Alterações salvas');
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('Não foi possível salvar. Tente de novo.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _cancel() {
    setState(() {
      _s = _baseline;
      _name.text = _baseline.name;
    });
  }

  Future<void> _savePhoto(String value) =>
      _call((api) async {
        await api.updateTeam(id: widget.team.id, photoUrl: value);
        if (mounted) {
          setState(() {
            _photoUrl = value.isEmpty ? null : value;
            if (value.isNotEmpty && !_inlinePhoto) _photoLink.text = value;
          });
        }
      }).then((_) {});

  Future<void> _decide(TeamJoinRequestInfo req, bool accept) async {
    final updated = await _call(
      (api) => api.decideJoinRequest(widget.team.id, req.id, accept),
    );
    // Sem retorno, a escrita não aconteceu (erro ou chamada em voo): o pedido
    // continua no servidor, então tirá-lo da lista deixaria a tela mentindo.
    if (updated == null || !mounted) return;
    setState(() => _requests = List.of(updated.pendingRequests));
  }

  Future<void> _copyLink() async {
    final link = _inviteLink;
    if (link == null) return;
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) _toast('Link copiado');
  }

  Future<void> _regenerate() async {
    final ok = await _confirm(
      title: 'Gerar novo link?',
      body: 'O link antigo deixa de funcionar.',
      action: 'Gerar',
    );
    if (!ok || !mounted) return;
    final updated = await _call(
      (api) => api.regenerateTeamInvite(widget.team.id),
    );
    // A falha não devolve equipe nenhuma: sair daqui sem checar apagaria o link
    // que ainda funciona e deixaria o painel sem convite.
    if (updated == null || !mounted) return;
    setState(() => _inviteLink = _linkOf(updated.inviteToken));
    _toast(_inviteLink == null ? 'Não foi possível gerar o link.' : 'Novo link gerado');
  }

  Future<void> _leave() async {
    final gone = await confirmTeamExit(context, widget.team);
    if (!gone || !mounted) return;
    widget.onChanged();
    Navigator.of(context).pop();
  }

  Future<void> _dissolve() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _DissolveDialog(teamName: _baseline.name),
    );
    if (ok != true || !mounted) return;
    // `disbandTeam` devolve vazio, então o marcador é o que separa o sucesso do
    // erro: fechar a tela numa falha mandaria a pessoa de volta ao painel com a
    // equipe ainda de pé.
    final gone = await _call((api) async {
      await api.disbandTeam(widget.team.id);
      return true;
    });
    if (gone != true || !mounted) return;
    Navigator.of(context).pop();
  }

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
                ? FilledButton.styleFrom(
                    backgroundColor: cs.error,
                    foregroundColor: cs.onError,
                  )
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final team = widget.team;
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
        if (discard && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Configurações'),
          backgroundColor: Colors.transparent,
        ),
        body: Center(
          // Largura máxima: a mesma tela serve para celular e web.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              child: ListView(
                // A lista própria da tela: dentro dela há a faixa horizontal de
                // avatares, então testes rolam por esta chave, não por `ListView`.
                key: const Key('team-settings-list'),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  _Section(title: 'Perfil da equipe', children: [
                    _ProfileFields(
                      team: team,
                      photoUrl: _photoUrl,
                      editable: _isAdmin,
                      busy: _busy,
                      nameCtrl: _name,
                      photoLinkCtrl: _photoLink,
                      onNameChanged: (v) => _set(_s.copyWith(name: v.trim())),
                      onPickPreset: _savePhoto,
                      onUseLink: () => _savePhoto(_photoLink.text.trim()),
                      onClearPhoto: () => _savePhoto(''),
                    ),
                  ]),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                    leading: const Icon(Icons.storefront_outlined),
                    title: const Text('Loja da equipe'),
                    subtitle: Text(
                      _isAdmin
                          ? 'Emblema, moldura, banner, efeito e bundles'
                          : 'Veja o que a equipe tem; só dono e admin compram',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _busy
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TeamShopScreen(teamId: team.id),
                            ),
                          ).then((_) => widget.onChanged()),
                  ),
                  ..._entrySections(context),
                  if (_isAdmin) ..._inviteSection(context),
                  if (_isAdmin) ..._requestsSection(context),
                  if (_isAdmin) ..._noticesSection(context),
                  _Section(title: 'Zona de risco', danger: true, children: [
                    ListTile(
                      title: const Text('Sair da equipe'),
                      subtitle: Text(
                        _isOwner
                            ? _onlyMember
                                  ? 'Como você é a única pessoa, sair apaga a equipe'
                                  : 'Você vai escolher um sucessor ou dissolver'
                            : 'Você deixa de ver os pontos e territórios da equipe',
                      ),
                      trailing: _DangerButton(
                        label: 'Sair',
                        onPressed: _leave,
                      ),
                    ),
                    if (_isOwner)
                      ListTile(
                        title: const Text('Dissolver equipe'),
                        subtitle: const Text(
                          'Remove a equipe, os pontos e os membros. '
                          'Não dá para desfazer',
                        ),
                        trailing: _DangerButton(
                          label: 'Dissolver',
                          onPressed: _dissolve,
                        ),
                      ),
                  ]),
                ],
              ),
            ),
          ),
        ),
        // Fixa embaixo: a pessoa não precisa rolar até o fim para salvar.
        bottomNavigationBar: _isAdmin
            ? _SaveBar(
                canSave: _dirty,
                saving: _saving,
                onSave: _save,
                onCancel: _cancel,
              )
            : null,
      ),
    );
  }

  bool get _onlyMember => widget.team.memberCount <= 1;

  /// Dono/admin escolhem; membro lê o que o servidor manda sobre a equipe.
  List<Widget> _entrySections(BuildContext context) {
    if (!_isAdmin) {
      final mode = JoinMode.fromApi(widget.team.joinMode);
      return [
        _Section(
          title: 'Quem pode entrar',
          children: [
            ListTile(
              title: Text(mode.title),
              subtitle: Text(mode.subtitle),
            ),
            const Divider(height: 1),
            ListTile(
              title: Text(
                widget.team.listed
                    ? 'Aparece em "Equipes disponíveis"'
                    : 'Não aparece em "Equipes disponíveis"',
              ),
              subtitle: const Text('Só dono e admin alteram isso'),
            ),
          ],
        ),
      ];
    }
    return [
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
    ];
  }

  List<Widget> _inviteSection(BuildContext context) {
    return [
      _Section(title: 'Convites', children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
          child: Row(children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Text(
                  _inviteLink ?? 'Gere um link para convidar',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: _inviteLink == null ? null : _copyLink,
              child: const Text('Copiar'),
            ),
          ]),
        ),
        ListTile(
          title: const Text('Gerar novo link'),
          subtitle: const Text('O link antigo deixa de funcionar'),
          trailing: OutlinedButton(
            onPressed: _busy ? null : _regenerate,
            child: const Text('Gerar'),
          ),
        ),
      ]),
    ];
  }

  List<Widget> _requestsSection(BuildContext context) {
    return [
      _Section(title: 'Pedidos de entrada', children: [
        if (_requests.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 16, 14, 16),
            child: Text('Nenhum pedido aguardando decisão.'),
          ),
        for (final req in _requests)
          ListTile(
            leading: CircleAvatar(
              child: Text(
                req.username.isNotEmpty
                    ? req.username[0].toUpperCase()
                    : '?',
              ),
            ),
            title: Text('@${req.username}'),
            subtitle: const Text('Quer entrar na equipe'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Aceitar pedido',
                  icon: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                  ),
                  onPressed: _busy ? null : () => _decide(req, true),
                ),
                IconButton(
                  tooltip: 'Recusar pedido',
                  icon: Icon(
                    Icons.cancel_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: _busy ? null : () => _decide(req, false),
                ),
              ],
            ),
          ),
      ]),
    ];
  }

  List<Widget> _noticesSection(BuildContext context) {
    return [
      _Section(title: 'Avisos da equipe', children: [
        // As chaves ficam na equipe, não na pessoa: um switch aqui muda o
        // aviso de todo mundo, por isso o texto avisa antes da pessoa mexer.
        SwitchListTile(
          title: const Text('Território em risco'),
          subtitle: const Text(
            'Avisar todos os membros quando alguém tomar uma zona nossa',
          ),
          value: _s.notifyRisk,
          onChanged: (v) => _set(_s.copyWith(notifyRisk: v)),
        ),
        SwitchListTile(
          title: const Text('Novos pedidos de entrada'),
          subtitle: const Text('Avisar dono e admins a cada pedido'),
          value: _s.notifyRequests,
          onChanged: (v) => _set(_s.copyWith(notifyRequests: v)),
        ),
      ]),
    ];
  }
}

/// Nome e foto. Dono/admin editam; membro vê os valores salvos.
class _ProfileFields extends StatelessWidget {
  const _ProfileFields({
    required this.team,
    required this.photoUrl,
    required this.editable,
    required this.busy,
    required this.nameCtrl,
    required this.photoLinkCtrl,
    required this.onNameChanged,
    required this.onPickPreset,
    required this.onUseLink,
    required this.onClearPhoto,
  });

  final TeamDetail team;
  final String? photoUrl;
  final bool editable;
  final bool busy;
  final TextEditingController nameCtrl;
  final TextEditingController photoLinkCtrl;
  final ValueChanged<String> onNameChanged;
  final Future<void> Function(String value) onPickPreset;
  final VoidCallback onUseLink;
  final VoidCallback onClearPhoto;

  @override
  Widget build(BuildContext context) {
    final image = profileImageProvider(photoUrl);
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            team.isOwner
                ? 'Você é o dono desta equipe.'
                : team.isAdmin
                ? 'Você é admin desta equipe.'
                : 'Você é membro: estes dados são da equipe e você pode sair.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.15),
                foregroundImage: image,
                onForegroundImageError: image == null ? null : (_, _) {},
                child: Text(
                  team.name.isNotEmpty ? team.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Emblema, moldura e efeito ficam na Loja da equipe.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (editable) ...[
            TextFormField(
              controller: nameCtrl,
              maxLength: 40,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: const InputDecoration(
                labelText: 'Nome da equipe',
                border: OutlineInputBorder(),
              ),
              // Os mesmos limites do servidor (2..40): validar menos que isso
              // deixa o campo "ok" no app e voltar 400 na salvada.
              validator: (v) {
                final name = (v ?? '').trim();
                if (name.length < 2) return 'O nome precisa de pelo menos 2 letras';
                if (name.length > 40) return 'O nome pode ter no máximo 40 letras';
                return null;
              },
              onChanged: onNameChanged,
            ),
            const SizedBox(height: 16),
            Text(
              'Foto da equipe',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: presetAvatars.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final preset = presetAvatars[i];
                  return InkWell(
                    key: Key('team-photo-${preset.label}'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: busy
                        ? null
                        : () async {
                            final uri = await presetAvatarDataUri(preset.asset);
                            if (uri == null || !context.mounted) return;
                            await onPickPreset(uri);
                          },
                    child: Ink(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: AssetImage(preset.asset),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: photoLinkCtrl,
              enabled: !busy,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Link da foto',
                hintText: 'https://…',
                helperText: (photoUrl ?? '').startsWith('data:')
                    ? 'A foto atual é um avatar pronto; digite um link para '
                          'substituí-la.'
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: photoLinkCtrl,
              builder: (context, photo, _) => Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  OutlinedButton(
                    onPressed: busy || photo.text.trim().isEmpty
                        ? null
                        : onUseLink,
                    child: const Text('Usar link'),
                  ),
                  if (photoUrl != null && photoUrl!.isNotEmpty)
                    TextButton(
                      onPressed: busy ? null : onClearPhoto,
                      child: const Text('Remover foto'),
                    ),
                ],
              ),
            ),
          ] else ...[
            Text(
              team.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '${team.memberCount} ${team.memberCount == 1 ? 'membro' : 'membros'} · '
              'criada por @${team.creatorUsername}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ Peças

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    this.danger = false,
  });

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
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(
              letterSpacing: 0.8,
              color: cs.onSurfaceVariant,
            ),
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
  const _OptionTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

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
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        ),
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
      style: OutlinedButton.styleFrom(
        foregroundColor: error,
        side: BorderSide(color: error),
      ),
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
        // Align com heightFactor (e não Center): o Scaffold mede a
        // bottomNavigationBar com folga total, e o Center preencheria a
        // tela inteira, esmagando o body para altura zero.
        child: Align(
          alignment: Alignment.center,
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: enabled ? onCancel : null,
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: FilledButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
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

/// Dissolução pede o nome da equipe digitado: é a ação sem volta do time.
class _DissolveDialog extends StatefulWidget {
  const _DissolveDialog({required this.teamName});

  final String teamName;

  @override
  State<_DissolveDialog> createState() => _DissolveDialogState();
}

class _DissolveDialogState extends State<_DissolveDialog> {
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
      title: const Text('Dissolver equipe?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.teamName} deixará de existir para todos os membros. '
            'Territórios voltam a ficar livres e a loja da equipe é apagada. '
            'Não há como desfazer.',
          ),
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
          style: FilledButton.styleFrom(
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
          ),
          onPressed: matches ? () => Navigator.pop(context, true) : null,
          child: const Text('Dissolver'),
        ),
      ],
    );
  }
}
