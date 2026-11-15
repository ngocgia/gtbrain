import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../data/food_search_service.dart';

/// Quét barcode → tra dinh dưỡng trên Open Food Facts → trả kết quả
/// cho màn nhập món qua `extra` pop.
class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _processing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final barcode = capture.barcodes.firstOrNull;
    final value = barcode?.rawValue;
    if (value == null || value.isEmpty) return;

    setState(() => _processing = true);
    try {
      final product = await FoodSearchService.instance.lookupBarcode(value);
      if (!mounted) return;
      if (product != null) {
        // Trả kết quả về màn nhập món.
        context.pop(product);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Không tìm thấy mã $value trên Open Food Facts — thử nhập tay nhé.'),
          duration: const Duration(seconds: 3),
        ));
        await Future<void>.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => _processing = false);
      }
    } catch (_) {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Quét mã vạch 🔍')),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.camera_alt_outlined, size: 52),
                    const SizedBox(height: 12),
                    Text(
                      'Không truy cập được camera.\n$error',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Khung ngắm
          Container(
            width: 260,
            height: 170,
            decoration: BoxDecoration(
              border: Border.all(
                  color: theme.colorScheme.primary, width: 3),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          if (_processing)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 10),
                  Text('Đang tra cứu sản phẩm…',
                      style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
