import 'package:flutter/material.dart';

class StaticWalkSummaryPage extends StatelessWidget {
  const StaticWalkSummaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Text(
                  'Walk Summary',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tuesday, Mar 31, 2026, 2:30 PM',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Shanghai, Jing An District',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      children: const [
                        _StaticStatRow(
                          icon: Icons.place,
                          color: Colors.blue,
                          label: 'Locations',
                          value: '3/5',
                        ),
                        Divider(),
                        _StaticStatRow(
                          icon: Icons.task_alt,
                          color: Colors.green,
                          label: 'Tasks',
                          value: '4',
                        ),
                        Divider(),
                        _StaticStatRow(
                          icon: Icons.timer,
                          color: Colors.purple,
                          label: 'Duration',
                          value: '01:12:00',
                        ),
                        Divider(),
                        _StaticStatRow(
                          icon: Icons.directions_walk,
                          color: Colors.orange,
                          label: 'Distance',
                          value: '4.8 km',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 300,
                    width: double.infinity,
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: const Text('Map Preview'),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 600),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.format_quote,
                              color: Theme.of(context).primaryColor,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Your Walk Story',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: constraints.maxWidth,
                              ),
                              child: Text(
                                '🎯 A soulful, sensory-rich journey through Sheung Wan’s hidden corners, where history, art, and local life unfold in every step.  \n📍 Visited: Man Mo Temple – a serene spiritual haven with intricate carvings; PMQ – a vibrant creative hub bursting with design and culture; Hollywood Road Park – a lush oasis of greenery and quiet romance nestled in the city’s heart.  \n⭐ Notable highlights: The tranquil beauty of Hollywood Road Park, the spiritual stillness of Man Mo Temple, and the dynamic energy of PMQ’s artistic pulse made this walk truly unforgettable.  \n📝 Task observations: Captured timeless moments—the old shop signs whispering stories, street artists’ vivid murals, fishermen at ease by the harbor, and the joyful chaos of wet markets—all revealing Sheung Wan’s living soul in rich detail.  \n🌟 You’ve walked with wonder and purpose—every photo, every step, a testament to your curiosity and love for Hong Kong’s authentic heartbeat. Keep exploring, you’re doing something beautiful.',
                                style: Theme.of(context).textTheme.bodyMedium,
                                softWrap: true,
                                overflow: TextOverflow.visible,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Favorite Moments 💖',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 8),
                const _ImageGridPlaceholder(itemCount: 4),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Task Photos 📝',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 8),
                const _ImageGridPlaceholder(itemCount: 8),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/', (route) => false);
                    },
                    child: const Text(
                      'Back to Home',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StaticStatRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _StaticStatRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _ImageGridPlaceholder extends StatelessWidget {
  final int itemCount;

  const _ImageGridPlaceholder({required this.itemCount});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Container(
          color: Colors.grey.shade300,
          child: const Icon(Icons.image_outlined, color: Colors.white70),
        );
      },
    );
  }
}
