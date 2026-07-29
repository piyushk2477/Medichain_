import 'api_client.dart';

/// A lightweight stand-in for the old Supabase `User` object. Screens read
/// `currentUser.id`, `.email` and `.userMetadata?['full_name']`, so those are
/// preserved here.
class SessionUser {
  final String id;
  final String? email;
  final String? fullName;
  final String? role;

  const SessionUser({
    required this.id,
    this.email,
    this.fullName,
    this.role,
  });

  /// Back-compat shim for `user.userMetadata?['full_name']` call sites.
  Map<String, dynamic> get userMetadata => {'full_name': fullName};

  factory SessionUser.fromJson(Map<String, dynamic> j) => SessionUser(
        id: j['id'] as String,
        email: j['email'] as String?,
        fullName: j['full_name'] as String?,
        role: j['role'] as String?,
      );
}

/// Auth + profile helpers. The class name is unchanged from the original
/// (`SupabaseService`) so the screens don't have to change, but every call now
/// goes through the MediChain backend instead of the Supabase SDK.
class SupabaseService {
  static final ApiClient _api = ApiClient.instance;

  static SessionUser? _currentUser;

  static SessionUser? get currentUser => _currentUser;
  static bool get isLoggedIn => _currentUser != null;

  /// Restore a persisted session on app start. Returns true if a valid session
  /// was recovered.
  static Future<bool> restoreSession() async {
    await _api.loadTokens();
    if (!_api.hasToken) return false;
    try {
      final res = await _api.get('/api/auth/me');
      _currentUser =
          SessionUser.fromJson((res['user'] as Map).cast<String, dynamic>());
      return true;
    } catch (_) {
      await _api.clear();
      _currentUser = null;
      return false;
    }
  }

  static Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    final res = await _api.post('/api/auth/signup', body: {
      'email': email,
      'password': password,
      'fullName': fullName,
      'role': role,
    });
    if (res is Map && res['needsEmailConfirmation'] == true) {
      throw Exception(
        (res['message'] as String?) ??
            'Account created! Please confirm your email then sign in.',
      );
    }
    await _storeSession(res);
  }

  static Future<void> login({
    required String email,
    required String password,
  }) async {
    final res = await _api.post('/api/auth/login', body: {
      'email': email,
      'password': password,
    });
    await _storeSession(res);
  }

  static Future<String?> getUserRole() async {
    if (_currentUser?.role != null) return _currentUser!.role;
    final res = await _api.get('/api/auth/role');
    return res['role'] as String?;
  }

  static Future<void> signOut() async {
    try {
      await _api.post('/api/auth/logout');
    } catch (_) {
      // Logout is best-effort; we clear the local session regardless.
    }
    _currentUser = null;
    await _api.clear();
  }

  /// Kept for compatibility. Wallets are created server-side at signup, so this
  /// just mirrors an address onto the profile if ever called.
  static Future<void> saveWalletAddress(String walletAddress) async {
    await _api.post('/api/profiles/wallet', body: {
      'wallet_address': walletAddress,
    });
  }

  static Future<String?> getDoctorWalletAddress(String doctorId) async {
    final res = await _api.get('/api/doctors/$doctorId/wallet');
    return res['wallet_address'] as String?;
  }

  static Future<void> _storeSession(dynamic res) async {
    final m = (res as Map).cast<String, dynamic>();
    await _api.setTokens(
      m['access_token'] as String?,
      m['refresh_token'] as String?,
    );
    if (m['user'] != null) {
      _currentUser =
          SessionUser.fromJson((m['user'] as Map).cast<String, dynamic>());
    }
  }
}
