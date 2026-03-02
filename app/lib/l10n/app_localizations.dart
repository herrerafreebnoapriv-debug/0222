import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'MOP'**
  String get appTitle;

  /// No description provided for @login.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get login;

  /// No description provided for @identityPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'手机号或用户名'**
  String get identityPlaceholder;

  /// No description provided for @passwordPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get passwordPlaceholder;

  /// No description provided for @termsTitle.
  ///
  /// In zh, this message translates to:
  /// **'用户须知和免责声明'**
  String get termsTitle;

  /// No description provided for @termsContent.
  ///
  /// In zh, this message translates to:
  /// **'请您在使用前仔细阅读《用户须知和免责声明》。使用本应用即表示您已阅读并同意相关条款。'**
  String get termsContent;

  /// No description provided for @termsAgree.
  ///
  /// In zh, this message translates to:
  /// **'已阅读并同意《用户须知和免责声明》'**
  String get termsAgree;

  /// No description provided for @sessions.
  ///
  /// In zh, this message translates to:
  /// **'会话'**
  String get sessions;

  /// No description provided for @contacts.
  ///
  /// In zh, this message translates to:
  /// **'联系人'**
  String get contacts;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @myCredential.
  ///
  /// In zh, this message translates to:
  /// **'我的凭证'**
  String get myCredential;

  /// No description provided for @changeAvatar.
  ///
  /// In zh, this message translates to:
  /// **'修改头像'**
  String get changeAvatar;

  /// No description provided for @changeProfile.
  ///
  /// In zh, this message translates to:
  /// **'个人简介'**
  String get changeProfile;

  /// No description provided for @changePassword.
  ///
  /// In zh, this message translates to:
  /// **'修改密码'**
  String get changePassword;

  /// No description provided for @userTerms.
  ///
  /// In zh, this message translates to:
  /// **'用户须知与免责声明'**
  String get userTerms;

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// No description provided for @logout.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get logout;

  /// No description provided for @searchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get searchHint;

  /// No description provided for @addFriend.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get addFriend;

  /// No description provided for @chat.
  ///
  /// In zh, this message translates to:
  /// **'聊天'**
  String get chat;

  /// No description provided for @enrollTitle.
  ///
  /// In zh, this message translates to:
  /// **'资料补全'**
  String get enrollTitle;

  /// No description provided for @countryCode.
  ///
  /// In zh, this message translates to:
  /// **'国家/地区'**
  String get countryCode;

  /// No description provided for @phone.
  ///
  /// In zh, this message translates to:
  /// **'手机号'**
  String get phone;

  /// No description provided for @username.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get username;

  /// No description provided for @usernameHint.
  ///
  /// In zh, this message translates to:
  /// **'用于登录'**
  String get usernameHint;

  /// No description provided for @nickname.
  ///
  /// In zh, this message translates to:
  /// **'昵称'**
  String get nickname;

  /// No description provided for @nicknameHint.
  ///
  /// In zh, this message translates to:
  /// **'用于好友展示'**
  String get nicknameHint;

  /// No description provided for @inviteCode.
  ///
  /// In zh, this message translates to:
  /// **'邀请码（选填）'**
  String get inviteCode;

  /// No description provided for @submitEnroll.
  ///
  /// In zh, this message translates to:
  /// **'提交'**
  String get submitEnroll;

  /// No description provided for @credentialTitle.
  ///
  /// In zh, this message translates to:
  /// **'我的凭证'**
  String get credentialTitle;

  /// No description provided for @credentialSave.
  ///
  /// In zh, this message translates to:
  /// **'保存到相册'**
  String get credentialSave;

  /// No description provided for @credentialEnterMain.
  ///
  /// In zh, this message translates to:
  /// **'进入主界面'**
  String get credentialEnterMain;

  /// No description provided for @goEnroll.
  ///
  /// In zh, this message translates to:
  /// **'新用户？去资料补全'**
  String get goEnroll;

  /// No description provided for @enrollSuccess.
  ///
  /// In zh, this message translates to:
  /// **'资料提交成功'**
  String get enrollSuccess;

  /// No description provided for @enrollFail.
  ///
  /// In zh, this message translates to:
  /// **'提交失败'**
  String get enrollFail;

  /// No description provided for @loginFail.
  ///
  /// In zh, this message translates to:
  /// **'登录失败'**
  String get loginFail;

  /// No description provided for @generateInvite.
  ///
  /// In zh, this message translates to:
  /// **'生成邀请'**
  String get generateInvite;

  /// No description provided for @inviteUrl.
  ///
  /// In zh, this message translates to:
  /// **'邀请链接'**
  String get inviteUrl;

  /// No description provided for @copy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In zh, this message translates to:
  /// **'已复制'**
  String get copied;

  /// No description provided for @apiUnavailableHint.
  ///
  /// In zh, this message translates to:
  /// **'当前无法连接服务器，请扫描管理员或好友提供的激活二维码以恢复使用。'**
  String get apiUnavailableHint;

  /// No description provided for @openCameraToScan.
  ///
  /// In zh, this message translates to:
  /// **'打开相机扫码'**
  String get openCameraToScan;

  /// No description provided for @activateByScanTitle.
  ///
  /// In zh, this message translates to:
  /// **'扫码激活'**
  String get activateByScanTitle;

  /// No description provided for @pasteMopLinkHint.
  ///
  /// In zh, this message translates to:
  /// **'粘贴 mop 凭证链接（或扫描二维码）'**
  String get pasteMopLinkHint;

  /// No description provided for @activateButton.
  ///
  /// In zh, this message translates to:
  /// **'激活'**
  String get activateButton;

  /// No description provided for @invalidQr.
  ///
  /// In zh, this message translates to:
  /// **'无效二维码'**
  String get invalidQr;

  /// No description provided for @retryIn30s.
  ///
  /// In zh, this message translates to:
  /// **'30 秒后自动重试'**
  String get retryIn30s;

  /// No description provided for @connectionRestored.
  ///
  /// In zh, this message translates to:
  /// **'连接已恢复，请重新登录'**
  String get connectionRestored;

  /// No description provided for @addFriendTitle.
  ///
  /// In zh, this message translates to:
  /// **'查找添加好友'**
  String get addFriendTitle;

  /// No description provided for @searchUserHint.
  ///
  /// In zh, this message translates to:
  /// **'用户名或手机号（精确搜索）'**
  String get searchUserHint;

  /// No description provided for @addFriendSent.
  ///
  /// In zh, this message translates to:
  /// **'已发送好友请求'**
  String get addFriendSent;

  /// No description provided for @addFriendFail.
  ///
  /// In zh, this message translates to:
  /// **'添加失败'**
  String get addFriendFail;

  /// No description provided for @noSearchResult.
  ///
  /// In zh, this message translates to:
  /// **'未找到用户'**
  String get noSearchResult;

  /// No description provided for @langZh.
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get langZh;

  /// No description provided for @langEn.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get langEn;

  /// No description provided for @langFollowSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get langFollowSystem;

  /// No description provided for @oldPassword.
  ///
  /// In zh, this message translates to:
  /// **'原密码'**
  String get oldPassword;

  /// No description provided for @newPassword.
  ///
  /// In zh, this message translates to:
  /// **'新密码'**
  String get newPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In zh, this message translates to:
  /// **'确认新密码'**
  String get confirmNewPassword;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @changePasswordSuccess.
  ///
  /// In zh, this message translates to:
  /// **'密码已修改'**
  String get changePasswordSuccess;

  /// No description provided for @changePasswordFail.
  ///
  /// In zh, this message translates to:
  /// **'修改失败'**
  String get changePasswordFail;

  /// No description provided for @profileBioHint.
  ///
  /// In zh, this message translates to:
  /// **'个人简介'**
  String get profileBioHint;

  /// No description provided for @profileSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get profileSaved;

  /// No description provided for @profileSaveFail.
  ///
  /// In zh, this message translates to:
  /// **'保存失败'**
  String get profileSaveFail;

  /// No description provided for @passwordMismatch.
  ///
  /// In zh, this message translates to:
  /// **'两次输入的新密码不一致'**
  String get passwordMismatch;

  /// No description provided for @messageHint.
  ///
  /// In zh, this message translates to:
  /// **'输入消息'**
  String get messageHint;

  /// No description provided for @send.
  ///
  /// In zh, this message translates to:
  /// **'发送'**
  String get send;

  /// No description provided for @setRemark.
  ///
  /// In zh, this message translates to:
  /// **'设置备注'**
  String get setRemark;

  /// No description provided for @voiceVideo.
  ///
  /// In zh, this message translates to:
  /// **'音视频'**
  String get voiceVideo;

  /// No description provided for @screenShare.
  ///
  /// In zh, this message translates to:
  /// **'屏幕共享'**
  String get screenShare;

  /// No description provided for @chatPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'暂无消息，Tinode 接入后显示'**
  String get chatPlaceholder;

  /// No description provided for @avatarSelectHint.
  ///
  /// In zh, this message translates to:
  /// **'从相册选择或拍照上传头像'**
  String get avatarSelectHint;

  /// No description provided for @selectImage.
  ///
  /// In zh, this message translates to:
  /// **'选择图片'**
  String get selectImage;

  /// No description provided for @avatarUploadComing.
  ///
  /// In zh, this message translates to:
  /// **'头像上传接口接入后开放'**
  String get avatarUploadComing;

  /// No description provided for @takePhoto.
  ///
  /// In zh, this message translates to:
  /// **'拍照'**
  String get takePhoto;

  /// No description provided for @upload.
  ///
  /// In zh, this message translates to:
  /// **'上传'**
  String get upload;

  /// No description provided for @uploadAvatarSuccess.
  ///
  /// In zh, this message translates to:
  /// **'头像已更新'**
  String get uploadAvatarSuccess;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get confirm;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
