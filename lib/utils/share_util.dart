// lib/utils/share_util.dart
//
// Simple share helper using share_plus. Falls back to plain text if not available.
//
// pubspec.yaml:
// dependencies:
//   share_plus: ^10.0.2
//
import 'package:share_plus/share_plus.dart';

Future<void> shareProfile({required String helperId, required String name}) async {
  // TODO: Replace with your real deep link once Firebase Dynamic Links is set up.
  final link = 'https://servana.app/helper/$helperId';
  await Share.share('Check out $name on Servana: $link');
}
