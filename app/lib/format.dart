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
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value
      .toDouble()
      .toStringAsFixed(1)
      .replaceAll('.', ',');
}
