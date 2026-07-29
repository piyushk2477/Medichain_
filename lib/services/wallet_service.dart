import 'api_client.dart';

/// The user's Ethereum wallet is now generated and custodied on the backend
/// (at signup). This client just exposes the address for display; there is no
/// private key on the device any more.
class WalletService {
  static final ApiClient _api = ApiClient.instance;

  /// The current user's checksummed wallet address, or null.
  static Future<String?> getAddress() async {
    try {
      final res = await _api.get('/api/wallet/address');
      return res['address'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// True if the current user has a wallet on file.
  static Future<bool> hasWallet() async => (await getAddress()) != null;
}
