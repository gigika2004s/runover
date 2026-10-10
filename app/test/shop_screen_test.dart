import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:runover_app/models.dart';
import 'package:runover_app/screens/shop_screen.dart';
import 'package:runover_app/services/api_client.dart';
import 'package:runover_app/state/app_state.dart';
import 'package:runover_app/theme.dart';

import 'profile_screen_test.dart' show profileData;

void main() {
  group('walletReasonLabel', () {
    final catalog = [
      ShopItem.fromJson({
        'id': 'avatar_corredor',
        'category': 'avatar',
        'name': 'Corredor',
        'price': 50,
        'payload': {'asset': 'corredor', 'animated': false},
      }),
    ];

    test('compra resolve o nome do item pelo catálogo', () {
      expect(walletReasonLabel('compra:avatar_corredor', catalog), 'Corredor');
    });

    test('compra de item fora do catálogo nunca expõe o id', () {
      expect(
        walletReasonLabel('compra:name_estilo_067', catalog),
        'Compra no mercado',
      );
    });

    test('passe distingue compra de recompensa por tier', () {
      expect(walletReasonLabel('passe:s9', catalog), 'Compra do passe');
      expect(
        walletReasonLabel('passe:s9:t3:cosmetic', catalog),
        'Recompensa do passe · nível 3',
      );
    });

    test('motivos de ganho têm rótulo legível', () {
      expect(walletReasonLabel('distancia', catalog), 'Distância percorrida');
      expect(
        walletReasonLabel('conquista', catalog),
        'Conquista de território',
      );
      expect(walletReasonLabel('missao_diaria', catalog), 'Missão diária');
      expect(walletReasonLabel('streak', catalog), 'Sequência de dias');
    });

    test('motivo desconhecido cai no genérico, nunca na chave crua', () {
      expect(walletReasonLabel('futuro:motivo:x', catalog), 'Outro movimento');
    });
  });

  testWidgets('a carteira fala em dracmas e o extrato não expõe id interno',
      (tester) async {
    final client = MockClient((request) async {
      final path = request.url.path;
      if (request.method == 'GET' && path == '/shop/catalog') {
        return http.Response(
          jsonEncode([
            {
              'id': 'avatar_corredor',
              'category': 'avatar',
              'name': 'Corredor',
              'price': 50,
              'payload': {'asset': 'corredor', 'animated': false},
            },
          ]),
          200,
        );
      }
      if (request.method == 'GET' && path == '/shop/inventory') {
        return http.Response(
          jsonEncode({
            'owned': <String>[],
            'equipped_avatar': null,
            'equipped_frame': null,
            'equipped_effect': null,
            'equipped_banner': null,
            'equipped_name_style': null,
            'equipped_emoticons': <String>[],
          }),
          200,
        );
      }
      if (request.method == 'GET' && path == '/shop/wallet') {
        return http.Response(
          jsonEncode({
            'balance': 4517,
            'transactions': [
              // Registro legado malformado: entra na fatia das duas recentes,
              // mas não pode derrubar o cartão — as válidas passam na frente.
              {
                'delta': 'oops',
                'reason': 'distancia',
                'created_at': '2026-10-11T00:00:00Z',
              },
              {
                'delta': -50,
                'reason': 'compra:avatar_corredor',
                'created_at': '2026-10-10T00:00:00Z',
              },
              {
                'delta': -1516,
                'reason': 'compra:name_estilo_067',
                'created_at': '2026-10-09T00:00:00Z',
              },
            ],
          }),
          200,
        );
      }
      return http.Response('{}', 404);
    });
    final api = ApiClient(client: client);
    final state = AppState(api: api)
      ..profile = UserProfile.fromJson(profileData)
      ..status = AuthStatus.signedIn;
    addTearDown(api.close);
    addTearDown(state.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: buildRunoverTheme(),
          home: const ShopScreen(),
        ),
      ),
    );
    // A vitrine tem brilho animado em loop: drena o primeiro frame sem
    // esperar o loop terminar.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('SEU SALDO · DRACMAS'), findsOneWidget);
    expect(find.text('−50 · Corredor'), findsOneWidget);
    expect(find.text('−1.516 · Compra no mercado'), findsOneWidget);
    expect(find.textContaining('compra:'), findsNothing);
    expect(find.textContaining('ORBS'), findsNothing);
  });
}
