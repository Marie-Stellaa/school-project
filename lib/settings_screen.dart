import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_langage.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  bool _strictMode = false;
  bool _dailyReminder = true;

  AppLanguage get _lang => AppLanguage.instance;


  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (_, controller) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FC),
              borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [

                Container(
                  margin:
                  const EdgeInsets.only(top: 10, bottom: 6),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _lang.tr('language'),
                        style: const TextStyle(
                          color: Color(0xFF0A0F2C),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 16, color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ),


                Expanded(
                  child: ListView.separated(
                    controller: controller,
                    padding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount:
                    AppLanguage.availableLanguages.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final lang =
                      AppLanguage.availableLanguages[i];
                      final isSelected =
                          _lang.code == lang['code'];

                      return GestureDetector(
                        onTap: () async {

                          await _lang
                              .setLanguage(lang['code']!);
                          setModal(() {});
                          setState(() {});
                          if (mounted) {
                            Navigator.pop(context);
                          }
                        },
                        child: AnimatedContainer(
                          duration:
                          const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF0A0F2C)
                                : Colors.white,
                            borderRadius:
                            BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF0A0F2C)
                                  : Colors.grey.shade200,
                            ),
                          ),
                          child: Row(
                            children: [

                              Text(
                                lang['flag']!,
                                style: const TextStyle(
                                    fontSize: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  lang['name']!,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(
                                        0xFF0A0F2C),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle,
                                    color: Colors.white,
                                    size: 20),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  void _logout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(_lang.tr('logout'),
            style: const TextStyle(
                color: Color(0xFF0A0F2C),
                fontWeight: FontWeight.w900)),
        content: const Text('Tu vas être déconnecté(e).'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_lang.tr('cancel'),
                  style:
                  const TextStyle(color: Colors.black45))),
          ElevatedButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const LoginScreen()),
                          (route) => false);
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A0F2C)),
              child: Text(_lang.tr('logout'),
                  style:
                  const TextStyle(color: Colors.white))),
        ],
      ),
    );
  }


  String get _currentLanguageName {
    final match = AppLanguage.availableLanguages.firstWhere(
          (l) => l['code'] == _lang.code,
      orElse: () => {'name': 'Français', 'flag': '🇫🇷'},
    );
    return '${match['flag']} ${match['name']}';
  }

  @override
  Widget build(BuildContext context) {

    return ListenableBuilder(
      listenable: AppLanguage.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FC),
          body: SafeArea(
            child: Column(
              children: [

                Container(
                  color: const Color(0xFF0A0F2C),
                  padding:
                  const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(20),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back,
                              color: Colors.white, size: 16),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _lang.tr('settings'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),


                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [


                      _buildSectionTitle(_lang.tr('general')),
                      _buildCard([

                        _buildItem(
                          icon: Icons.language,
                          label: _lang.tr('language'),
                          trailing: _currentLanguageName,
                          onTap: _showLanguagePicker,
                        ),
                        _buildSwitchItem(
                          icon: Icons.notifications_outlined,
                          label: _lang.tr('notifications'),
                          subtitle: _lang.tr('notif_sub'),
                          value: _notifications,
                          onChanged: (v) => setState(
                                  () => _notifications = v),
                        ),
                        _buildSwitchItem(
                          icon: Icons.wb_sunny_outlined,
                          label: _lang.tr('daily_reminder'),
                          subtitle:
                          _lang.tr('daily_reminder_sub'),
                          value: _dailyReminder,
                          onChanged: (v) => setState(
                                  () => _dailyReminder = v),
                        ),
                      ]),
                      const SizedBox(height: 16),


                      _buildSectionTitle(_lang.tr('blocking')),
                      _buildCard([
                        _buildSwitchItem(
                          icon: Icons.lock_outline,
                          label: _lang.tr('strict_mode'),
                          subtitle:
                          _lang.tr('strict_mode_sub'),
                          value: _strictMode,
                          onChanged: (v) =>
                              setState(() => _strictMode = v),
                        ),
                      ]),
                      const SizedBox(height: 16),


                      _buildSectionTitle(_lang.tr('about')),
                      _buildCard([
                        _buildItem(
                          icon: Icons.info_outline,
                          label: _lang.tr('version'),
                          trailing: '1.0.0',
                          onTap: () {},
                        ),
                        _buildItem(
                          icon: Icons.bug_report_outlined,
                          label: _lang.tr('report_bug'),
                          onTap: () {},
                        ),
                        _buildItem(
                          icon: Icons.star_outline,
                          label: _lang.tr('rate'),
                          onTap: () {},
                        ),
                      ]),
                      const SizedBox(height: 16),


                      _buildSectionTitle(_lang.tr('account')),
                      _buildCard([
                        _buildItem(
                          icon: Icons.logout,
                          label: _lang.tr('logout'),
                          isRed: true,
                          onTap: _logout,
                        ),
                      ]),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(title,
          style: const TextStyle(
            color: Colors.black45,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          )),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildItem({
    required IconData icon,
    required String label,
    String? trailing,
    bool isRed = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
            border: Border(
                bottom:
                BorderSide(color: Colors.grey.shade100))),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isRed
                    ? const Color(0xFFFFE0E0)
                    : const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon,
                  color: isRed
                      ? const Color(0xFFE24B4A)
                      : const Color(0xFF0A0F2C),
                  size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                    color: isRed
                        ? const Color(0xFFE24B4A)
                        : const Color(0xFF0A0F2C),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  )),
            ),
            if (trailing != null)
              Text(trailing,
                  style: const TextStyle(
                      color: Colors.black45, fontSize: 12)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right,
                color: isRed
                    ? const Color(0xFFE24B4A)
                    : Colors.black26,
                size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchItem({
    required IconData icon,
    required String label,
    String? subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          border: Border(
              bottom:
              BorderSide(color: Colors.grey.shade100))),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon,
                color: const Color(0xFF0A0F2C), size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                      color: Color(0xFF0A0F2C),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    )),
                if (subtitle != null)
                  Text(subtitle,
                      style: const TextStyle(
                        color: Colors.black38,
                        fontSize: 10,
                      )),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: const Color(0xFF0A0F2C),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}