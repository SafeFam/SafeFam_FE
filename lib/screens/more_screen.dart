import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'results.dart';
import 'family_flow.dart';
import 'mypage_screen.dart';
import 'login_screen.dart';
import 'whitelist_screen.dart';
import '../sheets.dart';
import '../services/auth_api.dart';
import '../services/app_prefs.dart';
import '../services/app_settings.dart';
import '../services/sms_listener_service.dart';

/// 더보기(설정) — 홈 톱니바퀴로 진입(pushed). 하단 탭 없음.
class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});
  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  // 접근성 설정. 앱 시작 시 AppSettings.load()로 복구된 값을 initState에서 읽는다.
  bool _big = false;
  bool _voice = true;

  // 탐지·알림 설정(users/me/settings). 진입 시 GET, 토글 변경 시 PATCH.
  UserSettings? _settings; // null=아직 못 불러옴
  bool _settingsLoading = true;
  bool _settingsError = false;
  bool _savingSettings = false; // PATCH 진행 중엔 토글 잠금(중복 요청 방지)

  /// 문자 수신 권한 보유 여부. 자동 탐지가 켜져 있어도 이게 없으면 실제로는
  /// 아무 문자도 들어오지 않으므로, 토글 아래에 그 사실을 알린다.
  bool _smsPermission = false;

  @override
  void initState() {
    super.initState();
    _big = AppSettings.instance.bigText.value;
    _voice = AppSettings.instance.voice.value;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _settingsLoading = true;
      _settingsError = false;
    });
    try {
      final s = await AuthApi.getSettings();
      final granted = await SmsListenerService.hasPermission();
      // 서버가 정본이므로, 백그라운드 수신 처리가 보는 기기 사본을 맞춰둔다.
      await AppPrefs.setAutoAnalysisEnabled(s.autoAnalysisEnabled);
      if (s.autoAnalysisEnabled && granted) {
        await SmsListenerService.start();
      }
      if (!mounted) return;
      setState(() {
        _settings = s;
        _smsPermission = granted;
        _settingsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _settingsLoading = false;
        _settingsError = true;
      });
    }
  }

  /// 자동 탐지 토글. 켤 때는 **문자 수신 권한이 먼저**다 — 권한 없이 서버 설정만
  /// 켜두면 토글은 켜졌는데 아무 문자도 분석되지 않는 상태가 된다.
  ///
  /// 끌 때는 권한을 건드리지 않는다. 수신기는 매니페스트에 등록돼 있어 계속
  /// 불릴 수 있지만, 처리 첫 단계가 이 설정을 다시 확인하므로 문자는 서버로
  /// 나가지 않는다([SmsListenerService.handleIncoming]).
  Future<void> _setAutoAnalysis(bool v) async {
    if (v) {
      final result = await SmsListenerService.requestPermission();
      if (!mounted) return;
      if (result != SmsPermissionResult.granted) {
        setState(() => _smsPermission = false);
        if (result == SmsPermissionResult.permanentlyDenied) {
          await _showPermissionGuide();
        } else {
          _toast('문자 접근을 허용해야 자동 탐지를 켤 수 있어요');
        }
        return; // 토글은 꺼진 채로 둔다.
      }
      setState(() => _smsPermission = true);
    }
    await _updateSetting(autoAnalysisEnabled: v);
    await AppPrefs.setAutoAnalysisEnabled(_settings?.autoAnalysisEnabled ?? false);
    if (_settings?.autoAnalysisEnabled ?? false) {
      await SmsListenerService.start();
    }
  }

  /// '다시 묻지 않음'으로 거부한 경우 — 앱 안에서는 되돌릴 수 없어 설정으로 안내한다.
  Future<void> _showPermissionGuide() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('문자 접근 권한이 필요해요',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: const Text(
            '받은 문자를 자동으로 검사하려면 문자 접근을 허용해야 해요.\n'
            '휴대폰 설정 > 권한에서 켜주세요.',
            style: TextStyle(fontSize: 15)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('나중에')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('설정 열기')),
        ],
      ),
    );
    if (go == true) await SmsListenerService.openSettings();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  /// 토글 변경 → 낙관적으로 UI 먼저 반영하고 PATCH. 실패하면 되돌리고 안내.
  Future<void> _updateSetting({bool? autoAnalysisEnabled, bool? pushEnabled}) async {
    final prev = _settings;
    if (prev == null) return;
    setState(() {
      _savingSettings = true;
      _settings = prev.copyWith(
        autoAnalysisEnabled: autoAnalysisEnabled,
        pushEnabled: pushEnabled,
      );
    });
    final updated = await AuthApi.updateSettings(
      autoAnalysisEnabled: autoAnalysisEnabled,
      pushEnabled: pushEnabled,
    );
    if (!mounted) return;
    setState(() {
      _savingSettings = false;
      if (updated != null) {
        _settings = updated; // 서버 반영값으로 동기화
      } else {
        _settings = prev; // 실패 → 원복
      }
    });
    if (updated == null) {
      _toast('설정을 변경하지 못했어요. 잠시 후 다시 시도해 주세요');
    }
  }

  Widget _link(IconData icon, String label, {VoidCallback? onTap}) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Row(children: [
            Icon(icon, color: AppColors.t2, size: 22),
            const SizedBox(width: 13),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
            const Icon(Icons.chevron_right, color: AppColors.t3),
          ]),
        ),
      );

  /// [on]이 null이면 스위치가 비활성(저장 중 중복 요청 방지 등)된다.
  Widget _toggle(IconData icon, String label, bool v, ValueChanged<bool>? on,
          {String? sub}) =>
      Row(children: [
        Icon(icon, color: AppColors.blue, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(fontSize: 16)),
              if (sub != null) ...[
                const SizedBox(height: 2),
                Text(sub, style: AppText.caption.copyWith(color: AppColors.t3)),
              ],
            ],
          ),
        ),
        Switch(
            value: v,
            activeColor: Colors.white,
            activeTrackColor: AppColors.blue,
            inactiveTrackColor: AppColors.toggleOff,
            onChanged: on),
      ]);

  /// 탐지·알림 설정 카드 — 로딩/에러/정상 3상태. 정상이면 토글 2개.
  Widget _detectionCard() {
    if (_settingsLoading) {
      return const SfCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
              child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: AppColors.blue))),
        ),
      );
    }
    if (_settingsError || _settings == null) {
      return SfCard(
        child: Column(children: [
          const Text('설정을 불러오지 못했어요',
              style: TextStyle(fontSize: 16, color: AppColors.t2)),
          const SizedBox(height: 12),
          SfButton('다시 시도', variant: SfBtn.ghost, onTap: _loadSettings),
        ]),
      );
    }
    final s = _settings!;
    // 저장 중엔 두 토글 모두 잠가 중복/경합 요청을 막는다.
    return SfCard(
      child: Column(children: [
        _toggle(
          Icons.security_outlined,
          '자동 탐지',
          s.autoAnalysisEnabled,
          _savingSettings ? null : _setAutoAnalysis,
          sub: '받은 문자를 자동으로 검사해 위험을 알려드려요',
        ),
        // 서버 설정만 켜져 있고 권한이 없으면 실제로는 동작하지 않는다.
        // 켜진 것처럼 보이게 두지 않고 그 자리에서 바로 알린다.
        if (s.autoAnalysisEnabled && !_smsPermission) ...[
          const SizedBox(height: 10),
          InkWell(
            onTap: _showPermissionGuide,
            child: Row(children: [
              const Icon(Icons.error_outline, size: 18, color: AppColors.med),
              const SizedBox(width: 6),
              Expanded(
                child: Text('문자 접근 권한이 꺼져 있어 검사되지 않아요. 눌러서 켜주세요',
                    style: AppText.caption.copyWith(color: AppColors.med)),
              ),
            ]),
          ),
        ],
        const Divider(color: AppColors.line, height: 24),
        _toggle(
          Icons.notifications_none,
          '푸시 알림',
          s.pushEnabled,
          _savingSettings ? null : (v) => _updateSetting(pushEnabled: v),
          sub: '위험 탐지·가족 알림을 푸시로 받아요',
        ),
      ]),
    );
  }

  /// '대응 도우미'를 분석 없이 바로 연다. 서버가 `analysisId`를 선택 항목으로
  /// 바꿔(SafeFam_BE #91) 컨텍스트 없이도 일반 상담이 되므로, 예전처럼 이력에서
  /// 분석을 고르게 하지 않는다. 특정 문자에 대한 상담은 그 결과 화면에서 열면
  /// 위험도·근거가 함께 실린다.
  void _openHelpChat() => showChatbotSheet(context);

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('로그아웃', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: const Text('정말 로그아웃할까요?', style: TextStyle(fontSize: 15)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('로그아웃', style: TextStyle(color: AppColors.high))),
        ],
      ),
    );
    if (ok != true) return;
    await AuthApi.logout();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
          context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.t1),
            onPressed: () => Navigator.maybePop(context)),
        title: const Text('더보기', style: AppText.titleScreen),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
        children: [
          const SectionLabel('탐지·알림'),
          _detectionCard(),
          const SizedBox(height: 12),
          SfCard(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _link(Icons.verified_user_outlined, '신뢰 발신자 관리',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const WhitelistScreen()))),
          ),
          const SizedBox(height: 16),
          const SectionLabel('보기 설정 · 누구나'),
          SfCard(
            child: Column(children: [
              _toggle(Icons.text_fields, '글씨 더 크게', _big, (v) {
                AppSettings.instance.setBigText(v);
                setState(() => _big = v);
              }, sub: '앱 전체 글씨가 커져요'),
              const Divider(color: AppColors.line, height: 24),
              _toggle(Icons.volume_up_outlined, '음성으로 읽어주기', _voice, (v) {
                AppSettings.instance.setVoice(v);
                setState(() => _voice = v);
              }, sub: '분석 결과를 소리로 들려드려요'),
            ]),
          ),
          const SizedBox(height: 16),
          const SectionLabel('도움말'),
          SfCard(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _link(Icons.smart_toy_outlined, '대응 도우미',
                onTap: _openHelpChat),
          ),
          const SizedBox(height: 16),
          const SectionLabel('가족'),
          SfCard(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
              _link(Icons.person_add_alt, '가족 추가·초대 코드',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const InviteCodeScreen()))),
              const Divider(height: 1, color: AppColors.line),
              // 가입 때 '나중에 하기'로 건너뛴 피보호자가 연결할 수 있는 경로.
              _link(Icons.dialpad, '받은 초대 코드 입력',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const GuardianLinkScreen(fromSignup: false)))),
            ]),
          ),
          const SizedBox(height: 16),
          const SectionLabel('계정'),
          SfCard(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
              _link(Icons.manage_accounts_outlined, '내 정보',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const MyPageScreen()))),
              const Divider(color: AppColors.line, height: 1),
              _link(Icons.logout, '로그아웃', onTap: () => _logout(context)),
            ]),
          ),
          const SizedBox(height: 16),
          const SectionLabel('화면 미리보기 · 개발용'),
          SfCard(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
              _link(Icons.phone_in_talk_outlined, '보이스피싱 결과',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const VoiceResultScreen()))),
              const Divider(color: AppColors.line, height: 1),
              _link(Icons.link, 'URL 검사 결과',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const UrlResultScreen()))),
            ]),
          ),
        ],
      ),
    );
  }
}
