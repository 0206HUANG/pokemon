import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

// ─────────── CONFIG DATA ───────────
const Map<int, String> kPokemonNames = {
  1: 'Bulbasaur',
  4: 'Charmander',
  7: 'Squirtle',
  25: 'Pikachu',
  133: 'Eevee',
  152: 'Chikorita',
  255: 'Torchic',
  387: 'Turtwig',
};

const List<int> kThresholds = [10, 25];

const Map<int, List<int>> kEvolutionChains = {
  1: [1, 2, 3],
  4: [4, 5, 6],
  7: [7, 8, 9],
  25: [25, 26],
  133: [133, 134],
  152: [152, 153, 154],
  255: [255, 256, 257],
  387: [387, 388, 389],
};

String spriteUrl(int id) =>
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$id.png';

void main() => runApp(const PokemonTapApp());

class PokemonTapApp extends StatelessWidget {
  const PokemonTapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pokémon Tap Evolution',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const SelectionScreen(),
    );
  }
}

class SelectionScreen extends StatelessWidget {
  const SelectionScreen({super.key});
  // Pikachu first, Bulbasaur at Pikachu's original slot
  static const List<int> starters = [25, 4, 7, 1, 133, 152, 255, 387];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF89CFF0), Color(0xFFFFC0CB), Color(0xFFFFE066)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Choose Your Starter',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        offset: Offset(2, 2),
                        blurRadius: 4,
                        color: Colors.black26,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: GridView.count(
                  padding: const EdgeInsets.all(16),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1,
                  children:
                      starters.map((baseId) {
                        final name = kPokemonNames[baseId]!;
                        final finalEvolution = kEvolutionChains[baseId]!.last;
                        return GestureDetector(
                          onTap:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => GameScreen(baseId: baseId),
                                ),
                              ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white70,
                                width: 2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(2, 2),
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Positioned.fill(
                                  child: Opacity(
                                    opacity: 0.2,
                                    child: Image.network(
                                      spriteUrl(finalEvolution),
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.network(
                                      spriteUrl(baseId),
                                      width: 80,
                                      height: 80,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GameScreen extends StatefulWidget {
  final int baseId;
  const GameScreen({required this.baseId, super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const int _gameDuration = 30;
  static const int _totalPokemon = 1010;
  static const double _targetSize = 80;

  final Random _rand = Random();
  Timer? _timer;
  late List<int> _chain;
  int _stage = 0;

  int _score = 0;
  int _remaining = _gameDuration;

  int _spawnCount = 5;
  late List<int> _targetIds;
  late List<Offset> _targetPos;
  late List<bool> _hitFx;

  bool _evoFx = false;
  Offset _cursorPos = const Offset(-100, -100);

  late List<List<Color>> _bgOptions;
  late List<Color> _bg;

  @override
  void initState() {
    super.initState();
    _chain = kEvolutionChains[widget.baseId]!;
    _bgOptions = [
      [Colors.pink, Colors.orange],
      [Colors.cyan, Colors.indigo],
      [Colors.lightGreen, Colors.teal],
      [Colors.amber, Colors.deepPurple],
    ];
    _startGame();
  }

  void _startGame() {
    _score = 0;
    _remaining = _gameDuration;
    _stage = 0;
    // random spawn count between 5 and 7
    _spawnCount = 5 + _rand.nextInt(3);
    _initTargets();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining <= 0) {
        t.cancel();
        _showGameOver();
      } else {
        setState(() => _remaining--);
      }
    });
  }

  void _initTargets() {
    _targetIds = List.generate(
      _spawnCount,
      (_) => _rand.nextInt(_totalPokemon) + 1,
    );
    _targetPos = List.generate(_spawnCount, (_) => Offset.zero);
    _hitFx = List.generate(_spawnCount, (_) => false);
    _bg = _bgOptions[_rand.nextInt(_bgOptions.length)];
  }

  void _respawn(int i) {
    _targetIds[i] = _rand.nextInt(_totalPokemon) + 1;
    _targetPos[i] = Offset.zero;
    _bg = _bgOptions[_rand.nextInt(_bgOptions.length)];
  }

  void _handleTapDown(TapDownDetails d) {
    for (int i = 0; i < _spawnCount; i++) {
      final rect = Rect.fromLTWH(
        _targetPos[i].dx,
        _targetPos[i].dy,
        _targetSize,
        _targetSize,
      );
      if (rect.contains(d.localPosition)) {
        setState(() {
          _score++;
          _checkEvolution();
          _hitFx[i] = true;
          _respawn(i);
        });
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _hitFx[i] = false);
        });
        break;
      }
    }
  }

  void _checkEvolution() {
    if (_stage + 1 < _chain.length && _score >= kThresholds[_stage]) {
      setState(() {
        _stage++;
        _evoFx = true;
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _evoFx = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MouseRegion(
        cursor: SystemMouseCursors.none,
        onHover: (e) => setState(() => _cursorPos = e.localPosition),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _handleTapDown,
          onPanUpdate: (d) => setState(() => _cursorPos += d.delta),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxX = constraints.maxWidth - _targetSize;
              final maxY = constraints.maxHeight - _targetSize - 100;
              for (int i = 0; i < _spawnCount; i++) {
                if (_targetPos[i] == Offset.zero ||
                    _targetPos[i].dx > maxX ||
                    _targetPos[i].dy > maxY) {
                  _targetPos[i] = Offset(
                    _rand.nextDouble() * maxX,
                    100 + _rand.nextDouble() * maxY,
                  );
                }
              }

              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _bg,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 40,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text(
                            'Score: $_score',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Time: $_remaining',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (int i = 0; i < _spawnCount; i++)
                      Positioned(
                        left: _targetPos[i].dx,
                        top: _targetPos[i].dy,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Image.network(
                              spriteUrl(_targetIds[i]),
                              width: _targetSize,
                              height: _targetSize,
                            ),
                            if (_hitFx[i])
                              SizedBox(
                                width: _targetSize + 40,
                                height: _targetSize + 40,
                                child: Lottie.asset(
                                  'assets/party.json',
                                  repeat: false,
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (_evoFx)
                      Center(
                        child: Lottie.asset('assets/party.json', repeat: false),
                      ),
                    Positioned(
                      left: _cursorPos.dx - 30,
                      top: _cursorPos.dy - 30,
                      child: Image.network(
                        spriteUrl(_chain[_stage]),
                        width: 60,
                        height: 60,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showGameOver() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => AlertDialog(
            title: const Text("Time's Up!"),
            content: Text('Your score: $_score'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: const Text('Back'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _startGame();
                },
                child: const Text('Play Again'),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
