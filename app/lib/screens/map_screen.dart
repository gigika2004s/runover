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
  List<Territory> _territories = [];
  ll.LatLng? _myLocation;
  bool _loading = true;
  String? _error;

  static final _defaultCenter = ll.LatLng(-23.6489, -46.8523); // Embu das Artes

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final state = context.read<AppState>();
      try {
        await state.retryPendingClaims();
      } on ApiException {
        // The map remains usable when queued claims cannot be retried yet.
      }
      final api = state.api;
      final territories = await api.listTerritories();
      final pos = await _resolveLocation();
      if (pos != null) {
        unawaited(
          api.pingLocation(pos.latitude, pos.longitude).catchError((_) {}),
        ); // RF14/RNF20
      }
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
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<ll.LatLng?> _resolveLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition();
      return ll.LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
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
    final conquered = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const TrackingScreen()));
    if (conquered == true) _load();
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
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _myLocation ?? _defaultCenter,
                initialZoom: 16,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          const Text(
            'Para dominar essa área, corra até ela e feche um laço passando por dentro — '
            'igual no Strava, ao voltar pro ponto de partida o percurso vira seu.',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
