import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/models/image_tilte_model.dart';
import 'package:helpcare/presentation/forget_pass1_screen/forget_pass1_screen.dart';
import 'package:helpcare/presentation/home.dart';
import 'package:helpcare/widgets/custom_button.dart';
import 'package:helpcare/widgets/custom_text_form_field.dart';
import 'package:helpcare/core/utils/api_client.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:helpcare/core/utils/focus_bus.dart';
import 'package:helpcare/core/utils/profile_sync_service.dart';
import 'package:helpcare/core/utils/auth_response_parser.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:helpcare/widgets/common_toast.dart';
import 'package:helpcare/core/config/default_dev_account.dart';
import 'package:helpcare/core/utils/auth_input_validation.dart';
import 'package:easy_localization/easy_localization.dart';
// removed sign up and create account navigations in existing login screen

class SignInOneScreen extends StatefulWidget {
  const SignInOneScreen({super.key});

  @override
  State<SignInOneScreen> createState() => _SignInOneScreenState();
}

class _SignInOneScreenState extends State<SignInOneScreen> {
  bool switchVal = false;

  bool obsecur = true;
  final TextEditingController _idCtrl = TextEditingController();
  final TextEditingController _pwCtrl = TextEditingController();
  List<ImageTitleModel> dropdownItemList1 = [
    ImageTitleModel(img: ImageConstant.fb, title: "Sign In with Facebook"),
  ];

  Object? value1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreSavedCredentials());
  }

  Future<void> _restoreSavedCredentials() async {
    try {
      final st = await SettingsStorage.load();
      final String savedEmail = (st['savedLoginEmail'] as String? ?? '').trim();
      final String savedPw = (st['savedLoginPassword'] as String? ?? '');
      if (!mounted) return;
      if (savedEmail.isNotEmpty) _idCtrl.text = savedEmail;
      if (savedPw.isNotEmpty) _pwCtrl.text = savedPw;
      if (savedEmail.isNotEmpty || savedPw.isNotEmpty) {
        setState(() => switchVal = true);
      }
      if (_idCtrl.text.isEmpty && _pwCtrl.text.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;
        _idCtrl.text = DefaultDevAccount.email;
        _pwCtrl.text = DefaultDevAccount.password;
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _persistLoginCredentials(String email, String password) async {
    try {
      final st = await SettingsStorage.load();
      st['savedLoginEmail'] = email;
      st['savedLoginPassword'] = password;
      await SettingsStorage.save(st);
    } catch (_) {}
  }

  Future<void> _upsertLocalAccount({required String email, required String password, String? displayName}) async {
    try {
      final st = await SettingsStorage.load();
      final List<Map<String, dynamic>> localAccounts = (st['localAccounts'] is List)
          ? (st['localAccounts'] as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
          : <Map<String, dynamic>>[];
      final int idx = localAccounts.indexWhere((e) => (e['email'] as String? ?? '').trim().toLowerCase() == email.toLowerCase());
      final Map<String, dynamic> row = {
        'email': email,
        'password': password,
        'displayName': (displayName ?? email).trim().isEmpty ? email : (displayName ?? email).trim(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      };
      if (idx >= 0) {
        localAccounts[idx] = {...localAccounts[idx], ...row};
      } else {
        localAccounts.add({...row, 'createdAt': DateTime.now().toUtc().toIso8601String()});
      }
      st['localAccounts'] = localAccounts;
      await SettingsStorage.save(st);
    } catch (_) {}
  }

  Future<void> _enterOfflineMode(ApiClient api, {required String userId}) async {
    try {
      final s = await SettingsStorage.load();
      final DateTime now = DateTime.now().toUtc();
      s['authToken'] = 'OFFLINE_USER_TOKEN';
      s['guestMode'] = true; // UI 상 Local mode badge 표시
      s['lastUserId'] = userId;
      if ((s['displayName'] as String? ?? '').trim().isEmpty) {
        s['displayName'] = userId;
      }
      s['offlineUploadPending'] = true;
      s['offlineUploadFromGlucose'] = (s['offlineUploadFromGlucose'] as String? ?? '').trim().isEmpty
          ? now.toIso8601String()
          : (s['offlineUploadFromGlucose'] as String?);
      s['offlineUploadFromEvents'] = (s['offlineUploadFromEvents'] as String? ?? '').trim().isEmpty
          ? now.toIso8601String()
          : (s['offlineUploadFromEvents'] as String?);
      await SettingsStorage.save(s);
      await api.loadToken();
      try {
        AppSettingsBus.notify();
      } catch (_) {}
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const Home()),
      (Route<dynamic> route) => false,
    );
    CommonToast.showSuccess(context, 'auth_local_login_toast'.tr());
  }

  Future<bool> _tryOfflineLocalLogin(ApiClient api, String email, String password) async {
    try {
      final st = await SettingsStorage.load();
      final List<Map<String, dynamic>> localAccounts = (st['localAccounts'] is List)
          ? (st['localAccounts'] as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
          : <Map<String, dynamic>>[];
      final int idx = localAccounts.indexWhere((e) => (e['email'] as String? ?? '').trim().toLowerCase() == email.toLowerCase());
      if (idx < 0) return false;
      final String savedPw = (localAccounts[idx]['password'] as String? ?? '');
      if (savedPw != password) return false;
      await _enterOfflineMode(api, userId: email);
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _loggingIn = false;

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('auth_login_title'.tr()),
      ),
      body: SizedBox(
        width: size.width,
        child: SingleChildScrollView(
          child: SizedBox(
            width: size.width,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    margin: getMargin(
                      left: 25,
                      top: 40,
                      right: 25,
                      bottom: 40,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: size.width,
                          height: size.height * 0.22,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            child: Image.asset(
                              ImageConstant.appSplash2,
                              errorBuilder: (context, error, stackTrace) => Image.asset(
                                'assets/images/splash2.png',
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: getPadding(
                            left: 38,
                            top: 62,
                            right: 38,
                          ),
                          child: Text(
                            'auth_sign_in_cgms'.tr(),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.start,
                            style: TextStyle(
                              fontSize: getFontSize(
                                20,
                              ),
                                fontFamily: 'Gilroy-Medium',
                                fontWeight: FontWeight.bold,
                            
                            ),
                          ),
                        ),
                        // keep only id/pw form (no easy-login button here)
                        Container(
                          height: getVerticalSize(
                            2.00,
                          ),
                          width: getHorizontalSize(
                            50.00,
                          ),
                          margin: getMargin(
                            left: 38,
                            top: 16,
                            right: 38,
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white : Colors.black,
                            borderRadius: BorderRadius.circular(
                              getHorizontalSize(
                                1.00,
                              ),
                            ),
                          ),
                        ),
                        // removed easy sign-in dropdown
                       
                       
                        // removed OR separator
                        CustomTextFormField(
                          isDark: isDark,
                          width: 325,                          
                          controller: _idCtrl,
                          focusNode: FocusNode(),
                          hintText: 'auth_login_hint_userid'.tr(),
                          margin: getMargin(
                            top: 24,
                          ),
                          alignment: Alignment.centerLeft,
                          suffix: Container(
                            margin: getMargin(
                              left: 20,
                              top: 21,
                              right: 20,
                              bottom: 21,
                            ),
                            child: CommonImageView(
                              svgPath: ImageConstant.imgCheckmark12X15,
                            ),
                          ),
                          suffixConstraints: BoxConstraints(
                            minWidth: getHorizontalSize(
                              15.00,
                            ),
                            minHeight: getVerticalSize(
                              12.00,
                            ),
                          ),
                        ),
                        CustomTextFormField(
                          isDark: isDark,
                          width: 325,
                          controller: _pwCtrl,
                          focusNode: FocusNode(),
                          hintText: "Enter your Password",
                          margin: getMargin(
                            top: 22,
                          ),
                          variant: TextFormFieldVariant.OutlineDeeppurple101,
                          padding: TextFormFieldPadding.PaddingT19,
                          textInputAction: TextInputAction.done,
                          alignment: Alignment.centerLeft,
                          suffix: GestureDetector(
                            onTap: () {
                              setState(() {
                                obsecur = !obsecur;
                              });
                            },
                            child: Container(
                              margin: getMargin(
                                left: 20,
                                top: 16,
                                right: 20,
                                bottom: 16,
                              ),
                              child: SvgPicture.asset(
                                   obsecur
                                      ? ImageConstant.visibilityOff
                                      : ImageConstant.visibilityOn,
                                      color: ColorConstant.bluegray300,
                                      width: getHorizontalSize(20),
                                      height: getVerticalSize(20),
                                ),
                            ),
                          ),
                          
                          suffixConstraints: BoxConstraints(
                            minWidth: getHorizontalSize(
                              14.00,
                            ),
                            minHeight: getVerticalSize(
                              12.00,
                            ),
                          ),
                          isObscureText: obsecur,
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: getPadding(
                              top: 22,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    FlutterSwitch(
                                      value: switchVal,
                                      height: getHorizontalSize(19),
                                      width: getHorizontalSize(32.3),
                                      toggleSize: 15.2,
                                      borderRadius: getHorizontalSize(
                                        9.50,
                                      ),
                                      activeColor: ColorConstant.indigoA700,
                                      activeToggleColor:
                                          ColorConstant.whiteA700,
                                      inactiveColor:isDark?ColorConstant.darkChoice: ColorConstant.indigo50,
                                      inactiveToggleColor:
                                          ColorConstant.whiteA700,
                                      onToggle: (value) {
                                        setState(() {
                                          switchVal = !switchVal;
                                        });
                                      },
                                    ),
                                    Padding(
                                      padding: getPadding(
                                        left: 9,
                                        right: 9,
                                        top: 3,
                                        bottom: 1,
                                      ),
                                      child: Text(
                                        'auth_remember_me'.tr(),
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.start,
                                        style: TextStyle(
                                          color: ColorConstant.bluegray400,
                                          fontSize: getFontSize(
                                            14,
                                          ),
                                           fontFamily: 'Gilroy-Medium',
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: getPadding(
                                    top: 3,
                                    bottom: 1,
                                  ),
                                  child: InkWell(
                                    onTap: (){
                                      Navigator.push(
    context,
    MaterialPageRoute(builder: (context)
 =>const ForgetPass1Screen()),
  );
                                    },
                                  child: Text(
                                      'auth_forgot_password'.tr(),
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.start,
                                      style: TextStyle(
                                        color: ColorConstant.bluegray400,
                                        fontSize: getFontSize(
                                          14,
                                        ),
                                       fontFamily: 'Gilroy-Medium',
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        CustomButton(
                          width: double.infinity,
                          text: 'auth_sign_in_upper'.tr(),
                          variant: ButtonVariant.FillLoginGreen,
                          margin: getMargin(
                            top: 39,
                           
                          ),
                          alignment: Alignment.centerLeft,
                          onTap: () async {
                            if (_loggingIn) return;
                            setState(() => _loggingIn = true);
                            Future<http.Response> doLogin(ApiClient api, String email, String password) {
                              return api.post('/api/auth/login', body: { 'email': email, 'password': password });
                            }
                            try {
                              final email = _idCtrl.text.trim();
                              final password = _pwCtrl.text;
                              if (email.isEmpty || password.isEmpty) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('auth_enter_id_password_snack'.tr())));
                                return;
                              }
                              if (!isValidLoginEmailId(email)) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('auth_login_invalid_email'.tr())),
                                );
                                return;
                              }
                              final api = ApiClient();
                              await api.loadToken();
                              http.Response resp;
                              try {
                                resp = await doLogin(api, email, password);
                              } on TimeoutException catch (_) {
                                final bool ok = await _tryOfflineLocalLogin(api, email, password);
                                if (ok) return;
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('auth_login_network_required'.tr())),
                                );
                                return;
                              } on SocketException catch (_) {
                                final bool ok = await _tryOfflineLocalLogin(api, email, password);
                                if (ok) return;
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('auth_login_network_required'.tr())),
                                );
                                return;
                              } on http.ClientException catch (_) {
                                final bool ok = await _tryOfflineLocalLogin(api, email, password);
                                if (ok) return;
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('auth_login_network_required'.tr())),
                                );
                                return;
                              } catch (e) {
                                final msg = e.toString().toLowerCase();
                                if (msg.contains('socket') || msg.contains('network') || msg.contains('connection') || msg.contains('failed host lookup')) {
                                  final bool ok = await _tryOfflineLocalLogin(api, email, password);
                                  if (ok) return;
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('auth_login_network_required'.tr())),
                                  );
                                  return;
                                }
                                if (!mounted) return;
                                await showDialog(context: context, builder: (_) => AlertDialog(title: Text('auth_login_failed'.tr()), content: Text('auth_error_with_detail'.tr(namedArgs: {'e': '$e'})), actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: Text('common_ok'.tr()))]));
                                return;
                              }
                              if (resp.statusCode == 200) {
                                final decoded = jsonDecode(resp.body);
                                if (decoded is! Map) {
                                  if (!mounted) return;
                                  CommonToast.showWarning(context, 'auth_invalid_login_response'.tr());
                                  return;
                                }
                                final data = Map<String, dynamic>.from(decoded as Map);
                                final prof = AuthResponseParser.parseLoginProfile(envelope: data, formEmail: email);
                                final String? token = prof.token;
                                if (token != null && token.isNotEmpty) {
                                  await api.saveToken(token);
                                try {
                                  await _persistLoginCredentials(prof.email, password);
                                  await _upsertLocalAccount(
                                    email: prof.email,
                                    password: password,
                                    displayName: prof.displayName.isNotEmpty ? prof.displayName : prof.email,
                                  );
                                  final st = await SettingsStorage.load();
                                  st['lastUserId'] = prof.email;
                                  st['displayName'] = prof.displayName.isNotEmpty ? prof.displayName : prof.email;
                                  st['guestMode'] = false;
                                  st['offlineUploadPending'] = false;
                                  await SettingsStorage.save(st);
                                } catch (_) {}
                                  try { AppSettingsBus.notify(); } catch (_) {}
                                  unawaited(ProfileSyncService.refreshFromServer());
                                  if (!mounted) return;
                                  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const Home()), (Route<dynamic> route) => false);
                                  CommonToast.showSuccess(context, 'auth_login_success_toast'.tr());
                                } else {
                                  if (!mounted) return;
                                  CommonToast.showWarning(context, 'auth_invalid_token'.tr());
                                }
                              } else {
                                if (!mounted) return;
                                await showDialog(context: context, builder: (_) => AlertDialog(title: Text('auth_login_failed'.tr()), content: Text('auth_login_server_error'.tr()), actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: Text('common_ok'.tr()))]));
                              }
                            } finally {
                              if (mounted) setState(() => _loggingIn = false);
                            }
                          },
                            ),
                        // removed sign-up and create-account entry (existing login only)
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // no easy login here
}
