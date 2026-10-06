import 'package:flutter/material.dart';

/// Um passo do tour guiado: destaca o widget da [targetKey].
class TourStep {
  const TourStep({
    required this.targetKey,
    required this.title,
    required this.text,
  });

  final GlobalKey targetKey;
  final String title;
  final String text;
}

/// Destaque deslizante sobre os controles reais do app.
class GuidedTour extends StatefulWidget {
  const GuidedTour({
    super.key,
    required this.steps,
    required this.onFinish,
  });

  final List<TourStep> steps;
  final VoidCallback onFinish;

  @override
  State<GuidedTour> createState() => _GuidedTourState();
}

class _GuidedTourState extends State<GuidedTour> {
  int _index = 0;
  Rect? _target;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _locate());
  }

  void _locate() {
    if (!mounted) return;
    final box =
        widget.steps[_index].targetKey.currentContext?.findRenderObject()
            as RenderBox?;
    if (box == null || !box.hasSize || box.size.isEmpty) {
      _advance();
      return;
    }
    final topLeft = box.localToGlobal(Offset.zero);
    setState(() => _target = (topLeft & box.size).inflate(8));
  }

  void _advance() {
    if (!mounted) return;
    if (_index < widget.steps.length - 1) {
      setState(() {
        _index++;
        _target = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _locate());
    } else {
      widget.onFinish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];
    final last = _index == widget.steps.length - 1;
    final size = MediaQuery.sizeOf(context);
    final target = _target;
    final below = target == null || target.center.dy < size.height / 2;
    return Stack(
      children: [
        ModalBarrier(
          color: Colors.transparent,
          dismissible: false,
        ),
        if (target != null)
          CustomPaint(
            size: Size.infinite,
            painter: _HolePainter(target),
          ),
        SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: widget.onFinish,
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('Pular'),
                ),
              ),
              const Spacer(),
              if (!below) const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Semantics(
                  header: true,
                  label: 'Passo ${_index + 1} de ${widget.steps.length}',
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            step.title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(step.text),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_index + 1} de ${widget.steps.length}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              FilledButton(
                                onPressed: _advance,
                                child: Text(last ? 'Concluir' : 'Avançar'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (below) const Spacer(),
            ],
          ),
        ),
      ],
    );
  }
}

/// Escurece tudo menos o recorte arredondado do alvo.
class _HolePainter extends CustomPainter {
  const _HolePainter(this.target);

  final Rect target;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black.withValues(alpha: 0.62),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(target, const Radius.circular(14)),
      Paint()
        ..blendMode = BlendMode.clear
        ..color = Colors.transparent,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HolePainter oldDelegate) =>
      oldDelegate.target != target;
}
