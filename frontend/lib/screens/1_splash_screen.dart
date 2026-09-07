import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _contentController;
  late AnimationController _glowController;

  late Animation<double> _logoOpacity;
  late Animation<double> _logoScale;

  late Animation<double> _contentOpacity;
  late Animation<Offset> _contentSlide;

  late Animation<double> _glowAnimation;

  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    // ==========================================================
    // LOGO ANIMATION
    // ==========================================================

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _logoOpacity = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOut,
    );

    _logoScale = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutCubic),
    );

    // ==========================================================
    // LEAF + CONTENT ANIMATION
    // ==========================================================

    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _contentOpacity = CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOut,
    );

    _contentSlide =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _contentController,
            curve: Curves.easeOutCubic,
          ),
        );

    // ==========================================================
    // SUBTLE GLOW
    // ==========================================================

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.025, end: 0.055).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _startSplash();
  }

  // ============================================================
  // SPLASH SEQUENCE
  // ============================================================

  Future<void> _startSplash() async {
    // Logo
    await _logoController.forward();

    await Future.delayed(const Duration(milliseconds: 200));

    if (!mounted) return;

    // Leaf + loading content
    await _contentController.forward();

    // ----------------------------------------------------------
    // Keep splash visible for a proper amount of time.
    //
    // Total screen time is approximately 6 seconds.
    // ----------------------------------------------------------

    await Future.delayed(const Duration(milliseconds: 3500));

    if (mounted && !_hasNavigated) {
      _navigateToFarmerLogin();
    }
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _navigateToFarmerLogin() {
    if (_hasNavigated) return;

    _hasNavigated = true;

    Navigator.pushReplacementNamed(context, '/farmer_auth');
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _logoController.dispose();
    _contentController.dispose();
    _glowController.dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FCF8),

      body: Container(
        width: double.infinity,
        height: double.infinity,

        // ======================================================
        // BACKGROUND
        // ======================================================
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFF7FCF8), Color(0xFFEAF6ED)],
            stops: [0.0, 0.55, 1.0],
          ),
        ),

        child: SafeArea(
          child: Stack(
            children: [
              // =================================================
              // LARGE SOFT GREEN GLOW
              // =================================================

              Positioned(
                top: screenHeight * 0.29,
                left: -40,
                right: -40,
                child: AnimatedBuilder(
                  animation: _glowAnimation,
                  builder: (context, child) {
                    return Container(
                      height: 360,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(
                          0xFF3A9B52,
                        ).withOpacity(_glowAnimation.value),
                      ),
                    );
                  },
                ),
              ),

              // =================================================
              // MAIN CONTENT
              // =================================================
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(
                    top: screenHeight * 0.12,
                    left: 20,
                    right: 20,
                  ),
                  child: Column(
                    children: [
                      // =========================================
                      // PRAVAN LOGO
                      // =========================================

                      FadeTransition(
                        opacity: _logoOpacity,
                        child: ScaleTransition(
                          scale: _logoScale,
                          child: Image.asset(
                            'assets/images/pravan_logo.png',
                            width: 345,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // =========================================
                      // LOTTIE LEAF
                      // =========================================
                      SlideTransition(
                        position: _contentSlide,
                        child: FadeTransition(
                          opacity: _contentOpacity,
                          child: Container(
                            width: 235,
                            height: 235,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF3A9B52,
                                  ).withOpacity(0.10),
                                  blurRadius: 55,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: Lottie.asset(
                              'assets/animations/pravan_leaf.json',

                              animate: true,
                              repeat: true,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // =========================================
                      // LOADING INDICATOR
                      // =========================================
                      FadeTransition(
                        opacity: _contentOpacity,
                        child: const SizedBox(
                          width: 42,
                          height: 42,
                          child: CircularProgressIndicator(
                            strokeWidth: 3.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF087F45),
                            ),
                            backgroundColor: Color(0xFFD9EEDC),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // =========================================
                      // LOADING MESSAGE
                      // =========================================
                      FadeTransition(
                        opacity: _contentOpacity,
                        child: const Text(
                          'Growing a Better Tomorrow...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                            color: Color(0xFF52705B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // =================================================
              // BOTTOM BRANDING
              // =================================================
              Positioned(
                left: 0,
                right: 0,
                bottom: 25,
                child: FadeTransition(
                  opacity: _contentOpacity,
                  child: const Text(
                    'Trusted • Field-First • Evidence-Based',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.7,
                      color: Color(0xFF91A99A),
                    ),
                  ),
                ),
              ),

              // =================================================
              // SOFT BOTTOM FIELD SHAPE
              // =================================================
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: SizedBox(
                    height: 70,
                    child: CustomPaint(painter: _BottomFieldPainter()),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// SUBTLE AGRICULTURAL FIELD AT BOTTOM
// ================================================================

class _BottomFieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    final path = Path();

    path.moveTo(0, height * 0.45);

    path.quadraticBezierTo(
      width * 0.18,
      height * 0.05,
      width * 0.38,
      height * 0.48,
    );

    path.quadraticBezierTo(
      width * 0.60,
      height * 0.92,
      width * 0.78,
      height * 0.40,
    );

    path.quadraticBezierTo(width * 0.90, height * 0.10, width, height * 0.35);

    path.lineTo(width, height);
    path.lineTo(0, height);
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFE0F0E2)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
