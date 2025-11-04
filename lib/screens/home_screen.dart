import 'package:flutter/material.dart';
import '../data/bottle_list.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'dart:math'; // for Random IDs


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late PageController _controller;
  bool _isFocused = false;
  int? _focusedIndex;
  bool _showMessages = false;
  final _focusNode = FocusNode();
  bool _showChatOverlay = false;
  final _chatFocusNode = FocusNode();

  final _chat = InMemoryChatController();

  void _handleSend(String text) {
    _chat.insertMessage(TextMessage(
      id: '${Random().nextInt(1 << 31)}',
      authorId: 'user1',
      createdAt: DateTime.now().toUtc(),
      text: text,
    ));

    Future.delayed(const Duration(milliseconds: 500), () {
      _chat.insertMessage(TextMessage(
        id: '${Random().nextInt(1 << 31)}',
        authorId: 'ai',
        createdAt: DateTime.now().toUtc(),
        text: 'You are the best!',
      ));
    });
  }

  @override
  void dispose() {
    _chatFocusNode.dispose();
    _chat.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) setState(() => _showMessages = true);
    });
    _controller = PageController(
      viewportFraction: 0.45, // controls how many bottles fit horizontally
      initialPage: bottles.length , //* (loopCount ~/ 2), // start in middle,
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255), // soft wine tone
      body: Stack(
          children: [
            Column(
                    children: [
                                  // --- Top logo ---
                        Padding(
                          padding: const EdgeInsets.only(top: 50.0, bottom: 10.0),
                          child: Center(
                            child: Image.asset(
                              'assets/images/logo/logo.png',
                              height: 80,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),

GestureDetector(
  onTap: () {
    if (_isFocused) {
      setState(() {
        _isFocused = false;
        _focusedIndex = null;
      });
    }
  },
                        // --- PageView Carousel section ---
                        child: Container(
  height: 500,
  alignment: Alignment.topCenter,
  margin: const EdgeInsets.only(top: 0),
  child: PageView.builder(
    controller: _controller,
    itemCount: bottles.length,
    physics: _isFocused
        ? const NeverScrollableScrollPhysics()
        : const BouncingScrollPhysics(),
    itemBuilder: (context, index) {

      return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return GestureDetector(
            onTap: () {
              final currentPage = _controller.page?.round() ?? 0;
              setState(() {
                if (_isFocused && index == _focusedIndex) {
                  _isFocused = false;
                  _focusedIndex = null;
                } else if (!_isFocused && index == currentPage) {
                  _isFocused = true;
                  _focusedIndex = index ;
                }
              });
            },
            child: TweenAnimationBuilder<double>(
  duration: const Duration(milliseconds: 500),
  curve: Curves.easeInOut,
  tween: Tween<double>(
    begin: 1.0,
    end: (_isFocused && index == _focusedIndex) ? 1.15 : 1.0,
  ),
  builder: (context, focusScale, child) {
    final page = _controller.hasClients
        ? (_controller.page ?? _controller.initialPage.toDouble())
        : _controller.initialPage.toDouble();
    final delta = index - page;
    final distance = delta.abs().clamp(0.0, 1.0);

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      tween: Tween<double>(
         begin: 0,
        end: !_isFocused
            ? 0.0
            : (index == _focusedIndex ? 0.0 : (delta > 0 ? 90.0 : -90.0)),
      ),
      builder: (context, xShift, child) {
        double baseScale = 1.0 - 0.4 * distance;
        double opacity = 1.0 - 0.6 * distance;
        double offsetY = delta * delta * 60.0 ;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..translate(  -delta * 60.0 + xShift, offsetY)
            ..scale(baseScale * focusScale),
          child: Opacity(
            opacity: opacity,
            child: Image.asset(
              bottles[index].imagePath,
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  },
),


          );

        },
      );
    },
  ),
),
),
                      const SizedBox(height: 12),
                      composerBar(), // <- only text field + send button
                    ],
                  ),

                  // --- Chat overlay ---
                  if (_showChatOverlay)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () async {
                          FocusScope.of(context).unfocus();                 // hide keyboard
                          await Future.delayed(const Duration(milliseconds: 200)); // let it finish
                          if (mounted) setState(() => _showChatOverlay = false);   // then close chat
                        },
                        child: Container(
                          color: Colors.transparent, // semi-transparent background
                          child: SafeArea(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: SizedBox(
                                height: MediaQuery.of(context).size.height * 0.6 - 200,
                                child: AnimatedPadding(       // 👈 add “child:” here
                                      padding: EdgeInsets.only(
                                        bottom: MediaQuery.of(context).viewInsets.bottom == 0 ? 10 : 0,
                                      ),
                                      duration: const Duration(milliseconds: 150),
                                      curve: Curves.easeOut,
                                child: Chat(
                                  chatController: _chat,
                                  currentUserId: 'user1',
                                  onMessageSend: _handleSend,
                                  resolveUser: (id) async => User(
                                    id: id,
                                    name: id == 'user1' ? 'You' : 'AI',
                                  ),
                                    builders: Builders(
                                    composerBuilder: (context) => Composer(
                                      focusNode: _chatFocusNode,                 // 👈 key line
                                    ),
                                  ),
                                  theme: ChatTheme(
                                    colors: ChatColors.light().copyWith(
                                      surface: Colors.white.withOpacity(0.80),            // chat window bg
                                      surfaceContainer: Colors.white.withOpacity(0.72),   // bubbles/tiles bg
                                      surfaceContainerLow: Colors.white.withOpacity(0.64),
                                      surfaceContainerHigh: Colors.white.withOpacity(0.88),
                                    ),
                                    typography: ChatTypography.standard(),
                                    shape: const BorderRadius.all(Radius.circular(16)),
                                  )
                                ),
                              ),
                            ),
                            ),
                          ),
                        ),
                      ),
                    ),



                  ],
        

      ),
    );
  }

  Widget composerBar() {
  return Padding(
    padding: const EdgeInsets.only(bottom: 20.0), // move it lower
    child: Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9, // slightly narrower
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30), // rounded corners
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                readOnly: true,
                onTap: () {
                  setState(() => _showChatOverlay = true);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    FocusScope.of(context).requestFocus(_chatFocusNode); // pops keyboard
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  border: InputBorder.none,
                ),
              ),
            ),
            const Icon(Icons.send, color: Colors.grey),
          ],
        ),
      ),
    ),
  );
}




}
