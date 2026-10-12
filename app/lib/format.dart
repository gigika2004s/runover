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
