import 'package:flutter/material.dart';

/// Uma página do tutorial inicial.
class OnboardingPageData {
  const OnboardingPageData({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

const _pages = [
  OnboardingPageData(
    icon: Icons.map_outlined,
    title: 'Bem-vindo ao RUNOVER!',
    description:
        'Transforme cada corrida em conquista: corra por áreas reais e domine territórios.',
  ),
  OnboardingPageData(
    icon: Icons.flag_outlined,
    title: 'Conquiste territórios',
    description:
        'Feche um trajeto dentro dos limites da área e cumpra o desafio para tomar o território.',
  ),
  OnboardingPageData(
    icon: Icons.emoji_events_outlined,
    title: 'Pontos, níveis e ranking',
    description:
        'Territórios valem pontos por quantidade e relevância. Suba de nível e compare no ranking.',
  ),
  OnboardingPageData(
    icon: Icons.accessibility_new_rounded,
    title: 'Acessível para todos',
    description:
        'Compatível com leitores de tela, com contraste nos temas claro e escuro e textos que acompanham o tamanho definido no sistema.',
  ),
  OnboardingPageData(
    icon: Icons.directions_run_rounded,
    title: 'Pronto para correr?',
    description: 'Entre ou crie sua conta para começar a dominar a cidade.',
  ),
];

/// Tutorial inicial deslizante com opção de pular sempre visível.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final last = _index == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Semantics(
                button: true,
                label: 'Pular tutorial',
                child: TextButton(
                  onPressed: widget.onDone,
                  child: const Text('Pular'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => _page(context, _pages[i], i),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: LayoutBuilder(
                builder: (_, constraints) {
                  final dots = Semantics(
                    label: 'Página ${_index + 1} de ${_pages.length}',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < _pages.length; i++)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            width: _index == i ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _index == i
                                  ? colors.primary
                                  : colors.onSurface.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                      ],
                    ),
                  );
                  final action = FilledButton(
                    onPressed: _next,
                    child: Text(last ? 'Começar' : 'Avançar'),
                  );
                  // Tela estreita com texto ampliado: empilha em vez de
                  // estourar a linha.
                  if (constraints.maxWidth < 380) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(child: dots),
                        const SizedBox(height: 16),
                        action,
                      ],
                    );
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [dots, action],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _page(BuildContext context, OnboardingPageData page, int index) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Semantics(
      header: true,
      label: 'Passo ${index + 1} de ${_pages.length}: ${page.title}',
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Icon(page.icon, color: colors.primary, size: 56),
            ),
            const SizedBox(height: 40),
            Text(
              page.title,
              textAlign: TextAlign.center,
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Text(
              page.description,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
