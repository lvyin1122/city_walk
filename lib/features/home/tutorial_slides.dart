import 'package:flutter/material.dart';

class TutorialSlides extends StatefulWidget {
  final VoidCallback? onFinish;
  const TutorialSlides({Key? key, this.onFinish}) : super(key: key);

  @override
  State<TutorialSlides> createState() => _TutorialSlidesState();
}

class _TutorialSlidesState extends State<TutorialSlides> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<String> _dummyTexts = [
    'Welcome to CityWalk!\n\nDiscover the city with personalized walks.',
    'Choose your interests and let us plan your route.',
    'Track your walks and revisit your favorite spots!',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: 3,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                return Center(
                  child: Transform.scale(
                    scale: 1.0,
                    child: Image.asset(
                      'assets/images/Tutorial_EN_0${index + 1}.png',
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                );
              },
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) => _buildDot(index)),
              ),
            ),
            Positioned(
              right: 24,
              bottom: 24,
              child:
                  _currentPage == 2
                      ? ElevatedButton(
                        onPressed: () {
                          if (widget.onFinish != null)
                            widget.onFinish!();
                          else
                            Navigator.of(context).pop();
                        },
                        child: Text('开始使用'),
                      )
                      : TextButton(
                        onPressed: () {
                          _controller.nextPage(
                            duration: Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: Text('下一步'),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      margin: EdgeInsets.symmetric(horizontal: 6),
      width: _currentPage == index ? 16 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: _currentPage == index ? Colors.blueAccent : Colors.grey[400],
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
