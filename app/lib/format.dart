/// Formatação pt-BR de milhares (`10.000`) para pontos, moedas e saldos.
///
/// Implementação canônica única — não duplique este regex nas telas;
/// importe daqui.
String formatPoints(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
