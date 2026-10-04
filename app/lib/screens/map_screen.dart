import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/api_client.dart';
import '../services/position_refiner.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/crown_icon.dart';
import 'notifications_screen.dart';
import 'tracking_screen.dart';

/// RF06/RF07 — mapa interativo com os territórios e seus donos.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  final _positionRefiner = PositionRefiner();
  List<Territory> _territories = [];
  ll.LatLng? _myLocation;
  bool _loading = false;
  bool _locating = false;
  double? _locationAccuracy;
  String? _locationError;
  String? _error;

  static final _defaultCenter = ll.LatLng(-23.6489, -46.8523); // Embu das Artes

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading || _locating) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final state = context.read<AppState>();
      final api = state.api;
      final pendingRuns = state.retryPendingRuns().catchError(
        (Object _) => false,
      );
      final territories = await api.listTerritories();
      final pos = await _resolveLocation();
      if (pos != null) {
        unawaited(
          api
              .pingLocation(pos.latitude, pos.longitude)
              .catchError((Object _) {}),
        );
      }
      if (!mounted) return; // RF14/RNF20
      setState(() {
        _territories = territories;
        _myLocation = pos;
        _loading = false;
      });
      // O FlutterMap só existe na árvore depois que _loading vira false acima —
      // mover a câmera antes disso derruba o MapController ("not attached yet").
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (pos != null) {
          _mapController.move(pos, 16);
        } else if (territories.isNotEmpty) {
          final c = territories.first.center;
          _mapController.move(ll.LatLng(c.lat, c.lng), 16);
        }
      });
      unawaited(
        pendingRuns.then((submitted) async {
          if (!submitted || !mounted) return;
          try {
            final updatedTerritories = await api.listTerritories();
            if (mounted) {
              setState(() => _territories = updatedTerritories);
            }
          } catch (_) {}
        }),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<ll.LatLng?> _resolveLocation() async {
    _locationAccuracy = null;
    _locationError = null;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw ApiException(
          'Ative a localização do dispositivo e tente novamente.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw ApiException(
          'Permita o acesso à localização nas configurações do navegador ou do aparelho.',
        );
      }
      var pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!pos.latitude.isFinite ||
          !pos.longitude.isFinite ||
          pos.latitude.abs() > 90 ||
          pos.longitude.abs() > 180) {
        throw ApiException(
          'O dispositivo não informou uma localização válida.',
        );
      }
      if (DateTime.now().difference(pos.timestamp) >
          const Duration(minutes: 2)) {
        throw ApiException(
          'A posição recebida está desatualizada. Tente localizar novamente.',
        );
      }
      if (!mounted) return null;
      pos = await _positionRefiner.refine(pos);
      if (pos.accuracy.isFinite && pos.accuracy > 0) {
        _locationAccuracy = pos.accuracy;
      }
      return ll.LatLng(pos.latitude, pos.longitude);
    } on TimeoutException {
      _locationError = 'A localização demorou para responder. Tente novamente.';
    } on ApiException catch (e) {
      _locationError = e.message;
    } catch (_) {
      _locationError = 'Não foi possível obter sua localização. Verifique a permissão e tente novamente.';
    }
    return null;
  }

  Future<void> _locate() async {
    if (_locating || _loading) return;
    setState(() => _locating = true);
    final pos = await _resolveLocation();
    if (!mounted) return;
    setState(() {
      _myLocation = pos;
      _locating = false;
    });
    if (pos != null) {
      _mapController.move(pos, 16);
      unawaited(
        context
            .read<AppState>()
            .api
            .pingLocation(pos.latitude, pos.longitude)
            .catchError((Object _) {}),
      );
    }
  }

  String get _locationLabel {
    if (_locating) return 'Buscando sua localização…';
    if (_locationError != null) return _locationError!;
    final accuracy = _locationAccuracy;
    if (accuracy == null) {
      return 'Localização estimada. O dispositivo não informou a precisão.';
    }
    final margin = accuracy >= 1000
        ? '${(accuracy / 1000).toStringAsFixed(1)} km'
        : '${accuracy.ceil()} m';
    if (accuracy > 50) {
      return 'Localização aproximada: margem informada de $margin. '
          'Para maior precisão, use o celular com GPS.';
    }
    return 'Localização estimada: margem informada de $margin.';
  }

  Color _statusColor(Territory t, String? myUsername, String? myTeamName) {
    if (t.isFree) return Colors.grey;
    if (t.isOwnedByTeam) {
      return t.ownerDisplay == myTeamName
          ? RunoverColors.territory
          : Colors.purple;
    }
    return t.ownerDisplay == myUsername
        ? RunoverColors.territory
        : RunoverColors.route;
  }

  void _openDetail(Territory t) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _TerritorySheet(territory: t),
    );
  }

  Future<void> _startRun() async {
    final conquered = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const TrackingScreen()));
    if (conquered == true) _load();
  }

  @override
  void dispose() {
    _positionRefiner.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AppState>().profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('RUNOVER!'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: RunoverColors.route),
            )
          : _error != null
          ? Center(child: Text(_error!))
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _myLocation ?? _defaultCenter,
                    initialZoom: 16,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.runover.app',
                    ),
                    PolygonLayer(
                      polygons: [
                        for (final t in _territories)
                          Polygon(
                            points: t.coordinates
                                .map((p) => ll.LatLng(p.lat, p.lng))
                                .toList(),
                            color: Colors.transparent,
                            borderColor: _statusColor(
                              t,
                              profile?.username,
                              profile?.teamName,
                            ),
                            borderStrokeWidth: 3,
                          ),
                      ],
                    ),
                    if (_myLocation != null && _locationAccuracy != null)
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: _myLocation!,
                            radius: _locationAccuracy!,
                            useRadiusInMeter: true,
                            color: Colors.blue.withValues(alpha: 0.12),
                            borderColor: Colors.blue.withValues(alpha: 0.45),
                            borderStrokeWidth: 1,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        for (final t in _territories)
                          Marker(
                            point: ll.LatLng(t.center.lat, t.center.lng),
                            width: 36,
                            height: 36,
                            child: GestureDetector(
                              onTap: () => _openDetail(t),
                              child: CrownIcon(
                                color: _statusColor(
                                  t,
                                  profile?.username,
                                  profile?.teamName,
                                ),
                              ),
                            ),
                          ),
                        if (_myLocation != null)
                          Marker(
                            point: _myLocation!,
                            width: 22,
                            height: 22,
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
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: SafeArea(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                        child: Row(
                          children: [
                            Expanded(child: Text(_locationLabel)),
                            if (_locating)
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            else
                              IconButton(
                                tooltip: 'Atualizar localização',
                                onPressed: _locate,
                                icon: const Icon(Icons.my_location),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startRun,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Iniciar corrida'),
        backgroundColor: RunoverColors.route,
      ),
    );
  }
}

class _TerritorySheet extends StatelessWidget {
  final Territory territory;

  const _TerritorySheet({required this.territory});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(territory.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                territory.isFree ? Icons.flag_outlined : Icons.emoji_events,
                color: territory.isFree ? Colors.grey : RunoverColors.route,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                territory.isFree
                    ? 'Território disponível'
                    : territory.isOwnedByTeam
                    ? 'Dominado pela equipe ${territory.ownerDisplay}'
                    : 'Dominado por @${territory.ownerDisplay}',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tamanho aproximado: ~${territory.radiusM.toStringAsFixed(0)}m de raio',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Text(
            'Para dominar essa área, corra até ela e feche um laço passando por dentro — '
            'igual no Strava, ao voltar pro ponto de partida o percurso vira seu.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
