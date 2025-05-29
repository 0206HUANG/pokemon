import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/services.dart';

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

// 新增：特殊Pokemon和稀有度系统
const Map<int, int> kPokemonRarity = {
  // 普通 (1x)
  1: 1, 4: 1, 7: 1, 152: 1, 255: 1, 387: 1,
  // 稀有 (2x)
  25: 2, 133: 2,
  // 传说 (5x) - 特殊Pokemon
  150: 5, 151: 5, 144: 5, 145: 5, 146: 5,
};

const List<int> kLegendaryPokemon = [150, 151, 144, 145, 146];
const List<int> kPowerUpPokemon = [35, 113, 242]; // 胖丁、吉利蛋、幸福蛋

enum WeatherType { sunny, rainy, snowy, stormy }
enum PowerUpType { timeFreeze, scoreMultiplier, rapidFire, magnetism }

// 粒子效果类
class Particle {
  Offset position;
  Offset velocity;
  Color color;
  double life;
  
  Particle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.life,
  });
  
  void update() {
    position += velocity;
    life -= 0.02;
    velocity *= 0.98; // 阻力
  }
}

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
                              color: Colors.white.withValues(alpha: 0.6),
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

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  static const int _gameDuration = 30;
  static const int _totalPokemon = 1010;
  static const double _targetSize = 80;

  final Random _rand = Random();
  Timer? _timer;
  Timer? _weatherTimer;
  Timer? _moveTimer;
  Timer? _powerUpTimer;
  late List<int> _chain;
  int _stage = 0;

  int _score = 0;
  int _remaining = _gameDuration;

  // Game state and effects
  int _combo = 0;
  int _maxCombo = 0;
  double _scoreMultiplier = 1.0;
  WeatherType _currentWeather = WeatherType.sunny;
  
  // Special abilities and power-ups
  bool _timeFreeze = false;
  bool _rapidFire = false;
  bool _magnetism = false;
  int _powerUpDuration = 0;
  
  // Animation controllers
  late AnimationController _shakeController;
  late AnimationController _comboController;
  late Animation<double> _shakeAnimation;
  late Animation<double> _comboAnimation;

  int _spawnCount = 5;
  List<int> _targetIds = [];
  List<Offset> _targetPos = [];
  List<Offset> _targetVelocity = []; // Movement velocity
  List<double> _targetSizes = []; // Different sized targets
  List<bool> _hitFx = [];
  List<bool> _isLegendary = [];
  List<bool> _isPowerUp = [];
  List<double> _targetRotation = []; // Rotation angle

  bool _evoFx = false;
  Offset _cursorPos = const Offset(-100, -100);

  late List<List<Color>> _bgOptions;
  late List<Color> _bg;
  
  // Particle effects
  final List<Particle> _particles = [];
  Timer? _particleTimer;

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
    
    // Initialize animation controllers
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticInOut),
    );
    
    _comboController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _comboAnimation = Tween<double>(begin: 1, end: 1.5).animate(
      CurvedAnimation(parent: _comboController, curve: Curves.elasticOut),
    );
    
    _startGame();
  }

  void _startGame() {
    _score = 0;
    _remaining = _gameDuration;
    _stage = 0;
    _combo = 0;
    _maxCombo = 0;
    _scoreMultiplier = 1.0;
    _currentWeather = WeatherType.sunny;
    _timeFreeze = false;
    _rapidFire = false;
    _magnetism = false;
    _powerUpDuration = 0;
    _particles.clear();
    
    // Random spawn count between 5 and 8
    _spawnCount = 5 + _rand.nextInt(4);
    _initTargets();
    _startTimers();
  }
  
  void _startTimers() {
    _timer?.cancel();
    _weatherTimer?.cancel();
    _moveTimer?.cancel();
    _powerUpTimer?.cancel();
    _particleTimer?.cancel();
    
    // Main game timer
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining <= 0) {
        t.cancel();
        _showGameOver();
      } else if (!_timeFreeze) {
        setState(() => _remaining--);
      }
    });
    
    // Weather change timer
    _weatherTimer = Timer.periodic(const Duration(seconds: 8), (t) {
      _changeWeather();
    });
    
    // Movement timer
    _moveTimer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      _updatePositions();
    });
    
    // Power-up timer
    _powerUpTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_powerUpDuration > 0) {
        setState(() => _powerUpDuration--);
        if (_powerUpDuration == 0) {
          _deactivatePowerUps();
        }
      }
    });
    
    // Particle effect timer
    _particleTimer = Timer.periodic(const Duration(milliseconds: 30), (t) {
      _updateParticles();
    });
  }

  void _initTargets() {
    _targetIds = [];
    _targetPos = [];
    _targetVelocity = [];
    _targetSizes = [];
    _hitFx = [];
    _isLegendary = [];
    _isPowerUp = [];
    _targetRotation = [];
    
    for (int i = 0; i < _spawnCount; i++) {
      _spawnNewTarget(i);
    }
    
    _bg = _bgOptions[_rand.nextInt(_bgOptions.length)];
  }
  
  void _spawnNewTarget(int index) {
    // Randomly decide whether to generate special Pokemon
    bool isLegendary = _rand.nextInt(100) < 3; // 3% chance
    bool isPowerUp = _rand.nextInt(100) < 5; // 5% chance
    
    int pokemonId;
    if (isLegendary) {
      pokemonId = kLegendaryPokemon[_rand.nextInt(kLegendaryPokemon.length)];
    } else if (isPowerUp) {
      pokemonId = kPowerUpPokemon[_rand.nextInt(kPowerUpPokemon.length)];
    } else {
      pokemonId = _rand.nextInt(_totalPokemon) + 1;
    }
    
    double targetSize = isLegendary ? 100 : (isPowerUp ? 90 : _targetSize + _rand.nextDouble() * 20);
    
    // Ensure list length is sufficient
    while (_targetIds.length <= index) {
      _targetIds.add(pokemonId);
      _targetPos.add(Offset.zero);
      _targetVelocity.add(Offset(
        (_rand.nextDouble() - 0.5) * 2, // -1 to 1
        (_rand.nextDouble() - 0.5) * 2,
      ));
      _targetSizes.add(targetSize);
      _hitFx.add(false);
      _isLegendary.add(isLegendary);
      _isPowerUp.add(isPowerUp);
      _targetRotation.add(0);
    }
    
    // Update values at specified index
    if (index < _targetIds.length) {
      _targetIds[index] = pokemonId;
      _targetPos[index] = Offset.zero;
      _targetVelocity[index] = Offset(
        (_rand.nextDouble() - 0.5) * 2,
        (_rand.nextDouble() - 0.5) * 2,
      );
      _targetSizes[index] = targetSize;
      _hitFx[index] = false;
      _isLegendary[index] = isLegendary;
      _isPowerUp[index] = isPowerUp;
      _targetRotation[index] = 0;
    }
  }

  void _respawn(int i) {
    _spawnNewTarget(i);
    _bg = _bgOptions[_rand.nextInt(_bgOptions.length)];
  }
  
  void _changeWeather() {
    setState(() {
      _currentWeather = WeatherType.values[_rand.nextInt(WeatherType.values.length)];
    });
    
    // Weather effects
    switch (_currentWeather) {
      case WeatherType.stormy:
        _shakeController.repeat(reverse: true);
        break;
      case WeatherType.snowy:
        // Slow down movement speed
        for (int i = 0; i < _targetVelocity.length; i++) {
          _targetVelocity[i] *= 0.5;
        }
        break;
      case WeatherType.rainy:
        // Increase score multiplier
        _scoreMultiplier = 1.5;
        break;
      default:
        _shakeController.stop();
        _scoreMultiplier = 1.0;
    }
  }
  
  void _updatePositions() {
    if (_timeFreeze) return;
    
    setState(() {
      for (int i = 0; i < _targetPos.length && i < _targetVelocity.length && i < _targetSizes.length; i++) {
        _targetPos[i] += _targetVelocity[i];
        if (i < _targetRotation.length) {
          _targetRotation[i] += 2;
        }
        
        // Boundary detection and bounce
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        
        if (_targetPos[i].dx < 0 || _targetPos[i].dx > screenWidth - _targetSizes[i]) {
          _targetVelocity[i] = Offset(-_targetVelocity[i].dx, _targetVelocity[i].dy);
        }
        if (_targetPos[i].dy < 100 || _targetPos[i].dy > screenHeight - _targetSizes[i] - 100) {
          _targetVelocity[i] = Offset(_targetVelocity[i].dx, -_targetVelocity[i].dy);
        }
        
        // Magnetism effect
        if (_magnetism) {
          final distance = (_cursorPos - _targetPos[i]).distance;
          if (distance < 150 && distance > 0) {
            final direction = (_cursorPos - _targetPos[i]) / distance;
            _targetVelocity[i] += direction * 0.5;
          }
        }
      }
    });
  }
  
  void _updateParticles() {
    setState(() {
      _particles.removeWhere((p) => p.life <= 0);
      for (var particle in _particles) {
        particle.update();
      }
    });
  }
  
  void _addParticles(Offset position, Color color) {
    for (int i = 0; i < 10; i++) {
      _particles.add(Particle(
        position: position,
        velocity: Offset(
          (_rand.nextDouble() - 0.5) * 4,
          (_rand.nextDouble() - 0.5) * 4,
        ),
        color: color,
        life: 1.0,
      ));
    }
  }

  void _handleTapDown(TapDownDetails d) {
    for (int i = 0; i < _spawnCount && i < _targetPos.length && i < _targetSizes.length; i++) {
      final rect = Rect.fromLTWH(
        _targetPos[i].dx,
        _targetPos[i].dy,
        _targetSizes[i],
        _targetSizes[i],
      );
      if (rect.contains(d.localPosition)) {
        // Haptic feedback
        HapticFeedback.lightImpact();
        
        // Calculate score
        int baseScore = 1;
        if (i < _isLegendary.length && _isLegendary[i]) {
          baseScore = 5;
        } else if (i < _isPowerUp.length && _isPowerUp[i]) {
          _activatePowerUp();
          baseScore = 0; // Power-up gives no score but special effects
        }
        
        // Apply score multipliers and combo
        int finalScore = (baseScore * _scoreMultiplier * (1 + _combo * 0.1)).round();
        
        setState(() {
          _score += finalScore;
          _combo++;
          if (_combo > _maxCombo) _maxCombo = _combo;
          _checkEvolution();
          if (i < _hitFx.length) {
            _hitFx[i] = true;
          }
          
          // Add particle effects
          Color particleColor = Colors.cyan;
          if (i < _isLegendary.length && _isLegendary[i]) {
            particleColor = Colors.amber;
          } else if (i < _isPowerUp.length && _isPowerUp[i]) {
            particleColor = Colors.purple;
          }
          
          _addParticles(_targetPos[i] + Offset(_targetSizes[i] / 2, _targetSizes[i] / 2), particleColor);
          
          // Combo animation
          if (_combo % 5 == 0) {
            _comboController.forward().then((_) => _comboController.reverse());
          }
          
          _respawn(i);
        });
        
        // Reset combo timer
        Timer(const Duration(milliseconds: 1500), () {
          if (mounted) setState(() => _combo = 0);
        });
        
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && i < _hitFx.length) setState(() => _hitFx[i] = false);
        });
        break;
      }
    }
  }
  
  void _activatePowerUp() {
    final powerUp = PowerUpType.values[_rand.nextInt(PowerUpType.values.length)];
    setState(() {
      _powerUpDuration = 5;
      switch (powerUp) {
        case PowerUpType.timeFreeze:
          _timeFreeze = true;
          break;
        case PowerUpType.scoreMultiplier:
          _scoreMultiplier *= 2;
          break;
        case PowerUpType.rapidFire:
          _rapidFire = true;
          break;
        case PowerUpType.magnetism:
          _magnetism = true;
          break;
      }
    });
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

  void _deactivatePowerUps() {
    setState(() {
      _timeFreeze = false;
      _rapidFire = false;
      _magnetism = false;
      _scoreMultiplier = _currentWeather == WeatherType.rainy ? 1.5 : 1.0;
    });
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
              final maxX = constraints.maxWidth - (_targetSizes.isNotEmpty ? _targetSizes[0] : _targetSize);
              final maxY = constraints.maxHeight - (_targetSizes.isNotEmpty ? _targetSizes[0] : _targetSize) - 100;
              
              // Initialize positions for targets that need it
              for (int i = 0; i < _spawnCount && i < _targetPos.length; i++) {
                if (_targetPos[i] == Offset.zero ||
                    _targetPos[i].dx > maxX ||
                    _targetPos[i].dy > maxY) {
                  _targetPos[i] = Offset(
                    _rand.nextDouble() * maxX,
                    100 + _rand.nextDouble() * maxY,
                  );
                }
              }

              return AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_shakeAnimation.value, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _bg,
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Weather effect background
                          if (_currentWeather == WeatherType.snowy)
                            ...List.generate(20, (index) => 
                              Positioned(
                                left: _rand.nextDouble() * constraints.maxWidth,
                                top: _rand.nextDouble() * constraints.maxHeight,
                                child: const Icon(Icons.ac_unit, color: Colors.white70),
                              ),
                            ),
                          if (_currentWeather == WeatherType.rainy)
                            ...List.generate(30, (index) => 
                              Positioned(
                                left: _rand.nextDouble() * constraints.maxWidth,
                                top: _rand.nextDouble() * constraints.maxHeight,
                                child: Container(
                                  width: 2,
                                  height: 20,
                                  color: Colors.lightBlue.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          
                          // Status bar
                          Positioned(
                            top: 40,
                            left: 0,
                            right: 0,
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    Column(
                                      children: [
                                        Text(
                                          'Score: $_score',
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                                          ),
                                        ),
                                        if (_combo > 1)
                                          AnimatedBuilder(
                                            animation: _comboAnimation,
                                            builder: (context, child) {
                                              return Transform.scale(
                                                scale: _comboAnimation.value,
                                                child: Text(
                                                  'Combo: ${_combo}x',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.yellow[300],
                                                    shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                      ],
                                    ),
                                    Column(
                                      children: [
                                        Text(
                                          'Time: $_remaining',
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: _remaining <= 10 ? Colors.red[300] : Colors.white,
                                            shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
                                          ),
                                        ),
                                        Text(
                                          _getWeatherText(),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                // Power-up status
                                if (_powerUpDuration > 0)
                                  Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withValues(alpha: 0.8),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      '${_getActivePowerUpText()} ($_powerUpDuration s)',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          
                          // Pokemon targets
                          for (int i = 0; i < _spawnCount && i < _targetPos.length && i < _targetSizes.length && i < _targetIds.length; i++)
                            Positioned(
                              left: _targetPos[i].dx,
                              top: _targetPos[i].dy,
                              child: Transform.rotate(
                                angle: (i < _targetRotation.length ? _targetRotation[i] : 0) * 0.017453, // Convert to radians
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Special Pokemon auras
                                    if (i < _isLegendary.length && _isLegendary[i])
                                      Container(
                                        width: _targetSizes[i] + 20,
                                        height: _targetSizes[i] + 20,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.amber.withValues(alpha: 0.6),
                                              blurRadius: 15,
                                              spreadRadius: 5,
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (i < _isPowerUp.length && _isPowerUp[i])
                                      Container(
                                        width: _targetSizes[i] + 15,
                                        height: _targetSizes[i] + 15,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.purple.withValues(alpha: 0.6),
                                              blurRadius: 10,
                                              spreadRadius: 3,
                                            ),
                                          ],
                                        ),
                                      ),
                                    
                                    Image.network(
                                      spriteUrl(_targetIds[i]),
                                      width: _targetSizes[i],
                                      height: _targetSizes[i],
                                    ),
                                    
                                    if (i < _hitFx.length && _hitFx[i])
                                      SizedBox(
                                        width: _targetSizes[i] + 40,
                                        height: _targetSizes[i] + 40,
                                        child: Lottie.asset(
                                          'assets/party.json',
                                          repeat: false,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          
                          // Particle effects
                          ..._particles.map((particle) => Positioned(
                            left: particle.position.dx,
                            top: particle.position.dy,
                            child: Opacity(
                              opacity: particle.life,
                              child: Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: particle.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          )),
                          
                          // Evolution effect
                          if (_evoFx)
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Lottie.asset('assets/party.json', repeat: false),
                                  const Text(
                                    'EVOLUTION!',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(color: Colors.purple, blurRadius: 10),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          
                          // Custom cursor
                          Positioned(
                            left: _cursorPos.dx - 30,
                            top: _cursorPos.dy - 30,
                            child: Transform.scale(
                              scale: _magnetism ? 1.2 : 1.0,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (_magnetism)
                                    Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.blue.withValues(alpha: 0.6),
                                          width: 3,
                                        ),
                                      ),
                                    ),
                                  Image.network(
                                    spriteUrl(_chain[_stage]),
                                    width: 60,
                                    height: 60,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
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
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            const Text("Time's Up!"),
            const SizedBox(width: 8),
            Image.network(
              spriteUrl(_chain[_stage]),
              width: 30,
              height: 30,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Final Score: $_score',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text('Max Combo: ${_maxCombo}x'),
            Text('Evolution Stage: ${_stage + 1}/${_chain.length}'),
            Text('Final Form: ${kPokemonNames[_chain[_stage]] ?? 'Unknown'}'),
            if (_stage == _chain.length - 1)
              const Text(
                '🎉 Fully Evolved!',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Back to Selection'),
          ),
          ElevatedButton(
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
    _weatherTimer?.cancel();
    _moveTimer?.cancel();
    _powerUpTimer?.cancel();
    _particleTimer?.cancel();
    _shakeController.dispose();
    _comboController.dispose();
    super.dispose();
  }

  String _getWeatherText() {
    switch (_currentWeather) {
      case WeatherType.sunny:
        return '☀️ Sunny';
      case WeatherType.rainy:
        return '🌧️ Rainy (+50% Score)';
      case WeatherType.snowy:
        return '❄️ Snowy (Slow Motion)';
      case WeatherType.stormy:
        return '⛈️ Stormy (Screen Shake)';
    }
  }
  
  String _getActivePowerUpText() {
    if (_timeFreeze) return '⏸️ Time Freeze';
    if (_rapidFire) return '⚡ Rapid Fire';
    if (_magnetism) return '🧲 Magnetism';
    if (_scoreMultiplier > 1.5) return '✨ Score Boost';
    return 'Power-Up Active';
  }
}
