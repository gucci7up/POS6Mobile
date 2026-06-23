import 'package:flutter/material.dart';
import 'package:pos_mobile/state/pos_state.dart';
import 'package:pos_mobile/services/print_service.dart';

// ── Paleta ────────────────────────────────────────────────────────────────────
const _kGold    = Color(0xFFD4AF37);
const _kBg      = Color(0xFF0D0D0D);
const _kSurface = Color(0xFF1A1A1A);
const _kCard    = Color(0xFF222222);
const _kGreen   = Color(0xFF2ECC40);
const _kRed     = Color(0xFFE53935);

// ── Datos de perros ───────────────────────────────────────────────────────────
const _dogs = [
  _Dog(1, 'ROJO',     Color(0xFFCC2200)),
  _Dog(2, 'BLANCO',   Color(0xFFCCCCCC)),
  _Dog(3, 'AZUL',     Color(0xFF1565C0)),
  _Dog(4, 'VERDE',    Color(0xFF2E7D32)),
  _Dog(5, 'AMARILLO', Color(0xFFFFB300)),
  _Dog(6, 'NEGRO',    Color(0xFF424242)),
];

class _Dog {
  final int number;
  final String name;
  final Color color;
  const _Dog(this.number, this.name, this.color);
}

_Dog _dogData(int n) => _dogs[n - 1];

// ── Modos de apuesta ──────────────────────────────────────────────────────────
enum _BetMode { ganador, exacta, trifecta }

class JugadaScreen extends StatefulWidget {
  final PosState state;
  const JugadaScreen({super.key, required this.state});

  @override
  State<JugadaScreen> createState() => _JugadaScreenState();
}

class _JugadaScreenState extends State<JugadaScreen> {
  _BetMode _mode = _BetMode.exacta;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.state.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() { if (mounted) setState(() {}); }

  void _changeMode(_BetMode m) {
    setState(() => _mode = m);
    widget.state.deleteCurrentTicket();
    widget.state.clearBetAmount();
  }

  Future<void> _apostar() async {
    final state = widget.state;
    if (!state.isSalesOpen) {
      _snack('Ventas cerradas para esta carrera');
      return;
    }
    if (state.currentTicketPlays.isEmpty) {
      _snack('Sin jugadas en el ticket');
      return;
    }
    final result = await state.printTicket();
    if (!mounted) return;
    if (result.error != null) { _snack(result.error!); return; }
    final ticket = state.salesHistory
        .where((t) => t.ticketNumber == result.ticketNumber)
        .firstOrNull;
    if (ticket != null) {
      PrintService.printTicket(
        ticket: ticket,
        agencyName: state.agencyName,
        cashier: state.currentUser,
        ticketId: result.ticketId,
      );
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _kGreen,
          content: Text(
            'Ticket #${result.ticketNumber} impreso',
            style: const TextStyle(fontFamily: 'DinNextLtPro', fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: _kRed, content: Text(msg, style: const TextStyle(fontFamily: 'DinNextLtPro'))),
    );
  }

  double _oddsForMode(int dog) {
    final s = widget.state;
    switch (_mode) {
      case _BetMode.ganador:   return s.getGanarOdds(dog);
      case _BetMode.exacta:    return s.getExactaOdds(dog);
      case _BetMode.trifecta:  return s.getTrifectaOdds(dog);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final plays = state.currentTicketPlays;

    return Column(
      children: [
        // Aviso ventas cerradas
        if (!state.isSalesOpen)
          Container(
            width: double.infinity, color: _kRed,
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: const Text(
              'VENTAS CERRADAS',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'DinNextLtPro', letterSpacing: 2),
            ),
          ),

        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Grid de perros ─────────────────────────────────────────
                _DogGrid(state: state, mode: _mode, getOdds: _oddsForMode),
                const SizedBox(height: 4),
                Row(
                  children: const [
                    Icon(Icons.circle, color: _kGreen, size: 8),
                    SizedBox(width: 4),
                    Text('Cuotas actualizadas automáticamente',
                      style: TextStyle(color: Colors.white38, fontFamily: 'DinNextLtPro', fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 10),

                // ── Selector de modo ───────────────────────────────────────
                _BetModeBar(mode: _mode, onChanged: _changeMode),
                const SizedBox(height: 10),

                // ── Selección actual ───────────────────────────────────────
                _SelectionArea(state: state, mode: _mode),
                const SizedBox(height: 10),

                // ── Modos especiales (R, R/2, Reversa, Random) ────────────
                _SpecialModes(state: state, mode: _mode),
                const SizedBox(height: 10),

                // ── Monto + numpad ─────────────────────────────────────────
                _AmountNumpad(state: state, mode: _mode, onApostar: _apostar),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),

        // ── Barra de ticket inferior ───────────────────────────────────────
        _TicketBar(
          state: state,
          onClear: () {
            state.deleteCurrentTicket();
            state.clearBetAmount();
          },
          onApostar: state.isSalesOpen && plays.isNotEmpty ? _apostar : null,
        ),
      ],
    );
  }
}

// ── Grid de perros ────────────────────────────────────────────────────────────

class _DogGrid extends StatelessWidget {
  final PosState state;
  final _BetMode mode;
  final double Function(int) getOdds;
  const _DogGrid({required this.state, required this.mode, required this.getOdds});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _dogs.map((dog) {
        final isS1 = state.selectedDog1 == dog.number;
        final isS2 = state.selectedDog2 == dog.number;
        final isS3 = state.selectedDog3 == dog.number;
        final isSelected = isS1 || isS2 || isS3;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.5),
            child: _DogCard(
              dog: dog,
              isSelected: isSelected,
              posLabel: isS1 ? '1°' : isS2 ? '2°' : isS3 ? '3°' : null,
              odds: getOdds(dog.number),
              enabled: state.isSalesOpen,
              onTap: () => _onTap(dog.number),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _onTap(int n) {
    if (mode == _BetMode.ganador) {
      state.selectDog1(n);
    } else if (mode == _BetMode.exacta) {
      if (state.selectedDog1 == null || state.selectedDog1 == n) {
        state.selectDog1(n);
      } else {
        state.selectDog2(n);
      }
    } else {
      if (state.selectedDog1 == null || state.selectedDog1 == n) {
        state.selectDog1(n);
      } else if (state.selectedDog2 == null || state.selectedDog2 == n) {
        state.selectDog2(n);
      } else {
        state.selectDog3(n);
      }
    }
  }
}

class _DogCard extends StatelessWidget {
  final _Dog dog;
  final bool isSelected;
  final String? posLabel;
  final double odds;
  final bool enabled;
  final VoidCallback onTap;
  const _DogCard({
    required this.dog, required this.isSelected, required this.posLabel,
    required this.odds, required this.enabled, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = dog.color;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.25) : _kCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : Colors.white12,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, spreadRadius: 1)]
              : null,
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Badge de número
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${dog.number}',
                    style: TextStyle(
                      color: dog.number == 2 ? Colors.black87 : Colors.white,
                      fontFamily: 'DinNextLtPro',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (posLabel != null)
                  Positioned(
                    top: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: _kGold,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(posLabel!, style: const TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold, fontFamily: 'DinNextLtPro')),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              dog.name,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontFamily: 'DinNextLtPro',
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              odds.toStringAsFixed(1),
              style: TextStyle(
                color: isSelected ? _kGold : Colors.white38,
                fontFamily: 'DinNextLtPro',
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Selector de modo de apuesta ───────────────────────────────────────────────

class _BetModeBar extends StatelessWidget {
  final _BetMode mode;
  final ValueChanged<_BetMode> onChanged;
  const _BetModeBar({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ModeTab(label: 'GANADOR', icon: Icons.emoji_events_outlined, mode: _BetMode.ganador, current: mode, onTap: () => onChanged(_BetMode.ganador)),
        const SizedBox(width: 6),
        _ModeTab(label: 'EXACTA',  icon: Icons.looks_two_outlined,    mode: _BetMode.exacta,  current: mode, onTap: () => onChanged(_BetMode.exacta)),
        const SizedBox(width: 6),
        _ModeTab(label: 'TRIFECTA', icon: Icons.filter_3_outlined,   mode: _BetMode.trifecta, current: mode, onTap: () => onChanged(_BetMode.trifecta)),
      ],
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final _BetMode mode;
  final _BetMode current;
  final VoidCallback onTap;
  const _ModeTab({required this.label, required this.icon, required this.mode, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = mode == current;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 44,
          decoration: BoxDecoration(
            color: active ? _kGold : _kCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? _kGold : Colors.white12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: active ? Colors.black : Colors.white54, size: 16),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.black : Colors.white54,
                  fontFamily: 'DinNextLtPro',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Área de selección ─────────────────────────────────────────────────────────

class _SelectionArea extends StatelessWidget {
  final PosState state;
  final _BetMode mode;
  const _SelectionArea({required this.state, required this.mode});

  @override
  Widget build(BuildContext context) {
    final slots = _slots();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _modeLabel(),
                style: const TextStyle(color: _kGold, fontFamily: 'DinNextLtPro', fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  state.deleteCurrentTicket();
                  state.clearBetAmount();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kRed.withOpacity(0.15),
                    border: Border.all(color: _kRed.withOpacity(0.4)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.delete_outline, color: _kRed, size: 14),
                      SizedBox(width: 4),
                      Text('LIMPIAR', style: TextStyle(color: _kRed, fontFamily: 'DinNextLtPro', fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...slots.map((slot) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _SelectionSlot(
              posLabel: slot.$1,
              dogNumber: slot.$2,
              onClear: slot.$3,
            ),
          )),
        ],
      ),
    );
  }

  String _modeLabel() {
    switch (mode) {
      case _BetMode.ganador:  return 'GANADOR — Selecciona el 1er lugar';
      case _BetMode.exacta:   return 'EXACTA — Selecciona 1° y 2° lugar';
      case _BetMode.trifecta: return 'TRIFECTA — Selecciona los 3 primeros';
    }
  }

  List<(String, int?, VoidCallback)> _slots() {
    final s = state;
    final list = <(String, int?, VoidCallback)>[];
    list.add(('1°', s.selectedDog1, () => s.selectDog1(s.selectedDog1 ?? 0)));
    if (mode == _BetMode.exacta || mode == _BetMode.trifecta) {
      list.add(('2°', s.selectedDog2, () => s.selectDog2(s.selectedDog2 ?? 0)));
    }
    if (mode == _BetMode.trifecta) {
      list.add(('3°', s.selectedDog3, () => s.selectDog3(s.selectedDog3 ?? 0)));
    }
    return list;
  }
}

class _SelectionSlot extends StatelessWidget {
  final String posLabel;
  final int? dogNumber;
  final VoidCallback onClear;
  const _SelectionSlot({required this.posLabel, required this.dogNumber, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final dog = dogNumber != null ? _dogData(dogNumber!) : null;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: dog != null ? dog.color.withOpacity(0.1) : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: dog != null ? dog.color.withOpacity(0.4) : Colors.white12),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(color: _kGold, borderRadius: BorderRadius.circular(6)),
            alignment: Alignment.center,
            child: Text(posLabel, style: const TextStyle(color: Colors.black, fontFamily: 'DinNextLtPro', fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          if (dog != null) ...[
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(color: dog.color, borderRadius: BorderRadius.circular(6)),
              alignment: Alignment.center,
              child: Text(
                '${dog.number}',
                style: TextStyle(
                  color: dog.number == 2 ? Colors.black87 : Colors.white,
                  fontFamily: 'DinNextLtPro', fontSize: 16, fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(dog.name, style: const TextStyle(color: Colors.white, fontFamily: 'DinNextLtPro', fontSize: 16, fontWeight: FontWeight.bold)),
          ] else
            Text('Seleccionar...', style: TextStyle(color: Colors.white.withOpacity(0.3), fontFamily: 'DinNextLtPro', fontSize: 14)),
          const Spacer(),
          if (dog != null)
            GestureDetector(
              onTap: onClear,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(Icons.cancel, color: Colors.white38, size: 20),
              ),
            )
          else
            const SizedBox(width: 44),
        ],
      ),
    );
  }
}

// ── Modos especiales ──────────────────────────────────────────────────────────

class _SpecialModes extends StatelessWidget {
  final PosState state;
  final _BetMode mode;
  const _SpecialModes({required this.state, required this.mode});

  @override
  Widget build(BuildContext context) {
    if (mode != _BetMode.exacta) return const SizedBox.shrink();
    final hasD1 = state.selectedDog1 != null;
    final hasBoth = hasD1 && state.selectedDog2 != null;
    return Row(
      children: [
        _SpecialBtn(
          label: '↕ REVERSA',
          sublabel: 'Ambos sentidos',
          enabled: hasBoth,
          color: Colors.purple.shade300,
          onTap: () { state.playReverse(); },
        ),
        const SizedBox(width: 6),
        _SpecialBtn(
          label: 'R',
          sublabel: '\$25 c/u · \$350',
          enabled: hasD1,
          color: Colors.blue.shade300,
          onTap: () { state.playR(); },
        ),
        const SizedBox(width: 6),
        _SpecialBtn(
          label: 'R/2',
          sublabel: '\$12.5 c/u · \$175',
          enabled: hasD1,
          color: Colors.teal.shade300,
          onTap: () { state.playR2(); },
        ),
        const SizedBox(width: 6),
        _SpecialBtn(
          label: '🎲 RANDOM',
          sublabel: 'Selección al azar',
          enabled: state.isSalesOpen,
          color: Colors.orange.shade300,
          onTap: () {
            final dogs = List.generate(6, (i) => i + 1)..shuffle();
            state.selectDog1(dogs[0]);
            state.selectDog2(dogs[1]);
          },
        ),
      ],
    );
  }
}

class _SpecialBtn extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool enabled;
  final Color color;
  final VoidCallback onTap;
  const _SpecialBtn({required this.label, required this.sublabel, required this.enabled, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: enabled ? color.withOpacity(0.12) : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: enabled ? color.withOpacity(0.5) : Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(color: enabled ? color : Colors.white24, fontFamily: 'DinNextLtPro', fontSize: 12, fontWeight: FontWeight.bold)),
              Text(sublabel, style: TextStyle(color: enabled ? color.withOpacity(0.7) : Colors.white12, fontFamily: 'DinNextLtPro', fontSize: 9), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Monto + Numpad ────────────────────────────────────────────────────────────

class _AmountNumpad extends StatelessWidget {
  final PosState state;
  final _BetMode mode;
  final VoidCallback onApostar;
  const _AmountNumpad({required this.state, required this.mode, required this.onApostar});

  void _typeAmount(PosState s, String digit) {
    final current = s.currentBetAmount == 0 ? '' : s.currentBetAmount.toStringAsFixed(0).replaceAll('.0', '');
    final next = current + digit;
    final value = double.tryParse(next) ?? s.currentBetAmount;
    s.setBetAmount(value);
  }

  void _backspace(PosState s) {
    final current = s.currentBetAmount == 0 ? '' : s.currentBetAmount.toStringAsFixed(0);
    if (current.length <= 1) { s.setBetAmount(0); return; }
    s.setBetAmount(double.tryParse(current.substring(0, current.length - 1)) ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final s = state;
    final amt = s.currentBetAmount;
    final modeLabel = mode == _BetMode.ganador ? 'GANADOR' : mode == _BetMode.exacta ? 'EXACTA' : 'TRIFECTA';

    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('MONTO DE APUESTA', style: TextStyle(color: Colors.white54, fontFamily: 'DinNextLtPro', fontSize: 11, letterSpacing: 1)),
          const SizedBox(height: 8),

          // Display de monto
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: amt > 0 ? _kGold : Colors.white24, width: amt > 0 ? 1.5 : 1),
            ),
            child: Text(
              amt > 0 ? '\$${amt.toStringAsFixed(amt == amt.roundToDouble() ? 0 : 2)}' : '\$ 0',
              style: TextStyle(
                color: amt > 0 ? Colors.white : Colors.white38,
                fontFamily: 'DinNextLtPro',
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Botones rápidos
          Row(
            children: [
              _QuickAmt('+25',  () => s.addBetAmount(25)),
              const SizedBox(width: 6),
              _QuickAmt('+50',  () => s.addBetAmount(50)),
              const SizedBox(width: 6),
              _QuickAmt('+100', () => s.addBetAmount(100),  highlighted: true),
              const SizedBox(width: 6),
              _QuickAmt('+500', () => s.addBetAmount(500)),
            ],
          ),
          const SizedBox(height: 10),

          // Numpad 4x4
          _buildNumpad(s, modeLabel),
        ],
      ),
    );
  }

  Widget _buildNumpad(PosState s, String modeLabel) {
    return SizedBox(
      height: 220,
      child: Row(
        children: [
          // Teclas 3x4
          Expanded(
            flex: 3,
            child: Column(
              children: [
                _NumRow(['1','2','3'],     s),
                const SizedBox(height: 6),
                _NumRow(['4','5','6'],     s),
                const SizedBox(height: 6),
                _NumRow(['7','8','9'],     s),
                const SizedBox(height: 6),
                _NumRow(['.','0','00'],    s),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Columna derecha
          SizedBox(
            width: 80,
            child: Column(
              children: [
                // Borrar
                Expanded(
                  child: _NumKey(
                    child: const Icon(Icons.backspace_outlined, color: Colors.white70, size: 22),
                    color: Colors.white12,
                    onTap: () => _backspace(s),
                  ),
                ),
                const SizedBox(height: 6),
                // Limpiar
                Expanded(
                  child: _NumKey(
                    child: const Text('LIMPIAR', style: TextStyle(color: _kGold, fontFamily: 'DinNextLtPro', fontSize: 11, fontWeight: FontWeight.bold)),
                    color: _kGold.withOpacity(0.12),
                    onTap: () => s.setBetAmount(0),
                  ),
                ),
                const SizedBox(height: 6),
                // APOSTAR (ocupa 2 filas)
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: onApostar,
                    child: Container(
                      decoration: BoxDecoration(
                        color: s.isSalesOpen && s.currentBetAmount > 0 ? _kGreen : Colors.white12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('APOSTAR', style: TextStyle(color: Colors.white, fontFamily: 'DinNextLtPro', fontSize: 13, fontWeight: FontWeight.bold)),
                          Text(modeLabel, style: const TextStyle(color: Colors.white70, fontFamily: 'DinNextLtPro', fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _NumRow(List<String> digits, PosState s) {
    return Expanded(
      child: Row(
        children: digits.map((d) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _NumKey(
              child: Text(d, style: const TextStyle(color: Colors.white, fontFamily: 'DinNextLtPro', fontSize: 22, fontWeight: FontWeight.bold)),
              color: Colors.white.withOpacity(0.07),
              onTap: () {
                if (d == '00') { _typeAmount(s, '0'); _typeAmount(s, '0'); }
                else if (d == '.') {} // sin decimales en apuestas
                else _typeAmount(s, d);
              },
            ),
          ),
        )).toList(),
      ),
    );
  }
}

class _QuickAmt extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool highlighted;
  const _QuickAmt(this.label, this.onTap, {this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            color: highlighted ? _kGold.withOpacity(0.2) : Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: highlighted ? _kGold : Colors.white24),
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(color: highlighted ? _kGold : Colors.white, fontFamily: 'DinNextLtPro', fontSize: 14, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

class _NumKey extends StatefulWidget {
  final Widget child;
  final Color color;
  final VoidCallback onTap;
  const _NumKey({required this.child, required this.color, required this.onTap});

  @override
  State<_NumKey> createState() => _NumKeyState();
}

class _NumKeyState extends State<_NumKey> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        decoration: BoxDecoration(
          color: _pressed ? widget.color.withOpacity(1.5) : widget.color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        alignment: Alignment.center,
        child: widget.child,
      ),
    );
  }
}

// ── Barra de ticket inferior ──────────────────────────────────────────────────

class _TicketBar extends StatelessWidget {
  final PosState state;
  final VoidCallback onClear;
  final VoidCallback? onApostar;
  const _TicketBar({required this.state, required this.onClear, required this.onApostar});

  @override
  Widget build(BuildContext context) {
    final plays = state.currentTicketPlays;
    final total = state.currentTicketTotal;

    return GestureDetector(
      onTap: plays.isNotEmpty ? () => _showTicketSheet(context) : null,
      child: Container(
        decoration: BoxDecoration(
          color: _kSurface,
          border: const Border(top: BorderSide(color: Colors.white12)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: plays.isNotEmpty ? _kGold.withOpacity(0.15) : Colors.white12,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.receipt_long, color: plays.isNotEmpty ? _kGold : Colors.white38, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    plays.isEmpty ? 'Sin jugadas' : 'TICKET ACTUAL · ${plays.length} jugada${plays.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      color: plays.isEmpty ? Colors.white38 : _kGold,
                      fontFamily: 'DinNextLtPro',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (plays.isNotEmpty)
                    Text(
                      plays.map((p) {
                        final sel = p.dog3 != null ? '${p.dog1}-${p.dog2}-${p.dog3}' : p.dog2 != null ? '${p.dog1}-${p.dog2}' : '${p.dog1}';
                        return '$sel(\$${p.amount.toInt()})';
                      }).join('  '),
                      style: const TextStyle(color: Colors.white70, fontFamily: 'DinNextLtPro', fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (plays.isNotEmpty) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('MONTO', style: TextStyle(color: Colors.white38, fontFamily: 'DinNextLtPro', fontSize: 9)),
                  Text('\$${total.toStringAsFixed(0)}', style: const TextStyle(color: _kGold, fontFamily: 'DinNextLtPro', fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: onApostar != null ? _kGold : Colors.white12,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: onApostar,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.print, size: 16),
                      Text('EMITIR', style: TextStyle(fontFamily: 'DinNextLtPro', fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showTicketSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _TicketSheet(state: state, onClear: onClear, onPrint: onApostar),
    );
  }
}

// ── Bottom sheet del ticket ───────────────────────────────────────────────────

class _TicketSheet extends StatelessWidget {
  final PosState state;
  final VoidCallback onClear;
  final VoidCallback? onPrint;
  const _TicketSheet({required this.state, required this.onClear, required this.onPrint});

  @override
  Widget build(BuildContext context) {
    final plays = state.currentTicketPlays;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle
        Container(margin: const EdgeInsets.symmetric(vertical: 10), width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),

        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text('TICKET ACTUAL', style: TextStyle(color: _kGold, fontFamily: 'DinNextLtPro', fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('\$${state.currentTicketTotal.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontFamily: 'DinNextLtPro', fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1, color: Colors.white12),

        // Lista
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: plays.length,
            itemBuilder: (ctx, i) {
              final p = plays[i];
              final sel = p.dog3 != null ? '${p.dog1}-${p.dog2}-${p.dog3}' : p.dog2 != null ? '${p.dog1}-${p.dog2}' : '${p.dog1}';
              final type = p.dog3 != null ? 'TRIFECTA' : p.dog2 != null ? 'EXACTA' : 'GANADOR';
              return Container(
                color: i % 2 == 0 ? Colors.white.withOpacity(0.04) : Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Text('${i+1}.', style: const TextStyle(color: Colors.white38, fontFamily: 'DinNextLtPro', fontSize: 13)),
                    const SizedBox(width: 10),
                    Text(sel, style: const TextStyle(color: Colors.white, fontFamily: 'DinNextLtPro', fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: _kGold.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                      child: Text(type, style: const TextStyle(color: _kGold, fontFamily: 'DinNextLtPro', fontSize: 10)),
                    ),
                    const Spacer(),
                    Text('\$${p.amount.toInt()}', style: const TextStyle(color: Colors.white, fontFamily: 'DinNextLtPro', fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => state.deletePlayAtIndex(i),
                      child: const Icon(Icons.delete_outline, color: _kRed, size: 20),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const Divider(height: 1, color: Colors.white12),

        // Botones
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () { onClear(); Navigator.pop(context); },
                  style: OutlinedButton.styleFrom(foregroundColor: _kRed, side: const BorderSide(color: _kRed), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  label: const Text('BORRAR', style: TextStyle(fontFamily: 'DinNextLtPro', fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: onPrint != null ? () { Navigator.pop(context); onPrint!(); } : null,
                  style: ElevatedButton.styleFrom(backgroundColor: _kGold, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  icon: const Icon(Icons.print, size: 18),
                  label: const Text('EMITIR TICKET', style: TextStyle(fontFamily: 'DinNextLtPro', fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom),
      ],
    );
  }
}
