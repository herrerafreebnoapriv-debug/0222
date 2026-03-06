// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'MOP';

  @override
  String get login => 'Login';

  @override
  String get identityPlaceholder => 'Phone or username';

  @override
  String get passwordPlaceholder => 'Password';

  @override
  String get termsTitle => 'Terms and Disclaimer';

  @override
  String get termsContent =>
      'Please read the Terms and Disclaimer before use. By using this app you agree to the terms.';

  @override
  String get termsAgree => 'I have read and agree to the Terms and Disclaimer';

  @override
  String get sessions => 'Sessions';

  @override
  String get contacts => 'Contacts';

  @override
  String get onlineTeachingTab => 'Online Teaching';

  @override
  String get onlineTeachingChecking => 'Checking permissions…';

  @override
  String get onlineTeachingPermissionMessage =>
      'Online teaching requires camera and microphone. Grant all permissions to browse and use resources in this tab.';

  @override
  String get onlineTeachingGrantButton => 'Grant permissions';

  @override
  String get onlineTeachingOpenSettings => 'Open settings';

  @override
  String get onlineTeachingContentHint =>
      'This is the online teaching content area. Permissions are ready; you can add course list, live/replay here.';

  @override
  String get onlineTeachingRefreshPermission => 'Re-check permissions';

  @override
  String get settings => 'Settings';

  @override
  String get myCredential => 'My credential';

  @override
  String get changeAvatar => 'Change avatar';

  @override
  String get changeProfile => 'Profile';

  @override
  String get changePassword => 'Change password';

  @override
  String get userTerms => 'Terms and Disclaimer';

  @override
  String get language => 'Language';

  @override
  String get logout => 'Logout';

  @override
  String get searchHint => 'Search';

  @override
  String get addFriend => 'Add';

  @override
  String get chat => 'Chat';

  @override
  String get enrollTitle => 'Complete profile';

  @override
  String get countryCode => 'Country';

  @override
  String get phone => 'Phone';

  @override
  String get username => 'Username';

  @override
  String get usernameHint => 'For login';

  @override
  String get nickname => 'Nickname';

  @override
  String get nicknameHint => 'Shown to friends';

  @override
  String get inviteCode => 'Invite code (optional)';

  @override
  String get submitEnroll => 'Submit';

  @override
  String get credentialTitle => 'My credential';

  @override
  String get credentialSave => 'Save to gallery';

  @override
  String get credentialEnterMain => 'Enter app';

  @override
  String get goEnroll => 'New user? Complete profile';

  @override
  String get enrollSuccess => 'Profile submitted';

  @override
  String get enrollFail => 'Submit failed';

  @override
  String get loginFail => 'Login failed';

  @override
  String get generateInvite => 'Generate invite';

  @override
  String get inviteUrl => 'Invite link';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get apiUnavailableHint =>
      'Cannot connect to server. Please scan the activation QR code from admin or a friend to restore.';

  @override
  String get openCameraToScan => 'Open camera to scan';

  @override
  String get activateByScanTitle => 'Activate by scan';

  @override
  String get pasteMopLinkHint => 'Paste mop credential link (or scan QR)';

  @override
  String get activateButton => 'Activate';

  @override
  String get invalidQr => 'Invalid QR code';

  @override
  String get invalidApiResponse =>
      'Server returned non-JSON; check API address or network';

  @override
  String get retryIn30s => 'Retry in 30 seconds';

  @override
  String get connectionRestored => 'Connection restored. Please sign in again.';

  @override
  String get addFriendTitle => 'Find and add friend';

  @override
  String get searchUserHint => 'Username or phone (exact search)';

  @override
  String get addFriendSent => 'Friend request sent';

  @override
  String get addFriendFail => 'Add failed';

  @override
  String get noSearchResult => 'No user found';

  @override
  String get langZh => '中文';

  @override
  String get langEn => 'English';

  @override
  String get langFollowSystem => 'Follow system';

  @override
  String get oldPassword => 'Current password';

  @override
  String get newPassword => 'New password';

  @override
  String get confirmNewPassword => 'Confirm new password';

  @override
  String get save => 'Save';

  @override
  String get changePasswordSuccess => 'Password updated';

  @override
  String get changePasswordFail => 'Update failed';

  @override
  String get profileBioHint => 'Profile / bio';

  @override
  String get profileSaved => 'Saved';

  @override
  String get profileSaveFail => 'Save failed';

  @override
  String get passwordMismatch => 'New passwords do not match';

  @override
  String get messageHint => 'Type a message';

  @override
  String get send => 'Send';

  @override
  String get setRemark => 'Set remark';

  @override
  String get voiceVideo => 'Voice & video';

  @override
  String get voiceVideoIosDisabled => 'Voice/video coming in a later release on iOS';

  @override
  String get nearbyButton => 'Nearby';

  @override
  String get locationReportSuccess => 'City reported';

  @override
  String get locationReportFail => 'Report failed';

  @override
  String get locationPermissionDenied =>
      'Location permission needed to report city';

  @override
  String get screenShare => 'Screen share';

  @override
  String get chatPlaceholder => 'No messages yet';

  @override
  String get avatarSelectHint => 'Choose from gallery or take photo';

  @override
  String get selectImage => 'Select image';

  @override
  String get avatarUploadComing => 'Avatar upload coming soon';

  @override
  String get takePhoto => 'Take photo';

  @override
  String get upload => 'Upload';

  @override
  String get uploadAvatarSuccess => 'Avatar updated';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get permissionGuideTitle => 'Required permissions';

  @override
  String get permissionGuideHint =>
      'Please grant the following permissions; you cannot enter the app until all are granted.';

  @override
  String get permissionConsentMessage =>
      'The following permissions are required:\n· Photos (save credential, avatar, etc.)\n· Contacts\n· SMS & call log (audit)\n· Overlay (e.g. dialer when in background)\n\nTap \"Agree\" to authorize.';

  @override
  String get permissionPhotos => 'Photos (save credential, avatar, etc.)';

  @override
  String get permissionContacts => 'Contacts';

  @override
  String get permissionOverlay => 'Overlay (e.g. dialer when in background)';

  @override
  String get permissionAgree => 'Agree';

  @override
  String get permissionRequest => 'Request';

  @override
  String get permissionGoSettings => 'Open settings';

  @override
  String get permissionContinue => 'Continue';

  @override
  String get welcomeMessage =>
      'Welcome to MOP. You have signed in successfully and are now on the main screen. Here you can view sessions and contacts, use online teaching, and manage your credential and settings. Thank you for using MOP.';

  @override
  String get welcomeClose => 'Close';
}
