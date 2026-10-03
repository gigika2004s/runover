import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/crown_icon.dart';

/// Mecânica estilo Strava: grava o trajeto do usuário livremente (sem
/// território pré-selecionado). Ao fechar o laço — voltar perto de onde
/// começou — o percurso vira ou retoma um território (RN05).
class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final List<Position> _track = [];
  StreamSubscription<Position>? _sub;
  final _stopwatch = Stopwatch();
  Timer? _ticker;
  double _km = 0;
  double? _distanceToStartM;
  bool _submitting = false;
  String? _statusMessage;
  TeamDetail? _myTeam;
  bool _conquerForTeam = false;
  final _nameCtrl = TextEditingController();
  String? _requestId;

  static const _closeLoopToleranceM = 30.0;

  @override
  void initState() {
    super.initState();
    _loadTeam();
    _start();
  }

  Future<void> _loadTeam() async {
    try {
      final team = await context.read<AppState>().api.getMyTeam();
      if (mounted) setState(() => _myTeam = team);
    } catch (_) {
      // sem equipe — segue individual
    }
  }

  Future<void> _start() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (!enabled ||
        permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(
        () => _statusMessage =
            'Não foi possível acessar sua localização. Verifique as permissões de GPS e tente novamente.',
      );
      return;
    }

    _stopwatch.start();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );

    const settings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 2,
    );
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen((
      pos,
    ) {
      setState(() {
        if (_track.isNotEmpty) {
          _km +=
              Geolocator.distanceBetween(
                _track.last.latitude,
                _track.last.longitude,
                pos.latitude,
                pos.longitude,
              ) /
              1000;
        }
        _track.add(pos);
        if (_track.length > 1) {
          _distanceToStartM = Geolocator.distanceBetween(
            _track.first.latitude,
            _track.first.longitude,
            pos.latitude,
            pos.longitude,
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  bool get _loopClosed =>
      _track.length >= 4 &&
      (_distanceToStartM ?? double.infinity) <= _closeLoopToleranceM;

  String get _elapsed {
    final d = _stopwatch.elapsed;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _pace {
    if (_km < 0.05) return "--'--\"";
    final minutesPerKm = _stopwatch.elapsed.inSeconds / 60 / _km;
    final m = minutesPerKm.floor();
    final s = ((minutesPerKm - m) * 60).round();
    return "$m'${s.toString().padLeft(2, '0')}\"";
  }

  Future<void> _finish() async {
    if (!_loopClosed) {
      setState(
        () => _statusMessage = _distanceToStartM == null
            ? 'Continue correndo até fechar um laço.'
            : 'Volte para perto do início — faltam ${(_distanceToStartM! - _closeLoopToleranceM).clamp(0, double.infinity).toStringAsFixed(0)}m para fechar o laço.',
      );
      return;
    }
    _sub?.cancel();
    _ticker?.cancel();
    setState(() {
      _submitting = true;
      _statusMessage = null;
    });

    final track = _track
        .map(
          (p) => {
            'lat': p.latitude,
            'lng': p.longitude,
            'timestamp': p.timestamp.toUtc().toIso8601String(),
          },
        )
        .toList();

    try {
      final api = context.read<AppState>().api;
      final profile = context.read<AppState>().profile;
      if (profile == null) {
        throw ApiException(
          'Não foi possível identificar sua conta. Entre novamente.',
        );
      }
      _requestId ??= api.newClaimRequestId();
      final result = await api.claimTerritory(
        track,
        requestId: _requestId!,
        userId: profile.id,
        teamId: _conquerForTeam ? _myTeam?.id : null,
        name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
      );
      if (!mounted) return;
      await context.read<AppState>().refreshProfile();
      if (!mounted) return;
      final createdNew = result['created_new'] == true;
      final territoryName = result['territory']['name'];
      final forTeam = _conquerForTeam && _myTeam != null;
      final leveledUp = result['leveled_up'] == true;
      final newLevel = result['new_level'];
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(
            createdNew ? 'Novo território criado!' : 'Território conquistado!',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                forTeam
                    ? 'A equipe ${_myTeam!.name} ${createdNew ? 'criou' : 'dominou'} $territoryName e ganhou ${result['points_awarded']} pontos.'
                    : 'Você ${createdNew ? 'criou' : 'dominou'} $territoryName e ganhou ${result['points_awarded']} pontos.',
              ),
              if (leveledUp) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.arrow_upward,
                      color: RunoverColors.route,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        forTeam
                            ? 'A equipe subiu para o nível $newLevel!'
                            : 'Você subiu para o nível $newLevel!',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Show!'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() {
        _statusMessage = e.message;
        _submitting = false;
      });
      if (!e.isRetryable) {
        // A validação recusou o envio; retome o GPS para corrigir/completar o trajeto.
        const settings = LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 2,
        );
        _sub = Geolocator.getPositionStream(locationSettings: settings).listen((
          pos,
        ) {
          setState(() {
            _track.add(pos);
            _distanceToStartM = Geolocator.distanceBetween(
              _track.first.latitude,
              _track.first.longitude,
              pos.latitude,
              pos.longitude,
            );
          });
        });
        _stopwatch.start();
        _ticker = Timer.periodic(
          const Duration(seconds: 1),
          (_) => setState(() {}),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = _track
        .map((p) => ll.LatLng(p.latitude, p.longitude))
        .toList();
    final center = points.isNotEmpty
        ? points.first
        : const ll.LatLng(-23.6489, -46.8523);

    return Scaffold(
      appBar: AppBar(title: const Text('Corrida em andamento')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(initialCenter: center, initialZoom: 17),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.runover.app',
                    ),
                    if (points.length > 1)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: points,
                            color: _loopClosed
                                ? RunoverColors.territory
                                : RunoverColors.route,
                            strokeWidth: 4,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        if (points.isNotEmpty)
                          Marker(
                            point: points.first,
                            width: 26,
                            height: 26,
                            child: CrownIcon(
                              color: _loopClosed
                                  ? RunoverColors.territory
                                  : RunoverColors.route,
                              size: 22,
                            ),
                          ),
                        if (points.isNotEmpty)
                          Marker(
                            point: points.last,
                            width: 20,
                            height: 20,
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.fromBorderSide(
                                  BorderSide(color: Colors.white, width: 3),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                if (_statusMessage != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 12,
                    child: Card(
                      color: Colors.amber.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_statusMessage!),
                      ),
                    ),
                  ),
                if (_loopClosed)
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 12,
                    child: Card(
                      color: RunoverColors.territory.withValues(alpha: 0.12),
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: RunoverColors.territory,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Laço fechado! Pode finalizar e dominar essa área.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _Stat(label: 'KM', value: _km.toStringAsFixed(2)),
                      _Stat(label: 'TEMPO', value: _elapsed, big: true),
                      _Stat(label: 'PACE', value: _pace),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nome do território (se for novo)',
                      isDense: true,
                    ),
                  ),
                  if (_myTeam != null)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _conquerForTeam,
                      onChanged: (v) => setState(() => _conquerForTeam = v),
                      title: Text('Conquistar para a equipe ${_myTeam!.name}'),
                      subtitle: const Text(
                        'Os pontos vão para a equipe, não para você (RN15)',
                      ),
                    ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: (_loopClosed && !_submitting) ? _finish : null,
                    icon: _submitting
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.flag),
                    label: Text(
                      _submitting ? 'Validando...' : 'Finalizar e dominar',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final bool big;
  const _Stat({required this.label, required this.value, this.big = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: big ? 30 : 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.black54,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
