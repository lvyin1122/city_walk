import 'package:flutter/material.dart';
import 'package:mambo/features/home/post_auth_choice_page.dart';
import 'package:mambo/theme/app_colors.dart';

/// Dummy reflection questions for the walk review flow.
const List<String> _reflectionQuestions = [
  'What did you notice during your walk?',
  'How did you feel while walking?',
  'Was there anything surprising or memorable?',
  'What would you do differently next time?',
];

/// A single reflection section with question and answer.
class ReflectionSection {
  const ReflectionSection({required this.question, required this.answer});

  final String question;
  final String answer;
}

class WalkReviewPage extends StatefulWidget {
  const WalkReviewPage({super.key});

  @override
  State<WalkReviewPage> createState() => _WalkReviewPageState();
}

class _WalkReviewPageState extends State<WalkReviewPage> {
  final List<ReflectionSection> _reflections = [];

  Future<void> _showReflectionSheet(BuildContext context) async {
    final result = await showModalBottomSheet<List<ReflectionSection>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ReflectionQuestionsSheet(
        questions: _reflectionQuestions,
      ),
    );
    if (result != null && result.isNotEmpty && mounted) {
      setState(() => _reflections.addAll(result));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review'),
      ),
      body: _reflections.isEmpty
          ? Center(
              child: Text(
                'No reflections yet.\nTap + to add one.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: _reflections.map((section) => _buildReflectionCard(section)).toList(),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const PostAuthChoicePage(),
                    ),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.check, size: 20),
                label: const Text('Finish Review'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 50),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _showReflectionSheet(context),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add Review'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 50),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  foregroundColor: AppColors.buttonTextColor,
                  backgroundColor: AppColors.primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReflectionCard(ReflectionSection section) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            section.question,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryColor,
                ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              section.answer,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReflectionQuestionsSheet extends StatefulWidget {
  const _ReflectionQuestionsSheet({required this.questions});

  final List<String> questions;

  @override
  State<_ReflectionQuestionsSheet> createState() =>
      _ReflectionQuestionsSheetState();
}

class _ReflectionQuestionsSheetState extends State<_ReflectionQuestionsSheet> {
  final PageController _pageController = PageController();
  final Map<int, TextEditingController> _answerControllers = {};
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.questions.length; i++) {
      _answerControllers[i] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _answerControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _goToNext() {
    if (_currentIndex < widget.questions.length - 1) {
      setState(() => _currentIndex++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      final sections = <ReflectionSection>[];
      for (int i = 0; i < widget.questions.length; i++) {
        final answer = _answerControllers[i]!.text.trim();
        if (answer.isNotEmpty) {
          sections.add(ReflectionSection(
            question: widget.questions[i],
            answer: answer,
          ));
        }
      }
      Navigator.pop(context, sections);
    }
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.questions;
    final isFirst = _currentIndex == 0;
    final isLast = _currentIndex == questions.length - 1;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Add Reflection',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              'Question ${_currentIndex + 1} of ${questions.length}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 280,
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: questions.length,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          questions[index],
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: TextField(
                            controller: _answerControllers[index],
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            decoration: InputDecoration(
                              hintText: 'Write your reflection...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isFirst
                          ? () => Navigator.pop(context)
                          : _goToPrevious,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isFirst ? Icons.close : Icons.arrow_back,
                            size: 20,
                          ),
                          SizedBox(width: 2),
                          Text(isFirst ? 'Close' : 'Back'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _goToNext,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        foregroundColor: AppColors.buttonTextColor,
                        backgroundColor: AppColors.primaryColor,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(isLast ? 'Done' : 'Next'),
                          if (!isLast) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward, size: 20),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
