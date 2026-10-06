import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runover_app/widgets/guided_tour.dart';

void main() {
  Future<void> pumpTour(
    WidgetTester tester, {
    required List<TourStep> steps,
    required VoidCallback onFinish,
    bool attachTargets = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              if (attachTargets)
                Column(
                  children: [
                    Container(
                      key: steps[0].targetKey,
                      width: 60,
                      height: 60,
                      color: Colors.red,
                    ),
                    if (steps.length > 1)
                      Container(
                        key: steps[1].targetKey,
                        width: 60,
                        height: 60,
                        color: Colors.blue,
                      ),
                  ],
                ),
              GuidedTour(steps: steps, onFinish: onFinish),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<TourStep> steps() => [
    TourStep(
      targetKey: GlobalKey(),
      title: 'Primeiro',
      text: 'Toque aqui primeiro.',
    ),
    TourStep(
      targetKey: GlobalKey(),
      title: 'Segundo',
      text: 'Depois aqui.',
    ),
  ];

  testWidgets('avança pelos passos até concluir', (tester) async {
    var finished = false;
    final s = steps();
    await pumpTour(tester, steps: s, onFinish: () => finished = true);

    expect(find.text('Primeiro'), findsOneWidget);
    await tester.tap(find.text('Avançar'));
    await tester.pumpAndSettle();
    expect(find.text('Segundo'), findsOneWidget);
    await tester.tap(find.text('Concluir'));
    await tester.pump();
    expect(finished, isTrue);
  });

  testWidgets('pular termina na hora', (tester) async {
    var finished = false;
    await pumpTour(
      tester,
      steps: steps(),
      onFinish: () => finished = true,
    );
    await tester.tap(find.text('Pular'));
    await tester.pump();
    expect(finished, isTrue);
  });

  testWidgets('alvo ausente pula o passo', (tester) async {
    var finished = false;
    await pumpTour(
      tester,
      attachTargets: false,
      steps: [
        TourStep(
          targetKey: GlobalKey(),
          title: 'Fantasma',
          text: 'Sem alvo na árvore.',
        ),
      ],
      onFinish: () => finished = true,
    );
    // Passo único sem alvo: conclui direto.
    await tester.pumpAndSettle();
    expect(finished, isTrue);
  });
}
