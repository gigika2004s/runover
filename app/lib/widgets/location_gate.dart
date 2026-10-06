import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Estados do acesso à localização.
enum LocationGateStatus {
  checking,
  granted,
  needsPrompt,
  blocked,
  serviceOff,
  error,
}

/// Portão obrigatório de localização: o pedido ao navegador parte de um
/// toque explícito (sem gesto, Safari/Firefox nem exibem o prompt) e cada
/// falha tem mensagem e ação de recuperação — nunca trava nem silencia.
class LocationGate extends StatefulWidget {
  const LocationGate({super.key, required this.onGranted});

  /// Chamado uma vez quando o acesso está garantido.
  final VoidCallback onGranted;

  @override
  State<LocationGate> createState() => _LocationGateState();
}

class _LocationGateState extends State<LocationGate> {
  LocationGateStatus _status = LocationGateStatus.checking;
  String? _detail;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    if (!mounted) return;
    setState(() {
      _status = LocationGateStatus.checking;
      _detail = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          setState(() => _status = LocationGateStatus.serviceOff);
        }
        return;
      }
      await _applyPermission(await Geolocator.checkPermission());
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = LocationGateStatus.error;
          _detail = e.toString();
        });
      }
    }
  }

  Future<void> _applyPermission(LocationPermission permission) async {
    if (!mounted) return;
    if (permission == LocationPermission.deniedForever) {
      setState(() => _status = LocationGateStatus.blocked);
      return;
    }
    if (permission == LocationPermission.denied) {
      setState(() => _status = LocationGateStatus.needsPrompt);
      return;
    }
    setState(() => _status = LocationGateStatus.granted);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onGranted();
    });
  }

  Future<void> _request() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _detail = null;
    });
    try {
      await _applyPermission(await Geolocator.requestPermission());
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = LocationGateStatus.error;
          _detail = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openSettings() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _detail = null;
    });
    try {
      final opened = await Geolocator.openAppSettings();
      if (!opened && mounted) {
        setState(() {
          _status = LocationGateStatus.error;
          _detail = 'Não foi possível abrir os ajustes. '
              'Libere a localização manualmente e tente de novo.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = LocationGateStatus.error;
          _detail = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (status == LocationGateStatus.checking) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Flexible(child: Text('Verificando localização…')),
            ],
          ),
        ),
      );
    }
    if (status == LocationGateStatus.granted) {
      return const SizedBox.shrink();
    }
    final (icon, title, body, actions) = switch (status) {
      LocationGateStatus.needsPrompt => (
        Icons.location_on_outlined,
        'Ativar localização',
        'O RUNOVER! precisa da sua localização para mostrar o mapa e '
            'validar territórios. O navegador vai pedir permissão ao '
            'tocar no botão abaixo.',
        [
          _GateAction(
            label: 'Ativar localização',
            primary: true,
            busy: _busy,
            onTap: _request,
          ),
        ],
      ),
      LocationGateStatus.blocked => (
        Icons.location_off_outlined,
        'Permissão negada',
        kIsWeb
            ? 'O acesso foi negado. Libere a localização no cadeado da '
                'barra de endereço do navegador e toque em tentar novamente.'
            : 'O acesso foi negado. Libere a localização nos ajustes do '
                'aparelho para continuar.',
        [
          if (!kIsWeb)
            _GateAction(
              label: 'Abrir configurações',
              primary: true,
              busy: _busy,
              onTap: _openSettings,
            ),
          _GateAction(
            label: 'Tentar novamente',
            primary: kIsWeb,
            busy: _busy,
            onTap: _check,
          ),
        ],
      ),
      LocationGateStatus.serviceOff => (
        Icons.gps_off_outlined,
        'GPS desligado',
        'Ative os serviços de localização do aparelho ou do navegador e '
            'tente novamente.',
        [
          _GateAction(
            label: 'Tentar novamente',
            primary: true,
            busy: _busy,
            onTap: _check,
          ),
        ],
      ),
      _ => (
        Icons.error_outline,
        'Falha na localização',
        _detail ?? 'Não foi possível verificar a localização. Tente de novo.',
        [
          _GateAction(
            label: 'Tentar novamente',
            primary: true,
            busy: _busy,
            onTap: _check,
          ),
        ],
      ),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(body),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ),
      ),
    );
  }
}

class _GateAction extends StatelessWidget {
  const _GateAction({
    required this.label,
    required this.primary,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool primary;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label);
    if (primary) {
      return FilledButton(onPressed: busy ? null : onTap, child: child);
    }
    return OutlinedButton(onPressed: busy ? null : onTap, child: child);
  }
}
