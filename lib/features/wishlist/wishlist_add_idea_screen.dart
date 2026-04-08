import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/app_db.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../social/social_state.dart';
import 'widgets/wishlist_editor_shell.dart';

class WishlistAddIdeaScreen extends ConsumerStatefulWidget {
  const WishlistAddIdeaScreen({super.key});

  @override
  ConsumerState<WishlistAddIdeaScreen> createState() =>
      _WishlistAddIdeaScreenState();
}

class _WishlistAddIdeaScreenState extends ConsumerState<WishlistAddIdeaScreen> {
  final TextEditingController _titleController = TextEditingController();
  bool _isSaving = false;
  String? _errorText;

  bool get _canContinue =>
      _titleController.text.trim().isNotEmpty && !_isSaving;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: wishlistEditorInputDecorationTheme(context),
      ),
      child: WishlistEditorShell(
        title: 'Add Idea',
        onBack: () => context.pop(),
        hideBottomDockWhenKeyboardVisible: true,
        bottomDock: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            WishlistEditorDockButton(
              label: 'Plan with AI',
              icon: Icons.auto_awesome_outlined,
              isLoading: _isSaving,
              onTap: _canContinue
                  ? () => _createIdea(openManualEditor: false)
                  : null,
            ),
            const SizedBox(height: 12),
            WishlistEditorDockButton(
              label: 'Plan manually',
              icon: Icons.edit_note_outlined,
              highlighted: false,
              onTap: _canContinue
                  ? () => _createIdea(openManualEditor: true)
                  : null,
            ),
          ],
        ),
        body: ListView(
          physics: const BouncingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            16,
            wishlistEditorTopOverlayClearanceOf(context),
            16,
            wishlistEditorBottomDockClearance + 48,
          ),
          children: <Widget>[
              ListenableBuilder(
                listenable: _titleController,
                builder: (context, _) {
                  return WishlistEditorHeroCard(
                    title: _titleController.text,
                    badge: 'Wishlist idea',
                    subtitle:
                        'Start with the spark. We can shape the destination, timing, and route in the next step.',
                  );
                },
              ),
              const SizedBox(height: 18),
              WishlistEditorSectionCard(
                title: 'Start with the spark',
                subtitle:
                    'Just name the idea for now. You can decide later whether AI should shape the itinerary or whether you want to build it yourself.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TextField(
                      controller: _titleController,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Wishlist title',
                        hintText: 'See Northern Lights',
                        prefixIcon: Icon(Icons.auto_stories_outlined),
                      ),
                      onChanged: (_) {
                        if (_errorText != null) {
                          setState(() {
                            _errorText = null;
                          });
                        } else {
                          setState(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Country, timing, purpose, and cities can all be added on the next screen.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    if (_errorText != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        _errorText!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
        ),
      ),
    );
  }

  Future<void> _createIdea({required bool openManualEditor}) async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() {
        _errorText = 'Give this wishlist idea a title first.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      final insertedId =
          await ref.read(wishlistRepositoryProvider).addWishlistItem(
                WishlistItemRecord(
                  title: title,
                  createdAt: DateTime.now().millisecondsSinceEpoch,
                ),
              );
      await ref.read(socialSyncControllerProvider).flushWishlistNow();

      if (!mounted) {
        return;
      }

      final destination = openManualEditor
          ? '/wishlist/plan/$insertedId/manual-edit'
          : '/wishlist/plan/$insertedId';
      context.pushReplacement(destination);
    } catch (error) {
      setState(() {
        _errorText = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
