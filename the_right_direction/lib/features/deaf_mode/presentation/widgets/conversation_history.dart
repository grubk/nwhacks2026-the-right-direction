import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/transcription.dart';

/// Scrollable conversation history with high contrast
class ConversationHistory extends StatefulWidget {
  final List<Transcription> history;
  final VoidCallback onClear;

  const ConversationHistory({
    super.key,
    required this.history,
    required this.onClear,
  });

  @override
  State<ConversationHistory> createState() => _ConversationHistoryState();
}

class _ConversationHistoryState extends State<ConversationHistory> {
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(ConversationHistory oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Auto-scroll to bottom when new items are added
    if (widget.history.length > oldWidget.history.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.history.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        // Header with clear button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                'Conversation History',
                style: AppTheme.labelLarge.copyWith(
                  color: Colors.white70,
                ),
              ),
              const Spacer(),
              Semantics(
                label: 'Clear conversation history',
                button: true,
                child: TextButton(
                  onPressed: widget.onClear,
                  child: Text(
                    'Clear',
                    style: AppTheme.labelLarge.copyWith(
                      color: AppTheme.deafModeAccent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // History list
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.history.length,
            itemBuilder: (context, index) {
              final transcription = widget.history[index];
              return _TranscriptionCard(
                transcription: transcription,
                index: index + 1,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Semantics(
      label: 'No conversation history yet',
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No conversation yet',
              style: AppTheme.bodyLarge.copyWith(
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Speech and signs will appear here',
              style: AppTheme.bodyMedium.copyWith(
                color: Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TranscriptionCard extends StatelessWidget {
  final Transcription transcription;
  final int index;

  const _TranscriptionCard({
    required this.transcription,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final isSignLanguage = transcription.source == TranscriptionSource.signLanguage;
    
    return Semantics(
      label: '${isSignLanguage ? "Sign" : "Speech"} $index: ${transcription.displayText}',
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSignLanguage
                ? Colors.purple.withOpacity(0.3)
                : Colors.blue.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Source and time
            Row(
              children: [
                Icon(
                  isSignLanguage ? Icons.sign_language : Icons.mic,
                  size: 16,
                  color: isSignLanguage ? Colors.purple : Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  isSignLanguage ? 'Sign' : 'Speech',
                  style: AppTheme.labelLarge.copyWith(
                    color: isSignLanguage ? Colors.purple : Colors.blue,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTime(transcription.timestamp),
                  style: AppTheme.labelLarge.copyWith(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Text
            Text(
              transcription.displayText,
              style: AppTheme.bodyLarge.copyWith(
                color: Colors.white,
              ),
            ),
            
            // Show original if enhanced
            if (transcription.enhancedText != null &&
                transcription.enhancedText != transcription.text) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_fix_high,
                      size: 14,
                      color: AppTheme.deafModeAccent.withOpacity(0.7),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Original: ${transcription.text}',
                        style: AppTheme.bodyMedium.copyWith(
                          color: Colors.white54,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
           '${time.minute.toString().padLeft(2, '0')}:'
           '${time.second.toString().padLeft(2, '0')}';
  }
}
