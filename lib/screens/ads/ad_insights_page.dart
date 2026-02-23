import 'package:flutter/material.dart';

import '../../models/post.dart';

class AdInsightsPage extends StatelessWidget {
  final Post post;

  const AdInsightsPage({super.key, required this.post});

  bool get _isAdvert {
    final notes = (post.authenticityNotes ?? '').toLowerCase();
    if (notes.contains('advertisement:')) return true;
    final ad = post.aiMetadata?['advertisement'];
    if (ad is Map) {
      return ad['requires_payment'] == true ||
          (ad['confidence'] is num && (ad['confidence'] as num) >= 40);
    }
    return false;
  }

  Map<String, dynamic>? get _advertMeta {
    final ad = post.aiMetadata?['advertisement'];
    return ad is Map<String, dynamic> ? ad : (ad is Map ? ad.cast<String, dynamic>() : null);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ad = _advertMeta;
    final adType = (ad?['type'] as String?)?.replaceAll('_', ' ');
    final adConfidence = (ad?['confidence'] as num?)?.toDouble();
    final adAction = ad?['action'] as String?;

    return Scaffold(
      appBar: AppBar(title: const Text('Ad Insights')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.campaign, color: Color(0xFFFF8C00)),
                      const SizedBox(width: 8),
                      const Text(
                        'Advertisement',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(_isAdvert ? 'AD' : 'NOT AD'),
                        backgroundColor: _isAdvert
                            ? const Color(0xFFFF8C00).withValues(alpha: 0.12)
                            : colors.surfaceContainerHighest,
                        side: BorderSide(
                          color: _isAdvert
                              ? const Color(0xFFFF8C00)
                              : colors.outlineVariant,
                        ),
                      ),
                    ],
                  ),
                  if (post.title?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Text(
                      post.title!.trim(),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                  if (post.content.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      post.content,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _MetricGrid(
            items: [
              _MetricItem('Views', post.views.toString(), Icons.visibility_outlined),
              _MetricItem('Likes', post.likes.toString(), Icons.favorite_border),
              _MetricItem('Comments', post.comments.toString(), Icons.chat_bubble_outline),
              _MetricItem('Shares', post.shares.toString(), Icons.share_outlined),
              _MetricItem('Reposts', post.reposts.toString(), Icons.repeat),
              _MetricItem('Tips (ROO)', post.tips.toStringAsFixed(2), Icons.toll_outlined),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ad Detection Details',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  _kv('Type', adType ?? 'Unknown'),
                  _kv(
                    'Confidence',
                    adConfidence == null ? 'Unknown' : '${adConfidence.toStringAsFixed(1)}%',
                  ),
                  _kv('Action', adAction ?? 'Unknown'),
                  _kv('Status', post.status),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Click-Based Analytics',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Click/impression tracking is not yet stored for adverts in the current app schema. '
                    'This page shows live engagement metrics available now (views, likes, comments, shares, reposts, tips).',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(width: 96, child: Text(label)),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

class _MetricGrid extends StatelessWidget {
  final List<_MetricItem> items;

  const _MetricGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.2,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(item.icon),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.label, style: Theme.of(context).textTheme.bodySmall),
                      Text(
                        item.value,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MetricItem {
  final String label;
  final String value;
  final IconData icon;

  const _MetricItem(this.label, this.value, this.icon);
}
