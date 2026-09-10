import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme/app_colors.dart';

/// Visualizador de câmera para leitura de QR Code.
///
/// Emite [onDetected] com o texto lido. Quando [paused] é verdadeiro, a câmera
/// é parada (útil durante o processamento do código).
class QrScannerView extends StatefulWidget {
  const QrScannerView({
    super.key,
    required this.onDetected,
    this.paused = false,
    this.height = 320,
    this.hint = 'Aponte para o QR Code',
  });

  final ValueChanged<String> onDetected;
  final bool paused;
  final double height;
  final String hint;

  @override
  State<QrScannerView> createState() => _QrScannerViewState();
}

class _QrScannerViewState extends State<QrScannerView> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  bool _torch = false;

  @override
  void didUpdateWidget(covariant QrScannerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paused != widget.paused) {
      if (widget.paused) {
        _controller.stop();
      } else {
        _controller.start();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (widget.paused) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.isNotEmpty) {
        widget.onDetected(value);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.no_photography_outlined,
                      color: Colors.white70, size: 40),
                  SizedBox(height: 8),
                  Text('Câmera indisponível',
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.accent, width: 3),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Text(
              widget.hint,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                shadows: [Shadow(blurRadius: 4)],
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              onPressed: () async {
                try {
                  await _controller.toggleTorch();
                  setState(() => _torch = !_torch);
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Flash não disponível')),
                    );
                  }
                }
              },
              icon: Icon(
                _torch ? Icons.flashlight_off : Icons.flashlight_on,
                color: Colors.white,
              ),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black38,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
