import 'package:mambo/theme/app_theme.dart';
import 'package:mambo/theme/tokens.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:gal/gal.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../services/log_service.dart';
import '../../../services/scrapbook_quota_service.dart';
import '../../../widgets/botanical.dart';
import '../../../widgets/fresh_surface.dart';
import 'log_map.dart';
import 'log_review_page.dart';
import 'widgets/review_parts.dart';

class LogReviewResultPage extends StatefulWidget {
  const LogReviewResultPage({super.key, required this.result});

  final LogReviewResult result;

  @override
  State<LogReviewResultPage> createState() => _LogReviewResultPageState();
}

class _LogReviewResultPageState extends State<LogReviewResultPage> {
  String? _scrapbookImageUrl;
  bool _isGenerating = false;
  String? _scrapbookError;

  @override
  void initState() {
    super.initState();
    // Show existing scrapbook image from log if already generated
    final firstLog = widget.result.logs.isNotEmpty ? widget.result.logs.first : null;
    _scrapbookImageUrl = firstLog?.scrapbookImageUrl;
  }

  String get _displayLogTitle {
    final logs = widget.result.logs;
    if (logs.isEmpty) return widget.result.logTitle;
    final date = logs.first.createdAt.toLocal();
    return DateFormat('yyyy年M月d日 EEEE', 'zh_CN').format(date);
  }

  Future<void> _onTapScrapbookPlaceholder() async {
    final canGen = await ScrapbookQuotaService.canGenerate();
    if (!canGen) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('今日生成次数已用完，明天再来吧'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    final logId = widget.result.logs.isNotEmpty ? widget.result.logs.first.id : null;
    if (logId == null) return;

    setState(() {
      _isGenerating = true;
      _scrapbookError = null;
    });

    try {
      final url = await LogService().generateScrapbookImage(logId);
      if (mounted) {
        if (url != null) {
          await ScrapbookQuotaService.recordGeneration();
          setState(() {
            _scrapbookImageUrl = url;
            _isGenerating = false;
          });
        } else {
          setState(() {
            _scrapbookError = '生成失败，请稍后重试';
            _isGenerating = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_scrapbookError!)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _scrapbookError = e.toString();
          _isGenerating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成失败：${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final entries = result.allEntries;
    final text = context.text;

    return Scaffold(
      appBar: AppBar(
        title: const Text('回顾完成'),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: '返回',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: PaperBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(FreshSpace.page + 8, FreshSpace.lg, FreshSpace.page, FreshSpace.xxl),
          children: [
            FreshHeading(_displayLogTitle, botanical: BotanicalKind.blossom),
            const SizedBox(height: FreshSpace.xxl),
            _buildScrapbookSection(),
            const SizedBox(height: FreshSpace.xxl),
            ReviewSection(title: '智能总结', answer: result.logSummary),
            if (logPositions(result.logs, entries).isNotEmpty)
              ReviewSection(title: '足迹地图', child: LogMap(logs: result.logs, entries: entries)),
            ReviewSection(title: '今日回顾', question: result.overallQuestion, answer: result.overallAnswer),
            ReviewSection(
              title: '念念不忘的瞬间',
              child: Column(
                children: [
                  for (final entry in entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: FreshSpace.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Thumbnail(entry.imageUrl, size: 72),
                          const SizedBox(width: FreshSpace.md),
                          Expanded(
                            child: Text(
                              entry.description?.isNotEmpty == true ? entry.description! : '—',
                              style: text.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            ReviewSection(title: '值得留意的一刻', question: result.followUpQuestion, answer: result.followUpAnswer),
            ReviewSection(title: '照片中的共鸣', question: result.imageTagQuestion, answer: result.imageTagAnswer),
            ReviewSection(
              title: '心中余韵',
              child: FreshCard(
                padding: const EdgeInsets.all(FreshSpace.lg),
                child: Text(
                  result.finalSummary.isEmpty ? '—' : result.finalSummary,
                  style: text.bodyLarge!.copyWith(height: 1.9),
                ),
              ),
            ),
            const SizedBox(height: FreshSpace.lg),
            ElevatedButton(
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text('返回首页'),
            ),
          ],
        ),
      ),
    );
  }

  void _showScrapbookFullScreen(String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => _ScrapbookFullScreenView(imageUrl: imageUrl),
      ),
    );
  }

  Widget _buildScrapbookSection() {
    final text = context.text;
    final url = _scrapbookImageUrl;
    final Widget content;
    if (_isGenerating) {
      content = SizedBox(
        height: 220,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Botanical(kind: BotanicalKind.bamboo, size: 56),
            const SizedBox(height: FreshSpace.lg),
            const SizedBox(width: 96, child: LinearProgressIndicator(minHeight: 1.5)),
            const SizedBox(height: FreshSpace.md),
            Text('正在生成…', style: text.bodySmall),
          ],
        ),
      );
    } else if (url != null) {
      content = Image.network(
        url,
        fit: BoxFit.contain,
        width: double.infinity,
        errorBuilder: (_, _, _) => _buildPlaceholderContent(),
      );
    } else {
      content = SizedBox(height: 220, child: _buildPlaceholderContent());
    }

    return ReviewSection(
      title: '今日手账封面',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FreshCard(
            padding: EdgeInsets.zero,
            onTap:
                _isGenerating
                    ? null
                    : url != null
                    ? () => _showScrapbookFullScreen(url)
                    : _onTapScrapbookPlaceholder,
            child: ClipRRect(
              borderRadius: FreshRadius.card,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: AnimatedSwitcher(duration: FreshMotion.of(context), child: content),
              ),
            ),
          ),
          if (url != null && !_isGenerating)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _onTapScrapbookPlaceholder,
                icon: const Icon(Icons.autorenew, size: 18),
                label: const Text('重新生成'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.auto_awesome_outlined, size: 32, color: FreshColors.inkSoft),
          const SizedBox(height: FreshSpace.md),
          Text('轻触生成今日手账封面', style: context.text.bodyMedium, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ScrapbookFullScreenView extends StatefulWidget {
  const _ScrapbookFullScreenView({required this.imageUrl});

  final String imageUrl;

  @override
  State<_ScrapbookFullScreenView> createState() => _ScrapbookFullScreenViewState();
}

class _ScrapbookFullScreenViewState extends State<_ScrapbookFullScreenView> {
  bool _isSaving = false;
  bool _isSharing = false;

  /// The cover's bytes, or null after telling the user it could not be
  /// downloaded.
  Future<Uint8List?> _fetchImageBytes() async {
    try {
      final response = await http.get(Uri.parse(widget.imageUrl)).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) return Uint8List.fromList(response.bodyBytes);
    } on TimeoutException {
      // Reported below.
    } catch (e) {
      debugPrint('Downloading the cover failed: $e');
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('封面下载失败，请检查网络后重试')));
    }
    return null;
  }

  Future<void> _saveToGallery() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final bytes = await _fetchImageBytes();
      if (bytes == null || !mounted) return;
      await Gal.putImageBytes(
        bytes,
        name: 'scrapbook_cover_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已保存到相册')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _shareImage() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final bytes = await _fetchImageBytes();
      if (bytes == null || !mounted) return;
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/scrapbook_share_${DateTime.now().millisecondsSinceEpoch}.png');
      await tempFile.writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(tempFile.path)], text: '来自 Mambo 漫步的今日手账'),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget busy(bool on, IconData icon) =>
        on ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 1.2)) : Icon(icon);
    return Scaffold(
      backgroundColor: FreshColors.riceWhite,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: '关闭',
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: busy(_isSaving, Icons.save_alt),
            onPressed: _isSaving ? null : _saveToGallery,
            tooltip: '保存到相册',
          ),
          IconButton(
            icon: busy(_isSharing, Icons.ios_share),
            onPressed: _isSharing ? null : _shareImage,
            tooltip: '分享',
          ),
          const SizedBox(width: FreshSpace.sm),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(FreshSpace.md),
          child: Center(
            child: InteractiveViewer(
              child: ClipRRect(
                borderRadius: FreshRadius.button,
                child: Image.network(
                  widget.imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder:
                      (context, child, progress) =>
                          progress == null ? child : const CircularProgressIndicator(strokeWidth: 1.2),
                  errorBuilder:
                      (context, error, stackTrace) =>
                          const Icon(Icons.image_not_supported_outlined, size: 40, color: FreshColors.inkSoft),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
