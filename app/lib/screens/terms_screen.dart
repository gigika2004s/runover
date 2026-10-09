import 'package:flutter/material.dart';

import '../widgets/centered_content.dart';

/// RF02 — Termos de Uso e Política de Privacidade no padrão das grandes
/// plataformas, em linguagem acessível e com base na LGPD (RNF02):
/// elegibilidade, conta, fair play, dados coletados, finalidades,
/// compartilhamento, retenção, exclusão e direitos do titular.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    return Scaffold(
      appBar: AppBar(title: const Text('Termos de Uso e Privacidade')),
      body: CenteredContent(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Termos de Uso',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Última atualização: 8 de outubro de 2026',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            Text('1. O que é o RUNOVER!', style: titleStyle),
            const _P(
              'O RUNOVER! é um aplicativo que transforma suas corridas em '
              'conquista de territórios: ao fechar um trajeto válido, a área '
              'percorrida passa a ser sua — ou da sua equipe — e rende pontos, '
              'níveis e posição no ranking.',
            ),

            Text('2. Quem pode usar', style: titleStyle),
            const _P(
              'É preciso ter ao menos 13 anos. Menores de 18 anos devem usar o '
              'aplicativo com acompanhamento de um responsável. Uma pessoa, uma '
              'conta: perfis duplicados ou automatizados podem ser removidos.',
            ),

            Text('3. Cadastro e veracidade', style: titleStyle),
            const _P(
              'O cadastro pede nome completo, apelido único, e-mail e senha, com '
              'aceite obrigatório destes termos. Você declara que as informações '
              'são verdadeiras e as mantém atualizadas. Também é possível entrar '
              'com Google, caso em que recebemos o e-mail verificado e, '
              'quando disponíveis, nome e foto.',
            ),

            Text('4. Sua conta e sua senha', style: titleStyle),
            const _P(
              'A senha precisa de ao menos 8 caracteres, com letras e números. '
              'Você é responsável por guardá-la e por tudo que acontece na sua '
              'conta. Se suspeitar de acesso indevido, troque a senha em '
              '"Editar perfil" — a troca encerra as outras sessões.',
            ),

            Text('5. Uso adequado e fair play', style: titleStyle),
            const _P(
              'Corra com atenção ao trânsito e ao ambiente. É proibido falsear '
              'a localização (GPS falso, emuladores, deslocamentos impossíveis) '
              'ou explorar falhas do sistema. O app valida velocidade, sequência '
              'e atualidade de cada leitura, e contas em fraude podem ser '
              'suspensas ou removidas. O RUNOVER! não substitui orientação médica '
              'ou avaliação das condições de segurança do trajeto.',
            ),

            Text('6. Territórios, pontos e ranking', style: titleStyle),
            const _P(
              'A pontuação depende da quantidade e da relevância dos territórios '
              'dominados; o nível vem da pontuação acumulada e o ranking é '
              'recalculado a cada mudança. Um território pode ser retomado por '
              'quem cumprir as regras do desafio — perder território faz parte '
              'do jogo e não gera direito a compensação.',
            ),

            Text('7. Equipes', style: titleStyle),
            const _P(
              'Você pode criar uma equipe ou entrar em uma existente. '
              'Territórios conquistados em nome da equipe pertencem a ela, não '
              'aos membros individualmente. Quem cria ou participa assume as '
              'regras da equipe perante os demais membros.',
            ),

            Text('8. Moedas, missões e cosméticos', style: titleStyle),
            const _P(
              'Corridas e conquistas podem gerar moedas virtuais, experiência, '
              'sequências e recompensas de missão. As moedas, os cosméticos e '
              'qualquer item da loja não têm valor monetário, não são dinheiro '
              'eletrônico e não podem ser vendidos, trocados ou convertidos '
              'fora do RUNOVER!. O catálogo, os preços e as recompensas podem '
              'ser alterados para manter o equilíbrio do jogo. Itens ficam '
              'vinculados à conta e não geram reembolso em dinheiro.',
            ),

            Text('9. Disponibilidade', style: titleStyle),
            const _P(
              'O serviço pode passar por manutenções e instabilidades. Não '
              'garantimos disponibilidade ininterrupta nem guardamos rascunhos '
              'não enviados se você limpar os dados do app ou do navegador.',
            ),

            const SizedBox(height: 24),
            Text(
              'Política de Privacidade (LGPD — Lei nº 13.709/2018)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            Text('10. Dados que coletamos', style: titleStyle),
            const _P(
              '• Conta: nome completo, apelido, e-mail, foto de perfil '
              '(opcional), pronomes (opcionais) e preferências de treino e '
              'privacidade.\n'
              '• Localização: posição do GPS durante o uso e o trajeto das '
              'corridas que você registra.\n'
              '• Jogo: territórios, pontos, nível, tempo de jogo, moedas '
              'virtuais, cosméticos, favoritos, missões e histórico.\n'
              '• Login social: e-mail verificado e, quando disponíveis, '
              'nome e foto vindos do Google, '
              'quando usados.',
            ),

            Text('11. Cookies e armazenamento local', style: titleStyle),
            const _P(
              'Usamos cookies e armazenamento local para manter sua sessão, '
              'lembrar preferências (como o tutorial e os cookies) e guardar '
              'rascunhos de corrida no aparelho. Você gerencia os cookies em '
              '"Gerenciar Cookies", no rodapé do app.',
            ),

            Text(
              '12. Para que usamos e com qual base legal',
              style: titleStyle,
            ),
            const _P(
              'Execução do serviço: mapa, validação de conquistas, ranking, '
              'histórico, perfil, missões e loja. Segurança e prevenção a '
              'fraudes: detecção de localização falsa e auditoria. Consentimento '
              'ou configuração escolhida por você: foto, pronomes, visibilidade '
              'do perfil, compartilhamento de atividades e cookies não '
              'essenciais. Não vendemos seus dados nem os usamos para publicidade '
              'de terceiros.',
            ),

            Text('13. Com quem compartilhamos', style: titleStyle),
            const _P(
              'Operadores técnicos estritamente necessários: hospedagem e banco '
              'de dados, envio de e-mails de recuperação de senha e mapas. '
              'Todos tratam dados apenas sob nossas instruções. Podemos divulgar '
              'dados para cumprir ordem legal ou proteger direitos, segurança e '
              'propriedade.',
            ),

            Text('14. Perfil público e privado', style: titleStyle),
            const _P(
              'Por padrão, apelido, nível, pontuação e territórios são visíveis '
              'a outros jogadores. Em "Editar perfil" você pode tornar o perfil '
              'privado — aí só você o enxerga. O percurso detalhado das '
              'corridas nunca é público. O compartilhamento de atividades é uma '
              'preferência separada: quando desativado, novas atividades não '
              'devem ser exibidas em superfícies sociais do app.',
            ),

            Text('15. Retenção', style: titleStyle),
            const _P(
              'Guardamos seus dados enquanto a conta existir. Logs de auditoria '
              'podem ser mantidos por obrigação legal mesmo após a exclusão, '
              'sempre sem identificação direta quando possível.',
            ),

            Text('16. Exclusão da conta', style: titleStyle),
            const _P(
              'Em "Editar perfil › Segurança › Excluir conta", após confirmação '
              'em duas etapas, apagamos perfil, foto, corridas, histórico, '
              'pontos e notificações, liberamos seus territórios e encerramos '
              'todas as sessões. É preciso sair da equipe antes, para não '
              'deixar times órfãos. A ação é permanente.',
            ),

            Text('17. Seus direitos (LGPD)', style: titleStyle),
            const _P(
              'Você pode confirmar a existência de tratamento e acessar, '
              'corrigir, anonimizar, bloquear ou eliminar seus dados, além de '
              'pedir portabilidade e revogar consentimentos. Fale pelo suporte '
              'do RUNOVER! informando seu e-mail de cadastro; respondemos em '
              'até 15 dias.',
            ),

            Text('18. Segurança', style: titleStyle),
            const _P(
              'Senhas existem apenas como hash irreversível e o tráfego usa '
              'criptografia. Nenhum sistema é infalível: nunca compartilhe sua '
              'senha e nos avise sobre vulnerabilidades em vez de explorá-las.',
            ),

            Text('19. Mudanças e contato', style: titleStyle),
            const _P(
              'Podemos atualizar estes termos; mudanças relevantes serão '
              'avisadas no app e o uso continuado vale como aceite. Dúvidas, '
              'pedidos de privacidade e solicitações da LGPD: suporte do '
              'RUNOVER!. Foro: São Paulo/SP.',
            ),

            const SizedBox(height: 12),
            const _P(
              'Ao marcar "Li e concordo" no cadastro, você declara que leu e aceita '
              'estes Termos de Uso e esta Política de Privacidade.',
            ),
          ],
        ),
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
      child: Text(
        text,
        style: TextStyle(
          height: 1.45,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}
