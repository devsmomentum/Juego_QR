import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/version_check_service.dart';

class WhatsNewService {
  static const String _lastSeenVersionKey = 'last_seen_changelog_version';

  /// Determines if the changelog for the current version should be shown.
  /// Returns [true] if [localVersion] is greater than the [lastSeenVersion]
  /// AND [changelog] is not empty.
  static Future<bool> shouldShow(VersionStatus status) async {
    if (status.changelog.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final lastSeenVersion = prefs.getString(_lastSeenVersionKey) ?? '0.0.0';
    
    return _isNewer(status.localVersion, lastSeenVersion);
  }

  /// Marks the current version's changelog as seen.
  static Future<void> markAsSeen(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSeenVersionKey, version);
  }

  /// Simple version comparison (helper).
  static bool _isNewer(String local, String seen) {
    if (local == seen) return false;
    
    List<int> localParts = local.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> seenParts = seen.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    int maxLength = localParts.length > seenParts.length ? localParts.length : seenParts.length;

    for (int i = 0; i < maxLength; i++) {
      int l = i < localParts.length ? localParts[i] : 0;
      int s = i < seenParts.length ? seenParts[i] : 0;
      if (l > s) return true;
      if (l < s) return false;
    }
    return false;
  }
}
