/// Formatação pt-BR de milhares (`10.000`) para pontos, moedas e saldos.
///
/// Implementação canônica única — não duplique este regex nas telas;
/// importe daqui.
String formatPoints(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');

/// Número avulso no padrão pt-BR, sem milhar e sem zero sobrando: `10`, `3,4`,
/// `12,3`. É o formato das metas e dos totais de corrida na tela; para pontos e
/// saldos use [formatPoints].
String formatNumber(num value) {
  // Arredonda antes de decidir: `3.96` (resíduo de `distance_m / 1000` ou de
  // `target - value`) é "4" para a pessoa, e mostrar "4,0" contradiz a regra
  // de nunca deixar zero sobrando.
  final one = double.parse(value.toDouble().toStringAsFixed(1));
  if (one == one.roundToDouble()) return one.toInt().toString();
  return one.toStringAsFixed(1).replaceAll('.', ',');
}

/// Meses em pt-BR abreviados, para a etiqueta de dia abaixo.
const _ptMonths = [
  'Jan',
  'Fev',
  'Mar',
  'Abr',
  'Mai',
  'Jun',
  'Jul',
  'Ago',
  'Set',
  'Out',
  'Nov',
  'Dez',
];

/// O dia de um carimbo qualquer, no fuso do aparelho: `Hoje`, `Ontem` ou
/// `3 Out`.
///
/// A pessoa não compara datas, compara "foi hoje?". Por isso os dois dias mais
/// próximos têm nome e o resto volta para o calendário.
String formatDayLabel(DateTime date) {
  final local = date.toLocal();
  final now = DateTime.now();
  final day = DateTime(local.year, local.month, local.day);
  final today = DateTime(now.year, now.month, now.day);
  if (day == today) return 'Hoje';
  if (day == today.subtract(const Duration(days: 1))) return 'Ontem';
  return '${local.day} ${_ptMonths[local.month - 1]}';
}

/// [formatDayLabel] para o campo ISO que chega do servidor. `'Sem data'` quando
/// ele vem ausente ou quebrado — a linha não pode sumir por causa disso.
String formatDayLabelFromIso(Object? iso) {
  final parsed = DateTime.tryParse('$iso');
  if (parsed == null) return 'Sem data';
  return formatDayLabel(parsed);
}

/// Relógio `09:05`, com hora e minuto sempre em dois dígitos.
///
/// Montar `'$hour:$minute'` na mão imprime `9:5`, que não é hora nenhuma. A
/// hora zerada à esquerda é o relógio de 24h do pt-BR: `9:05` parece faltando
/// um dígito.
String formatClock(DateTime date) {
  final local = date.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
