import 'package:url_launcher/url_launcher.dart';

/// Opens the device dialer with [phone]. Returns false when nothing could
/// handle the call (for example a desktop browser without a phone app).
Future<bool> dialPhone(String phone) async {
  final String number = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (number.isEmpty) return false;
  try {
    return await launchUrl(Uri(scheme: 'tel', path: number));
  } catch (_) {
    return false;
  }
}
