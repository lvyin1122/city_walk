import 'package:flutter/material.dart';

class TutorialSlides extends StatefulWidget {
  final VoidCallback? onFinish;
  const TutorialSlides({super.key, this.onFinish});

  @override
  State<TutorialSlides> createState() => _TutorialSlidesState();
}

class _TutorialSlidesState extends State<TutorialSlides> {
  static const int _pageCount = 3;

  final PageController _controller = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    if (widget.onFinish != null) {
      widget.onFinish!();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _pageCount - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: _pageCount,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                return Center(
                  child: Image.asset(
                    'assets/images/Tutorial_EN_0${index + 1}.png',
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                );
              },
            ),
            if (!isLastPage)
              Positioned(
                top: 8,
                right: 16,
                child: TextButton(onPressed: _finish, child: const Text('跳过')),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pageCount, (index) => _buildDot(index)),
              ),
            ),
            Positioned(
              right: 24,
              bottom: 24,
              child:
                  isLastPage
                      ? ElevatedButton(
                        onPressed: _finish,
                        child: const Text('开始使用'),
                      )
                      : TextButton(
                        onPressed: () {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: const Text('下一步'),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 6),
      width: _currentPage == index ? 16 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: _currentPage == index ? Colors.blueAccent : Colors.grey[400],
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
