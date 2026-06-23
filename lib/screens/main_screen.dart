import 'package:flutter/material.dart';
import 'package:pos_mobile/state/pos_state.dart';
import 'package:pos_mobile/screens/jugada_screen.dart';
import 'package:pos_mobile/screens/resultados_screen.dart';
import 'package:pos_mobile/screens/cuotas_screen.dart';
import 'package:pos_mobile/screens/ventas_screen.dart';
import 'package:pos_mobile/screens/premios_screen.dart';
import 'package:pos_mobile/screens/settings_screen.dart';

const kGold   = Color(0xFFD4AF37);
const kBg     = Color(0xFF0D0D0D);
const kSurface = Color(0xFF1A1A1A);
const kCard   = Color(0xFF222222);

class MainScreen extends StatefulWidget {
  final PosState state;
  const MainScreen({super.key, required this.state});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _tabIndex = 0;

  static const _navItems = [
    _NavItem(Icons.point_of_sale_rounded, 'POS'),
    _NavItem(Icons.confirmation_num_outlined, 'TICKETS'),
    _NavItem(Icons.flag_outlined, 'CARRERAS'),
    _NavItem(Icons.bar_chart_rounded, 'REPORTES'),
    _NavItem(Icons.stars_rounded, 'PREMIOS'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final state = widget.state;
        return Scaffold(
          backgroundColor: kBg,
          body: SafeArea(
            child: Column(
              children: [
                _TopBar(state: state, onSettings: () => _openSettings()),
                _RaceInfoCard(state: state),
                Expanded(child: _body(state)),
              ],
            ),
          ),
          bottomNavigationBar: _BottomNav(
            currentIndex: _tabIndex,
            items: _navItems,
            onTap: (i) => setState(() => _tabIndex = i),
          ),
        );
      },
    );
  }

  Widget _body(PosState state) {
    switch (_tabIndex) {
      case 0: return JugadaScreen(state: state);
      case 1: return VentasScreen(state: state);
      case 2: return ResultadosScreen(state: state);
      case 3: return CuotasScreen(state: state);
      case 4: return PremiosScreen(state: state);
      default: return JugadaScreen(state: state);
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final PosState state;
  final VoidCallback onSettings;
  const _TopBar({required this.state, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    final online = state.isServerOnline;
    return Container(
      color: kSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Hamburger
          const Icon(Icons.menu, color: Colors.white, size: 26),
          const SizedBox(width: 12),
          // Logo text
          RichText(
            text: const TextSpan(
              style: TextStyle(fontFamily: 'DinNextLtPro', fontSize: 22, fontWeight: FontWeight.bold),
              children: [
                TextSpan(text: 'MB', style: TextStyle(color: kGold)),
                TextSpan(text: 'SPORT', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
          const Spacer(),
          // Estado conexion
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: online ? Colors.white24 : Colors.red.shade900),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: online ? const Color(0xFF4CAF50) : Colors.red,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  online ? 'CONECTADO' : 'OFFLINE',
                  style: TextStyle(
                    color: online ? Colors.white : Colors.red,
                    fontFamily: 'DinNextLtPro',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Más opciones
          GestureDetector(
            onTap: onSettings,
            child: const Icon(Icons.more_vert, color: Colors.white70, size: 26),
          ),
        ],
      ),
    );
  }
}

// ── Race info card ────────────────────────────────────────────────────────────

class _RaceInfoCard extends StatelessWidget {
  final PosState state;
  const _RaceInfoCard({required this.state});

  String _fmtCountdown(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$s'.replaceFirst(':$s', ':${sec}');
  }

  @override
  Widget build(BuildContext context) {
    final s = state;
    final cd = s.countdownSeconds;
    final m = (cd ~/ 60).toString().padLeft(2, '0');
    final sec = (cd % 60).toString().padLeft(2, '0');
    final cdStr = '$m:$sec';
    final isUrgent = cd < 30 && s.raceStatus == 'OPEN';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          // Carrera actual
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('CARRERA ACTUAL', style: TextStyle(color: Colors.white54, fontFamily: 'DinNextLtPro', fontSize: 10, letterSpacing: 1)),
              Text(
                '${s.currentRace}',
                style: const TextStyle(color: Colors.white, fontFamily: 'DinNextLtPro', fontSize: 36, fontWeight: FontWeight.bold, height: 1),
              ),
            ],
          ),
          const SizedBox(width: 20),
          // Countdown
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.raceStatus == 'OPEN' ? 'INICIO EN' : s.raceStatusLabel,
                style: const TextStyle(color: Colors.white54, fontFamily: 'DinNextLtPro', fontSize: 10, letterSpacing: 1),
              ),
              Text(
                cdStr,
                style: TextStyle(
                  color: isUrgent ? const Color(0xFFE53935) : kGold,
                  fontFamily: 'DinNextLtPro',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
              const Text('SEGUNDOS', style: TextStyle(color: Colors.white38, fontFamily: 'DinNextLtPro', fontSize: 9)),
            ],
          ),
          const Spacer(),
          // Jackpot
          if (s.jackpotAmount > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('JACKPOT', style: TextStyle(color: Colors.white54, fontFamily: 'DinNextLtPro', fontSize: 10, letterSpacing: 1)),
                Text(
                  '\$${s.jackpotAmount.toStringAsFixed(0)}',
                  style: const TextStyle(color: Color(0xFFFFD700), fontFamily: 'DinNextLtPro', fontSize: 16, fontWeight: FontWeight.bold),
                ),
                // X2
                if (s.x2Dog > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      border: Border.all(color: Colors.orange),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '⚡ X2 PERRO ${s.x2Dog}',
                      style: const TextStyle(color: Colors.orange, fontFamily: 'DinNextLtPro', fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Bottom nav ────────────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.currentIndex, required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kSurface,
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Row(
        children: List.generate(items.length, (i) {
          final item = items[i];
          final active = i == currentIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.icon, color: active ? kGold : Colors.white38, size: 24),
                    const SizedBox(height: 3),
                    Text(
                      item.label,
                      style: TextStyle(
                        color: active ? kGold : Colors.white38,
                        fontFamily: 'DinNextLtPro',
                        fontSize: 10,
                        fontWeight: active ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
