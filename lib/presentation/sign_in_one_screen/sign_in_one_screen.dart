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
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:helpcare/widgets/common_toast.dart';
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
    // 화면 로드 완료 후 약간의 딜레이를 두고 테스트 계정 입력
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        if (_idCtrl.text.isEmpty && _pwCtrl.text.isEmpty) {
          _idCtrl.text = 'empecs';
          _pwCtrl.text = 'admin';
        }
      });
    });
  }

  bool _loggingIn = false;

  Future<void> _enterLocalLogin(ApiClient api, String email) async {
    try {
      final s = await SettingsStorage.load();
      s['authToken'] = 'LOCAL_USER_TOKEN';
      s['guestMode'] = false;
      s['lastUserId'] = email;
      s['displayName'] = email;
      await SettingsStorage.save(s);
      await api.loadToken();
      try { AppSettingsBus.notify(); } catch (_) {}
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const Home()),
      (Route<dynamic> route) => false,
    );
    CommonToast.showSuccess(context, 'Local login (offline)');
  }

  Future<void> _enterOfflineMode(ApiClient api, {String? userId}) async {
    try {
      final s = await SettingsStorage.load();
      s['authToken'] = 'OFFLINE_USER_TOKEN';
      s['guestMode'] = true; // 임시 로그인 모드
      if (userId != null && userId.isNotEmpty) {
        s['lastUserId'] = userId;
        s['displayName'] = userId;
      } else {
        s['displayName'] = 'Guest';
      }
      await SettingsStorage.save(s);
      await api.loadToken();
      try { AppSettingsBus.notify(); } catch (_) {}
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const Home()),
      (Route<dynamic> route) => false,
    );
    CommonToast.showSuccess(context, 'Guest login: offline mode');
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Login'),
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
                            "Sign In with CGMS App",
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
                          hintText: "Enter your User ID",
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
                                        "Remember Me",
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
                                      "Forgot Password?",
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
                          text: "Sign In".toUpperCase(),
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
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter ID / Password')));
                                return;
                              }
                              final api = ApiClient();
                              await api.loadToken();
                              http.Response resp;
                              try {
                                resp = await doLogin(api, email, password);
                              } on TimeoutException catch (_) {
                                if (!mounted) return;
                                await _enterLocalLogin(api, email);
                                return;
                              } on SocketException catch (_) {
                                if (!mounted) return;
                                await _enterLocalLogin(api, email);
                                return;
                              } catch (e) {
                                final msg = e.toString().toLowerCase();
                                if (msg.contains('socket') || msg.contains('network') || msg.contains('connection') || msg.contains('failed host lookup')) {
                                  if (!mounted) return;
                                  await _enterLocalLogin(api, email);
                                  return;
                                }
                                if (!mounted) return;
                                await showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Login failed'), content: Text('Error: $e'), actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('OK'))]));
                                return;
                              }
                              if (resp.statusCode == 200) {
                                final data = jsonDecode(resp.body) as Map<String, dynamic>;
                                final token = data['token'] as String?;
                                if (token != null && token.isNotEmpty) {
                                  await api.saveToken(token);
                                try {
                                  final st = await SettingsStorage.load();
                                  st['lastUserId'] = email;
                                  final dn = data['displayName'] ?? data['name'];
                                  st['displayName'] = (dn != null && dn.toString().trim().isNotEmpty) ? dn.toString().trim() : email;
                                  st['guestMode'] = false;
                                  await SettingsStorage.save(st);
                                } catch (_) {}
                                  try { AppSettingsBus.notify(); } catch (_) {}
                                  if (!mounted) return;
                                  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const Home()), (Route<dynamic> route) => false);
                                  CommonToast.showSuccess(context, 'Login successful');
                                } else {
                                  if (!mounted) return;
                                  CommonToast.showWarning(context, 'Invalid token');
                                }
                              } else {
                                if (!mounted) return;
                                await showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Login failed'), content: Text('Server responded ${resp.statusCode}. Please try again.'), actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('OK'))]));
                              }
                            } finally {
                              if (mounted) setState(() => _loggingIn = false);
                            }
                          },
                            ),
                        const SizedBox(height: 10),
                        // Guest Login button (offline mode)
                        CustomButton(
                          width: double.infinity,
                          text: 'GUEST LOGIN',
                          variant: ButtonVariant.OutlinePrimaryWhite,
                          fontStyle: ButtonFontStyle.GilroyMedium16Primary,
                          onTap: () async {
                            if (_loggingIn) return;
                            setState(() => _loggingIn = true);
                            try {
                              final api = ApiClient();
                              await api.loadToken();
                              String userId = '';
                              try {
                                final st = await SettingsStorage.load();
                                userId = (st['lastUserId'] as String? ?? '').trim();
                              } catch (_) {}
                              if (userId.isEmpty) {
                                final fallback = _idCtrl.text.trim();
                                if (fallback.isNotEmpty) userId = fallback;
                              }
                              await _enterOfflineMode(api, userId: userId);
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
