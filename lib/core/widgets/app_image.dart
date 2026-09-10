import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Exibe uma imagem a partir de URL http(s) ou de um data URL base64.
///
/// O webapp salva a foto da obra como data URL base64 em `obras.foto_url`,
/// enquanto fotos de obra usam URLs do Storage.
class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    required this.placeholder,
  });

  final String? url;
  final BoxFit fit;
  final Widget placeholder;

  @override
  Widget build(BuildContext context) {
    final value = url;
    if (value == null || value.isEmpty) return placeholder;

    if (value.startsWith('data:image')) {
      final bytes = _decodeDataUrl(value);
      if (bytes == null) return placeholder;
      return Image.memory(bytes, fit: fit);
    }

    return Image.network(
      value,
      fit: fit,
      errorBuilder: (_, _, _) => placeholder,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : placeholder,
    );
  }

  Uint8List? _decodeDataUrl(String dataUrl) {
    final comma = dataUrl.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(dataUrl.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }
}
