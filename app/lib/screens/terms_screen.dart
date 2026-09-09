import 'package:flutter/material.dart';

/// RF02 — acesso aos Termos de Uso e à Política de Privacidade. É a mesma tela
/// aberta pelo link do cadastro e pelo item do perfil. O texto cobre a base
/// exigida pela LGPD (RNF02): quais dados são coletados, para quê, e os
/// direitos do titular.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    return Scaffold(
      appBar: AppBar(title: const Text('Termos de Uso e Privacidade')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Termos de Uso', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('Última atualização: 2026', style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 16),

          Text('1. O que é o RUNOVER!', style: titleStyle),
          const _P(
            'O RUNOVER! é um aplicativo de jogo que usa a sua localização para '
            'transformar o percurso que você corre em territórios virtuais. Ao '
            'fechar um trajeto (voltar perto do ponto de partida), a área '
            'percorrida vira ou passa a ser sua — ou da sua equipe.',
          ),

          Text('2. Cadastro e conta', style: titleStyle),
          const _P(
            'Para jogar você precisa criar uma conta com nome, apelido, e-mail e '
            'senha. O apelido é único. Você é responsável por manter a senha em '
            'segurança e por toda atividade feita na sua conta.',
          ),

          Text('3. Uso adequado', style: titleStyle),
          const _P(
            'Corra com atenção ao trânsito e ao ambiente à sua volta. É proibido '
            'falsear a localização (GPS falso, emuladores ou deslocamentos '
            'impossíveis). O sistema detecta e recusa essas tentativas, e a conta '
            'pode ser suspensa.',
          ),

          Text('4. Territórios, pontos e ranking', style: titleStyle),
          const _P(
            'A pontuação depende da quantidade e da relevância dos territórios '
            'dominados, e o nível vem da pontuação acumulada. Um território pode '
            'ser retomado por outro jogador ou equipe que cumpra as regras — '
            'perder um território faz parte do jogo.',
          ),

          const SizedBox(height: 24),
          Text('Política de Privacidade (LGPD)', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),

          Text('5. Dados que coletamos', style: titleStyle),
          const _P(
            '• Cadastro: nome completo, apelido, e-mail e foto de perfil (opcional).\n'
            '• Localização: a posição do GPS enquanto você usa o app, e o trajeto '
            'das corridas que você registra.\n'
            '• Uso: territórios conquistados e perdidos, pontuação, nível, tempo '
            'de jogo e histórico de atividades.',
          ),

          Text('6. Para que usamos', style: titleStyle),
          const _P(
            'A localização é usada exclusivamente para exibir o mapa, validar a '
            'conquista de territórios e impedir fraudes. Os demais dados fazem o '
            'ranking, o histórico e o perfil funcionarem. Não vendemos seus dados.',
          ),

          Text('7. Perfil público e privado', style: titleStyle),
          const _P(
            'Outros jogadores podem ver informações públicas do seu perfil '
            '(apelido, nível, pontuação e territórios). Em "Editar perfil" você '
            'pode tornar seu perfil privado — aí só você o enxerga.',
          ),

          Text('8. Segurança e retenção', style: titleStyle),
          const _P(
            'As senhas são guardadas apenas de forma criptografada (hash). Os '
            'dados ficam armazenados enquanto sua conta existir e são usados para '
            'auditoria e melhoria do serviço.',
          ),

          Text('9. Seus direitos', style: titleStyle),
          const _P(
            'Você pode acessar e corrigir seus dados a qualquer momento na tela '
            'de perfil, e pode solicitar a exclusão da conta e dos dados '
            'associados. Dúvidas sobre privacidade podem ser enviadas ao suporte '
            'do RUNOVER!.',
          ),

          const SizedBox(height: 12),
          const _P(
            'Ao marcar "Li e concordo" no cadastro, você declara que leu e aceita '
            'estes Termos de Uso e esta Política de Privacidade.',
          ),
        ],
      ),
    );
  }
}

class _P extends StatelessWidget {
  final String text;
  const _P(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 18),
      child: Text(text, style: const TextStyle(height: 1.45, color: Colors.black87)),
    );
  }
}
