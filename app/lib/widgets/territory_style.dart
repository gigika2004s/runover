import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../models.dart';
import '../theme.dart';

const rivalPalette = [
  Color(0xFFE53935),
  Color(0xFFD81B60),
  Color(0xFF43A047),
  Color(0xFF8E24AA),
  Color(0xFF1E88E5),
  Color(0xFFF9A825),
];

bool isOwnTerritory(Territory t, {String? myUsername, String? myTeamName}) {
  if (t.isFree || t.ownerDisplay == null) return false;
  return t.isOwnedByTeam
      ? t.ownerDisplay == myTeamName
      : t.ownerDisplay == myUsername;
}

bool isRivalTerritory(Territory t, {String? myUsername, String? myTeamName}) =>
    !t.isFree &&
    !isOwnTerritory(t, myUsername: myUsername, myTeamName: myTeamName);

/// Cada rival recebe sempre a mesma cor, derivada do apelido ou da equipe.
Color territoryColor(Territory t, {String? myUsername, String? myTeamName}) {
  if (t.isFree || t.ownerDisplay == null) return Colors.grey;
  if (isOwnTerritory(t, myUsername: myUsername, myTeamName: myTeamName)) {
    return RunoverColors.territory;
  }
  var hash = t.isOwnedByTeam ? 7 : 0;
  for (final unit in t.ownerDisplay!.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return rivalPalette[hash % rivalPalette.length];
}

bool polygonContains(List<LatLngPoint> ring, double lat, double lng) {
  var inside = false;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final a = ring[i], b = ring[j];
    if ((a.lat > lat) != (b.lat > lat) &&
        lng < (b.lng - a.lng) * (lat - a.lat) / (b.lat - a.lat) + a.lng) {
      inside = !inside;
    }
  }
  return inside;
}

/// De 0 a 1: quanto o território é disputado, somando as trocas de dono e
/// os donos diferentes com território encostado.
double disputeHeat(Territory t, List<Territory> all) {
  if (t.isFree) return 0;
  const distance = ll.Distance();
  final center = ll.LatLng(t.center.lat, t.center.lng);
  final owners = <String>{};
  for (final o in all) {
    if (o.isFree || o.ownerDisplay == null) continue;
    final gap = distance(center, ll.LatLng(o.center.lat, o.center.lng));
    if (gap <= t.radiusM + o.radiusM + 150) {
      owners.add('${o.ownerType}:${o.ownerDisplay}');
    }
  }
  final score = t.takeovers + owners.length - 1;
  return (score / 4).clamp(0, 1).toDouble();
}

Color heatColor(double heat) =>
    Color.lerp(const Color(0xFFFFC107), const Color(0xFFD50000), heat)!;
