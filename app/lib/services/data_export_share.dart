import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Compartilha o JSON exportado como arquivo; sem compartilhamento
/// disponível (ex.: web sem Web Share) ou com o diálogo travado, copia
/// para a área de transferência. Devolve true quando o usuário recebeu
/// os dados de algum jeito.
Future<bool> shareExportedJson(String filename, String content) async {
  try {
    await SharePlus.instance
        .share(
          ShareParams(
            files: [
              XFile.fromData(
                Uint8List.fromList(utf8.encode(content)),
                name: filename,
                mimeType: 'application/json',
              ),
            ],
            text: 'Meus dados do RUNOVER!',
          ),
        )
        .timeout(const Duration(seconds: 10));
    return true;
  } catch (_) {
    try {
      await Clipboard.setData(ClipboardData(text: content));
      return true;
    } catch (_) {
      return false;
    }
  }
}
