import 'package:flutter/material.dart';
import '../data/bottle_list.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'dart:math'; // for Random IDs
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';

//import 'package:chatview/chatview.dart'; // adjust if your chat package is different

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late PageController _controller;
  bool _isFocused = false;
  int? _focusedIndex;
  bool _wasJustUnfocused = false;
  bool _showMessages = false;
  final _focusNode = FocusNode();
  bool _showChatOverlay = false;
  final _chatFocusNode = FocusNode();

  final _chat = InMemoryChatController();
  final String RETRIEVE_URL = "https://rag-retrieve.gines-rodriguez-castro.workers.dev";
  final String OPENAI_API_KEY = "";

void _handleSend(String text) async {
  // insert user message in the chat
  _chat.insertMessage(TextMessage(
    id: '${Random().nextInt(1 << 31)}',
    authorId: 'user1',
    createdAt: DateTime.now().toUtc(),
    text: text,
  ));

  try {
    final routerResponse = await http.post(
  Uri.parse('https://api.openai.com/v1/chat/completions'),
  headers: {
    'content-type': 'application/json',
    'authorization': 'Bearer $OPENAI_API_KEY',
  },
  body: jsonEncode({
    'model': 'gpt-4o-mini',
    'messages': [
      {
        'role': 'system',
        'content':
            'You are a sommelier at a restaurant with an R2 database of 10 wines + 1 general chunk. '
            'You will decide if the user request needs R2 context (1) or not (0). '
            'Output exactly three lines: the number (1/0), the R2 prompt, and the final agent prompt.'
      },
      {'role': 'user', 'content': text}
    ],
    'temperature': 0,
  }),
);

final routerJson = jsonDecode(routerResponse.body);
final routerReply = routerJson['choices']?[0]?['message']?['content'] ?? '';
final lines = routerReply.trim().split('\n');
final useR2 = lines.isNotEmpty && lines.first.trim() == '1';
final r2Prompt = lines.length > 1 ? lines[1].trim() : '';
final agentPrompt = lines.length > 2 ? lines[2].trim() : '';

// 🟢 Add this status/debug message
//_chat.insertMessage(TextMessage(
//  id: '${Random().nextInt(1 << 31)}',
//  authorId: 'ai',
//  createdAt: DateTime.now().toUtc(),
//  text:
//      'Router decision: ${useR2 ? "1 (use R2)" : "0 (no R2)"}\nR2 query: $r2Prompt\nAgent query: $agentPrompt',
//));

    // --- 1️⃣ Send query to your Cloudflare retriever ---
    if (useR2){
    final retrieveResponse = await http.post(
      Uri.parse(RETRIEVE_URL),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'query': r2Prompt, 'top_k': 20}),
    );

    if (retrieveResponse.statusCode != 200) {
      throw Exception('Retriever error: ${retrieveResponse.body}');
    }

    final retrieveJson = jsonDecode(retrieveResponse.body);
    final context = retrieveJson['matches']?[0]?['text'] ?? '';

    // --- 2️⃣ Build prompt for OpenAI ---
    final prompt = agentPrompt + '''
Context:
$context
''';

    // --- 3️⃣ Ask OpenAI ---
    final openaiResponse = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $OPENAI_API_KEY',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini',
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.1,
      }),
    );

    if (openaiResponse.statusCode != 200) {
      throw Exception('OpenAI error: ${openaiResponse.body}');
    }

    final openaiJson = jsonDecode(openaiResponse.body);
    final reply = openaiJson['choices']?[0]?['message']?['content'] ?? '(no answer)';
     _chat.insertMessage(TextMessage(
      id: '${Random().nextInt(1 << 31)}',
      authorId: 'ai',
      createdAt: DateTime.now().toUtc(),
      text: reply,
    ));

    }else{
      final reply = agentPrompt;
     _chat.insertMessage(TextMessage(
      id: '${Random().nextInt(1 << 31)}',
      authorId: 'ai',
      createdAt: DateTime.now().toUtc(),
      text: reply,
    ));}
    // --- 4️⃣ Insert AI reply in the chat ---
   
  } catch (e) {
    // handle any error
    _chat.insertMessage(TextMessage(
      id: '${Random().nextInt(1 << 31)}',
      authorId: 'ai',
      createdAt: DateTime.now().toUtc(),
      text: 'Error: $e',
    ));
  }
}

void _handleSend_light(String text) async {
  _chat.insertMessage(TextMessage(
    id: '${Random().nextInt(1 << 31)}',
    authorId: 'user1',
    createdAt: DateTime.now().toUtc(),
    text: text,
  ));

  try {
    final prompt = '''
You are a world-class sommelier working at a fine-dining restaurant.
You may ONLY recommend or discuss wines from the following list — these are the **only wines available** in our cellar:

1. Château Margaux (Bordeaux, France)
An icon of elegance. Deep ruby color, aromas of violet, cassis, and subtle cedar. On the palate, layers of redcurrant, graphite, and tobacco harmonize with silky tannins. Best enjoyed with roast lamb or beef tenderloin. Decant for at least two hours to reveal its floral perfume and mineral finish.

2. Domaine de la Romanée-Conti (Burgundy, France)
A mythical Pinot Noir, ethereal yet powerful. Notes of wild strawberry, rose petals, and forest floor. The texture is satin-like, almost weightless, with an endless, perfumed aftertaste. Ideal with truffle dishes or delicate game birds.

3. Sassicaia (Tuscany, Italy)
The pioneer of the Super Tuscans. A Cabernet Sauvignon blend offering aromas of blackberry, Mediterranean herbs, and pencil shavings. Firm structure, fine acidity, and a persistent balsamic finish. Perfect alongside grilled steak or aged pecorino.

4. Opus One (Napa Valley, USA)
A collaboration between Mondavi and Rothschild. Opulent nose of ripe plum, black cherry, and mocha. The mouthfeel is plush, with polished tannins and balanced oak. Pair with veal, duck breast, or rich mushroom sauces.

5. Vega Sicilia Único (Ribera del Duero, Spain)
Tempranillo at its noblest. Aromas of dried fig, leather, cedar, and sweet spice. Palate shows mature fruit, velvety tannins, and extraordinary length. Magnificent with roasted lamb or Iberian ham.

6. Penfolds Grange (Australia)
A powerful Shiraz known for longevity. Dark chocolate, espresso, and blackcurrant dominate, supported by smoky oak. Intense and muscular, yet balanced by freshness. A perfect partner for barbecue meats or venison.

7. Château d’Yquem (Sauternes, France)
A liquid gold dessert wine with aromas of apricot, honey, saffron, and crème brûlée. Lusciously sweet but with a razor-sharp acidity. Superb with foie gras, blue cheese, or as a meditative drink on its own.

8. Domaine Leflaive Puligny-Montrachet (Burgundy, France)
A benchmark Chardonnay, crystalline and pure. Aromas of white peach, almond, and buttered brioche. On the palate, tension and minerality define its character. Pairs beautifully with scallops, lobster, or creamy risotto.

9. Château Cheval Blanc (Saint-Émilion, France)
Merlot and Cabernet Franc in poetic balance. Aromas of violets, plum, and cocoa. Silky texture with remarkable finesse and length. Complements dishes of duck confit or earthy mushroom ragouts.

10. Krug Grande Cuvée (Champagne, France)
The epitome of complexity in sparkling wine. Layers of hazelnut, brioche, citrus zest, and baked apple. Fine mousse, vibrant acidity, and an endlessly creamy finish. Ideal for celebrations or with oysters and caviar.

Answer the customer's question **only** using this wine list. 
Be elegant, concise, and accurate in your recommendation.

Customer's request:
$text
''';

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $OPENAI_API_KEY',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini',
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.4,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('OpenAI error: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final reply = data['choices']?[0]?['message']?['content'] ?? '(no answer)';

    _chat.insertMessage(TextMessage(
      id: '${Random().nextInt(1 << 31)}',
      authorId: 'ai',
      createdAt: DateTime.now().toUtc(),
      text: reply.trim(),
    ));
  } catch (e) {
    _chat.insertMessage(TextMessage(
      id: '${Random().nextInt(1 << 31)}',
      authorId: 'ai',
      createdAt: DateTime.now().toUtc(),
      text: 'Error: $e',
    ));
  }
}

  void _handleSend2(String text) {
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
                    setState(() => _wasJustUnfocused = true);
                    Future.delayed(const Duration(milliseconds: 500), () {
                      if (mounted) setState(() => _wasJustUnfocused = false);
                    });
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
    ..translate(-delta * 60.0 + xShift, offsetY)
    ..scale(baseScale * focusScale),

  child: Opacity(
    opacity: opacity,
    child: Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Bottle image


        // --- TEXT 1: right side ---
        AnimatedPositioned(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          top: 30, // near the neck
          left: _isFocused && index == _focusedIndex ? 120 : 0,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 400),
            opacity: _isFocused && index == _focusedIndex ? 1.0 : 0.0,
            child: Transform.translate(
              offset: Offset(
                _isFocused && index == _focusedIndex ? 0 : -10,
                120,
              ),
              child: SizedBox(
              width: 80, // <= forces wrapping
              child: Text(
                bottles[index].text1,
                style: GoogleFonts.playfairDisplay(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color.fromARGB(255, 0, 0, 0),
                height: 1.2,
              ),
              ),
              ),
            ),
          ),
        ),

        // --- TEXT 2: left side ---
        AnimatedPositioned(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          top: 30,
          right: _isFocused && index == _focusedIndex ? 120 : 0,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 400),
            opacity: _isFocused && index == _focusedIndex ? 1.0 : 0.0,
            child: Transform.translate(
              offset: Offset(
                _isFocused && index == _focusedIndex ? 0 : 10,
                320,
              ),
              child: SizedBox(
              width: 80, // <= forces wrapping
              child: Text(
                bottles[index].text2,
                style: GoogleFonts.playfairDisplay(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color.fromARGB(255, 0, 0, 0),
                height: 1.2,
              ),
              ),
              ),

            ),
          ),
        ),

Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child:Opacity(
              opacity: (_isFocused && index == _focusedIndex) || _wasJustUnfocused ? 1.0 : 0.0,
              child: Transform.translate(
                offset: const Offset(60, 120), // x, y shift
                child: SizedBox(
                  width: 120,
                  height: 40,
                  child: Container(color: const Color.fromARGB(255, 255, 255, 255)),
                ),
              ),
            ),
          ),
    ),

Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: Opacity(
              opacity: (_isFocused && index == _focusedIndex) || _wasJustUnfocused ? 1.0 : 0.0,
              child: Transform.translate(
                offset: const Offset(-60, -80), // x, y shift
                child: SizedBox(
                  width: 110,
                  height: 80,
                  child: Container(color: const Color.fromARGB(255, 255, 255, 255)),
                ),
              ),
            ),
          ),
        ),
        Image.asset(
          bottles[index].imagePath,
          fit: BoxFit.contain,
        ),


      ],
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
                                height: MediaQuery.of(context).size.height ,
                                child: AnimatedPadding(       // 👈 add “child:” here
                                      padding: EdgeInsets.only(
                                        bottom: MediaQuery.of(context).viewInsets.bottom == 0 ? 10 : 0,
                                      ),
                                      duration: const Duration(milliseconds: 150),
                                      curve: Curves.easeOut,
                                child: Chat(
                                  chatController: _chat,
                                  currentUserId: 'user1',
                                  onMessageSend: _handleSend_light,
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
