import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/app_confirmation_dialog.dart';

class OnboardingScreen extends StatefulWidget {
  final Widget nextScreen;

  const OnboardingScreen({super.key, required this.nextScreen});

  static Future<void> checkAndNavigate(BuildContext context, Widget nextScreen) async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('hasSeenOnboarding') ?? false;

    if (!context.mounted) return;

    if (hasSeen) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => nextScreen),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => OnboardingScreen(nextScreen: nextScreen)),
      );
    }
  }

  static Future<void> checkAndRemoveUntil(BuildContext context, Widget nextScreen) async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('hasSeenOnboarding') ?? false;

    if (!context.mounted) return;

    if (hasSeen) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => nextScreen),
        (route) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => OnboardingScreen(nextScreen: nextScreen)),
        (route) => false,
      );
    }
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingSlide> _slides = [
    OnboardingSlide(
      icon: PhosphorIconsFill.magnifyingGlass,
      title: 'Welcome to FoundIT',
      description:
          'A smart way to manage and recover your lost items securely within the community using the power of AI.',
      color: Colors.indigo,
    ),
    OnboardingSlide(
      icon: PhosphorIconsFill.cameraPlus,
      title: 'Report Items Easily',
      description:
          'Quickly report what you lost or found. Add a clear picture and precise details to boost your chances of a match.',
      color: Colors.orange,
    ),
    OnboardingSlide(
      icon: PhosphorIconsFill.brain,
      title: 'AI-Powered Matching',
      description:
          'Our AI system cross-references deep visual queues and textual descriptions to automatically match lost & found reports!',
      color: Colors.teal,
    ),
    OnboardingSlide(
      icon: PhosphorIconsFill.chatCircleText,
      title: 'Secure Claiming',
      description:
          'Connect safely through built-in chat. Verify ownership with confidence and arrange meetups to retrieve belongings.',
      color: Colors.blue,
    ),
    OnboardingSlide(
      icon: PhosphorIconsFill.checkCircle,
      title: 'Ready to Start?',
      description:
          'Join the community now and help make the campus a better place for everyone!',
      color: Colors.green,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _onPrevious() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 1200), // Slightly longer to be obvious
        reverseTransitionDuration: const Duration(milliseconds: 1200),
        pageBuilder: (context, animation, secondaryAnimation) => widget.nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // A premium compound transition: Fade + Slide Up + Scale Up
          var curve = Curves.fastLinearToSlowEaseIn; // A more dramatic curve

          var slideAnimation = Tween<Offset>(
            begin: const Offset(0.0, 0.4), // Start much lower
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: curve));

          var scaleAnimation = Tween<double>(
            begin: 0.8, // Start smaller
            end: 1.0,
          ).animate(CurvedAnimation(parent: animation, curve: curve));

          var fadeAnimation = Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(CurvedAnimation(parent: animation, curve: curve));

          return FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(
              position: slideAnimation,
              child: ScaleTransition(
                scale: scaleAnimation,
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // Top Right Skip Button
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: () async {
                    final confirm = await showAppConfirmationDialog<bool>(
                      context: context,
                      title: 'Skip Introduction?',
                      message: 'Are you sure you want to skip the introduction and go straight to the app?',
                      confirmText: 'Skip',
                      cancelText: 'Cancel',
                    );
                    if (confirm == true) {
                      _finishOnboarding();
                    }
                  },
                  child: const Text('Skip', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ),
              ),

              // Swipable Pages
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: _slides.length,
                  itemBuilder: (context, index) {
                    return AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, child) {
                        double pageOffset = 0;
                        if (_pageController.position.haveDimensions) {
                          pageOffset = _pageController.page! - index;
                        } else {
                          pageOffset = _currentPage - index.toDouble();
                        }
                        
                        double opacity = (1 - pageOffset.abs()).clamp(0.0, 1.0);
                        double scale = 0.8 + (0.2 * opacity);
                        
                        return Opacity(
                          opacity: opacity,
                          child: Transform.scale(
                            scale: scale,
                            child: child,
                          ),
                        );
                      },
                      child: _AnimatedSlideContent(slide: _slides[index]),
                    );
                  },
                ),
              ),

              // Bottom Navigation & Controls
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Previous Button or empty space
                    _currentPage > 0
                        ? TextButton(
                            onPressed: _onPrevious,
                            child: const Text(
                              'Back',
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          )
                        : const SizedBox(width: 64),

                    // Dot Indicators
                    Row(
                      children: List.generate(
                        _slides.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: _currentPage == index ? 24 : 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? const Color(0xFF413F55)
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),

                    // Next / Get Started Button
                    _currentPage == _slides.length - 1
                        ? ElevatedButton(
                            onPressed: _onNext,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF413F55),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Start'),
                          )
                        : IconButton(
                            onPressed: _onNext,
                            icon: const Icon(PhosphorIconsBold.caretRight),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF413F55),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(12),
                            ),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingSlide {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  OnboardingSlide({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}

class _AnimatedSlideContent extends StatefulWidget {
  final OnboardingSlide slide;
  const _AnimatedSlideContent({required this.slide});

  @override
  State<_AnimatedSlideContent> createState() => _AnimatedSlideContentState();
}

class _AnimatedSlideContentState extends State<_AnimatedSlideContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2500))
      ..repeat(reverse: true);
      
    _floatAnimation = Tween<double>(begin: -15, end: 15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _floatAnimation.value),
                child: Transform.scale(
                  scale: _pulseAnimation.value,
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: widget.slide.color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(widget.slide.icon, size: 80, color: widget.slide.color),
            ),
          ),
          const SizedBox(height: 48),
          Text(
            widget.slide.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF262532),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.slide.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black54,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
