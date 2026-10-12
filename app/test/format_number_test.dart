import 'package:flutter_test/flutter_test.dart';
import 'package:runover_app/format.dart';

void main() {
  test('formatNumber não deixa zero sobrando nem mostra resíduo de divisão', () {
    // Inteiro não leva zero: `4.0` é "4".
    expect(formatNumber(4.0), '4');
    // `4800 / 1000` dá 4.8, mas `3960 / 1000` é 4 para a pessoa — não "4,0".
    expect(formatNumber(3.96), '4');
    expect(formatNumber(4.8), '4,8');
    expect(formatNumber(12.34), '12,3');
    expect(formatNumber(7), '7');
    // Arredondar para cima pode levar a centena cheia.
    expect(formatNumber(99.96), '100');
  });

  test('formatPoints separa milhares', () {
    expect(formatPoints(999), '999');
    expect(formatPoints(1000), '1.000');
    expect(formatPoints(12345678), '12.345.678');
  });

  test('formatDayLabel nomeia os dois dias mais próximos', () {
    // Datas relativas ao "hoje" do aparelho: é o que a etiqueta quer dizer.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 12);
    expect(formatDayLabel(today), 'Hoje');
    expect(formatDayLabel(today.subtract(const Duration(days: 1))), 'Ontem');
    // "Ontem" é o dia anterior do calendário, não 24 h atrás: vale em 1º de
    // janeiro (quando o ontem é 31 de dezembro) e vale para qualquer hora daquele
    // dia. E o dia anterior a ele não é ontem mesmo faltando menos de 48 h.
    final ontem = DateTime(now.year, now.month, now.day - 1, 12);
    expect(formatDayLabel(ontem), 'Ontem');
    expect(
      formatDayLabel(DateTime(ontem.year, ontem.month, ontem.day - 1, 23)),
      isNot('Ontem'),
    );
    // O resto volta para o calendário, com o mês em pt-BR. Uma data longe do
    // hoje não depende do dia em que o teste roda.
    expect(formatDayLabel(DateTime(2020, 3, 5, 12)), '5 Mar');
  });

  test('formatDayLabelFromIso lê o carimbo do servidor', () {
    // Meio-dia UTC: em qualquer fuso de teste o dia continua sendo 5 de março.
    expect(formatDayLabelFromIso('2020-03-05T12:00:00Z'), '5 Mar');
    // Campo ausente ou quebrado não pode sumir com a linha.
    expect(formatDayLabelFromIso(null), 'Sem data');
    expect(formatDayLabelFromIso('ontem'), 'Sem data');
  });

  test('formatClock escreve as duas horas de um relógio', () {
    expect(formatClock(DateTime(2026, 10, 12, 9, 5)), '09:05');
    expect(formatClock(DateTime(2026, 10, 12, 23, 0)), '23:00');
  });
}
