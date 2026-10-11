import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';

/// Fluxo único de saída da equipe: o painel e as Configurações chamam aqui.
///
/// Membro e admin só confirmam. O dono precisa decidir entre passar a liderança
/// e dissolver antes de sair — o servidor recusa um `leave` seco com
/// `409 "Escolha um sucessor ou dissolva a equipe para sair."` enquanto sobrar
/// gente, então este diálogo existe para essa decisão nunca virar erro na tela.
///
/// Retorna `true` quando a pessoa realmente saiu; quem chamou decide se fecha
/// a própria tela.
Future<bool> confirmTeamExit(BuildContext context, TeamDetail team) async {
  final app = context.read<AppState>();
  // O servidor chama de dono quem criou (`creator_username`), e é esse nome que
  // ele recusa como sucessor. `profile` pode estar nulo quando o GET do perfil
  // falhou, e sem o nome do dono aqui ele mesmo entraria na própria lista.
  final myUsername = team.isOwner
      ? team.creatorUsername
      : app.profile?.username;
  final others = team.members
      .where((m) => m.username != myUsername)
      .toList();
  if (team.isOwner && others.isNotEmpty) {
    return _exitAsOwner(context, app.api, team, others);
  }
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Sair da equipe?'),
      content: Text(
        team.isOwner
            ? 'Você é a única pessoa em ${team.name}, então sair apaga a '
                  'equipe e libera os territórios.'
            : 'Você vai deixar de fazer parte de ${team.name}.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
            foregroundColor: Theme.of(ctx).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Sair'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  return _run(context, () => app.api.leaveTeam());
}

/// Dono com membros: escolhe o sucessor ou dissolve a equipe para sair.
Future<bool> _exitAsOwner(
  BuildContext context,
  ApiClient api,
  TeamDetail team,
  List<TeamMemberInfo> others,
) async {
  String? successor = others.first.username;
  var dissolve = false;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) => AlertDialog(
        title: const Text('Passar a posse ou dissolver?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Você é dono de ${team.name}. Escolha um sucessor '
              'ou dissolva a equipe para sair.',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: dissolve ? null : successor,
              decoration: const InputDecoration(labelText: 'Sucessor'),
              items: [
                for (final m in others)
                  DropdownMenuItem(value: m.username, child: Text('@${m.username}')),
              ],
              onChanged: (v) => setSheetState(() {
                successor = v;
                dissolve = false;
              }),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Dissolver a equipe'),
              subtitle: const Text('Libera territórios e apaga a loja da equipe.'),
              value: dissolve,
              onChanged: (v) => setSheetState(() => dissolve = v ?? false),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: dissolve
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(ctx).colorScheme.error,
                    foregroundColor: Theme.of(ctx).colorScheme.onError,
                  )
                : null,
            child: Text(dissolve ? 'Dissolver e sair' : 'Transferir e sair'),
          ),
        ],
      ),
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  final target = successor;
  return _run(context, () async {
    if (dissolve) {
      await api.leaveTeam(dissolve: true);
    } else if (target != null) {
      await api.leaveTeam(successorUsername: target);
    }
  });
}

/// Rodeia a chamada com o tratamento de erro do app: mensagem do servidor em
/// um SnackBar, nada de tela parada.
Future<bool> _run(BuildContext context, Future<void> Function() call) async {
  try {
    await call();
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
    return false;
  }
  return true;
}
