import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/run_store.dart';
import '../services/run_sync.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../widgets/territory_style.dart';
import 'run_detail_screen.dart';
import 'tracking_route_processor.dart';

class TrackingScreen extends StatefulWidget {
  final String? draftId;
  const TrackingScreen({super.key, this.draftId});
  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen>
    with WidgetsBindingObserver {
  RunDraft? _draft;
  RunStore? _store;
  StreamSubscription<Position>? _subscription;
  bool _recording = false;
  bool _busy = false;
  bool _starting = false;
  String? _message;
  TeamDetail? _team;
  List<Territory> _territories = [];
  final Set<String> _contested = {};
  final _mapController = MapController();
  bool _mapReady = false;
  final _name = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    final state = context.read<AppState>();
    _store = RunStore(state.profile!.id);
    try {
      final drafts = await _store!.list();
      if (!mounted) return;
      final matches = drafts.where(
        (d) => widget.draftId != null ? d.id == widget.draftId : !d.queued,
      );
      final restored = matches.isNotEmpty;
      _draft = restored ? matches.first : RunDraft.create();
      _name.text = _draft!.name;
      if (restored) await _store!.save(_draft!);
      if (!mounted) return;
      final track = _draft!.track;
      if (track.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_mapReady) return;
          _mapController.move(
            ll.LatLng(track.last['lat'], track.last['lng']),
            _mapController.camera.zoom,
          );
        });
      }
      setState(() {
        _message = restored
            ? 'Corrida recuperada. Continue ou salve o percurso já registrado.'
            : 'Toque em Iniciar para registrar seu percurso.';
      });
      try {
        final team = await state.api.getMyTeam();
        if (mounted) setState(() => _team = team);
      } catch (_) {
        /* Running individually also works when team lookup fails. */
      }
      try {
        final territories = await state.api.listTerritories();
        if (!mounted) return;
        setState(() {
          _territories = territories;
          for (final p in _draft?.track ?? const <Map<String, dynamic>>[]) {
            _markContested(p);
          }
        });
      } catch (_) {
        /* Territory lines are optional while running. */
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Não foi possível abrir o armazenamento local. Tente novamente antes de correr.',
        );
      }
    }
  }

  Future<void> _start() async {
    if (_starting || _recording || _draft == null || _draft!.queued) return;
    setState(() => _starting = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw ApiException(
          'Sem sinal de GPS. Ative a localização no emulador ou no aparelho e tente novamente.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw ApiException(
          'Permita o acesso à localização para registrar a corrida.',
        );
      }
      if (!mounted) return;
      _draft!.beginSegment();
      await _store!.save(_draft!);
      if (!mounted) return;
      setState(() {
        _recording = true;
        _message = null;
      });
      _subscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.best,
              distanceFilter: 2,
            ),
          ).listen(
            _onPosition,
            onError: (Object _) {
              if (_recording) {
                _pause();
              }
              if (mounted) {
                setState(
                  () => _message =
                      'O GPS foi interrompido. Seu percurso está salvo; tente continuar.',
                );
              }
            },
          );
    } catch (e) {
      if (mounted) {
        setState(
          () => _message = e is ApiException
              ? e.message
              : 'Não foi possível iniciar o GPS.',
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _onPosition(Position position) {
    if (!_recording || !mounted) return;
    final d = _draft!;
    if (d.track.length >= 10000) {
      _pause();
      setState(
        () => _message = 'Limite de pontos atingido. Salve esta corrida.',
      );
      return;
    }
    if (position.accuracy > 50 ||
        !position.latitude.isFinite ||
        !position.longitude.isFinite) {
      return;
    }
    if (d.track.isNotEmpty &&
        !position.timestamp.isAfter(
          DateTime.parse(d.track.last['timestamp']),
        )) {
      return;
    }
    final candidate = {
      'lat': position.latitude,
      'lng': position.longitude,
      'timestamp': position.timestamp.toUtc().toIso8601String(),
      'segment': d.segment,
      'accuracy': position.accuracy,
    };
    if (!TrackingScreenRouteProcessor.isUsablePoint(
      candidate,
      accuracyMeters: 50,
    )) {
      return;
    }
    setState(() {
      final previous = d.track.isEmpty ? null : d.track.last;
      if (previous != null) {
        final previousTime = DateTime.tryParse(previous['timestamp'] as String);
        final currentTime = DateTime.tryParse(candidate['timestamp'] as String);
        if (previousTime != null &&
            currentTime != null &&
            currentTime.isAfter(previousTime)) {
          final distance = Geolocator.distanceBetween(
            (previous['lat'] as num).toDouble(),
            (previous['lng'] as num).toDouble(),
            (candidate['lat'] as num).toDouble(),
            (candidate['lng'] as num).toDouble(),
          );
          final elapsed = currentTime.difference(previousTime).inSeconds;
          if (elapsed > 0 && distance > 250 && elapsed <= 5) {
            return;
          }
        }
      }
      d.track.add(candidate);
      _markContested(candidate);
    });
    if (_mapReady) {
      _mapController.move(
        ll.LatLng(position.latitude, position.longitude),
        _mapController.camera.zoom,
      );
    }
    if (d.track.length % 10 == 0) _persist();
  }

  bool _isRival(Territory t) {
    final profile = context.read<AppState>().profile;
    return isRivalTerritory(
      t,
      myUsername: profile?.username,
      myTeamName: profile?.teamName,
    );
  }

  void _markContested(Map<String, dynamic> point) {
    final lat = (point['lat'] as num).toDouble();
    final lng = (point['lng'] as num).toDouble();
    for (final t in _territories) {
      if (_contested.contains(t.id) || !_isRival(t)) continue;
      if (polygonContains(t.coordinates, lat, lng)) _contested.add(t.id);
    }
  }

  String? get _disputeLabel {
    final rivals = _territories.where((t) => _contested.contains(t.id));
    if (rivals.isEmpty) return null;
    final owners = {
      for (final t in rivals)
        t.isOwnedByTeam ? 'equipe ${t.ownerDisplay}' : '@${t.ownerDisplay}',
    };
    return owners.length == 1
        ? 'Em disputa com ${owners.first}'
        : 'Em disputa com ${owners.length} rivais';
  }

  Future<void> _persist() async {
    if (_draft == null || _store == null || _draft!.queued) return;
    try {
      final sanitized = TrackingScreenRouteProcessor.filterTrack(_draft!.track);
      if (sanitized.length != _draft!.track.length) {
        _draft!.track.clear();
        _draft!.track.addAll(sanitized);
      }
      await _store!.save(_draft!);
    } catch (_) {
      _recording = false;
      await _subscription?.cancel();
      if (mounted) {
        setState(
          () => _message =
              'Falha ao salvar no aparelho. Libere espaço antes de continuar.',
        );
      }
    }
  }

  Future<void> _pause() async {
    _recording = false;
    await _subscription?.cancel();
    _subscription = null;
    await _persist();
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_recording || !mounted) return;
    if (state == AppLifecycleState.detached) {
      _pause();
      if (mounted) {
        setState(
          () => _message =
              'Corrida pausada ao sair do aplicativo. Toque em Continuar ao voltar.',
        );
      }
    }
  }

  Future<void> _finish() async {
    if (_draft == null || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await _pause();
      final draft = _draft!;
      if (!draft.queued) {
        draft.name = _name.text.trim();
      }
      if (!mounted) return;
      final state = context.read<AppState>();
      final result = await RunSync(state.api, _store!).submit(draft);
      state.markRunSaved();
      try {
        await state.refreshProfile();
      } catch (_) {
        /* Upload already succeeded. */
      }
      if (!mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => RunDetailScreen(run: result)));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(
          () => _message =
              '${e is ApiException ? e.message : 'Não foi possível concluir o envio.'}\nA corrida permanece neste aparelho, na aba Corridas.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _persistOnDispose() async {
    final draft = _draft;
    if (draft == null || _store == null || draft.queued) return;
    try {
      draft.name = _name.text.trim();
      final sanitized = TrackingScreenRouteProcessor.filterTrack(draft.track);
      if (sanitized.length != draft.track.length) {
        draft.track.clear();
        draft.track.addAll(sanitized);
      }
      await _store!.save(draft);
    } catch (_) {
      // Disposal must not fail or interrupt teardown.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recording = false;
    _subscription?.cancel();
    unawaited(_persistOnDispose());
    _mapController.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = _draft;
    final track = d?.track ?? [];
    double meters = 0;
    int seconds = 0;
    for (var i = 1; i < track.length; i++) {
      final a = track[i - 1], b = track[i];
      if (a['segment'] != b['segment']) continue;
      meters += Geolocator.distanceBetween(
        a['lat'],
        a['lng'],
        b['lat'],
        b['lng'],
      );
      seconds += DateTime.parse(
        b['timestamp'],
      ).difference(DateTime.parse(a['timestamp'])).inSeconds;
    }
    final groups = <int, List<ll.LatLng>>{};
    for (final p in track) {
      groups
          .putIfAbsent(p['segment'] as int, () => [])
          .add(ll.LatLng(p['lat'], p['lng']));
    }
    final last = track.isEmpty
        ? const ll.LatLng(-23.6489, -46.8523)
        : ll.LatLng(track.last['lat'], track.last['lng']);
    final canEdit = d != null && !d.queued && !_busy;
    final profile = context.watch<AppState>().profile;
    final dispute = _disputeLabel;
    return Scaffold(
      appBar: AppBar(
        title: Text(_recording ? 'Corrida em andamento' : 'Sua corrida'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: last,
                    initialZoom: 16,
                    onMapReady: () => _mapReady = true,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.runover.runover_app',
                    ),
                    PolygonLayer(
                      polygons: [
                        for (final t in _territories)
                          Polygon(
                            points: t.coordinates
                                .map((p) => ll.LatLng(p.lat, p.lng))
                                .toList(),
                            color:
                                territoryColor(
                                  t,
                                  myUsername: profile?.username,
                                  myTeamName: profile?.teamName,
                                ).withValues(
                                  alpha: _contested.contains(t.id)
                                      ? 0.22
                                      : 0.08,
                                ),
                            borderColor: territoryColor(
                              t,
                              myUsername: profile?.username,
                              myTeamName: profile?.teamName,
                            ),
                            borderStrokeWidth: _contested.contains(t.id)
                                ? 5
                                : 2,
                          ),
                      ],
                    ),
                    PolylineLayer(
                      polylines: [
                        for (final points in groups.values)
                          Polyline(
                            points: points,
                            color: Colors.deepOrange,
                            strokeWidth: 4,
                          ),
                      ],
                    ),
                    if (track.isNotEmpty)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: last,
                            width: 24,
                            height: 24,
                            child: const Icon(
                              Icons.my_location,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
                if (dispute != null)
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Card(
                      child: ListTile(
                        leading: const Icon(Icons.flag_outlined),
                        title: Text(dispute),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(meters / 1000).toStringAsFixed(2)} km  •  ${seconds ~/ 60}min ${seconds % 60}s',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (meters >= 10)
                        Text(
                          'Ritmo médio: ${((seconds / (meters / 1000)) / 60).toStringAsFixed(1)} min/km',
                        ),
                      if (_message != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(_message!, textAlign: TextAlign.center),
                        ),
                      if (track.isEmpty && !_recording && _message == null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Sem sinal de GPS. Ative a localização no emulador ou no aparelho para registrar a corrida.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      TextField(
                        controller: _name,
                        enabled: canEdit,
                        maxLength: 80,
                        decoration: const InputDecoration(
                          labelText: 'Nome da corrida',
                        ),
                        onChanged: (value) {
                          d!.name = value;
                          _persist();
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Tentar conquistar território'),
                        subtitle: const Text(
                          'O percurso fica privado. Ao conquistar, a área formada aparece no mapa para os jogadores.',
                        ),
                        value: d?.conquer ?? false,
                        onChanged: canEdit
                            ? (v) {
                                setState(() => d.conquer = v);
                                _persist();
                              }
                            : null,
                      ),
                      if (_team != null)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Conquistar para ${_team!.name}'),
                          value: d?.teamId != null,
                          onChanged: canEdit
                              ? (v) {
                                  setState(
                                    () => d.teamId = v ? _team!.id : null,
                                  );
                                  _persist();
                                }
                              : null,
                        ),
                      if (canEdit)
                        OutlinedButton.icon(
                          onPressed: _starting
                              ? null
                              : (_recording ? _pause : _start),
                          icon: Icon(
                            _recording ? Icons.pause : Icons.play_arrow,
                          ),
                          label: Text(
                            _recording
                                ? 'Pausar'
                                : track.isEmpty
                                ? 'Iniciar'
                                : 'Continuar',
                          ),
                        ),
                      FilledButton.icon(
                        onPressed: _busy || track.length < 2 ? null : _finish,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(
                          _busy
                              ? 'Salvando…'
                              : d?.queued == true
                              ? 'Tentar enviar novamente'
                              : 'Salvar corrida',
                        ),
                      ),
                      const Text(
                        'Mantenha o app aberto durante a gravação. Envie em até 7 dias.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
