import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'wishlist_plan_manual_edit_controller.dart';
import 'wishlist_plan_manual_edit_models.dart';
import '../trips/widgets/add_trip_cover_image_preview.dart';
import '../../widgets/frosted_squircle.dart';
import 'widgets/wishlist_editor_shell.dart';
import 'widgets/wishlist_manual_edit_common_widgets.dart';

class WishlistPlanManualEditCityScreen extends StatefulWidget {
  const WishlistPlanManualEditCityScreen({
    super.key,
    required this.city,
    required this.controller,
    required this.onDraftChanged,
  });

  final EditableCity city;
  final WishlistPlanManualEditController controller;
  final VoidCallback onDraftChanged;

  @override
  State<WishlistPlanManualEditCityScreen> createState() =>
      _WishlistPlanManualEditCityScreenState();
}

class _WishlistPlanManualEditCityScreenState
    extends State<WishlistPlanManualEditCityScreen> {
  late final TextEditingController _cityController;
  late final TextEditingController _daysController;
  late final TextEditingController _reasonController;
  late final TextEditingController _overviewController;

  EditableCity get _city => widget.city;

  @override
  void initState() {
    super.initState();
    _cityController = TextEditingController(text: _city.city);
    _daysController = TextEditingController(text: _city.days.toString());
    _reasonController = TextEditingController(text: _city.reason);
    _overviewController = TextEditingController(text: _city.overview);
  }

  @override
  void dispose() {
    _cityController.dispose();
    _daysController.dispose();
    _reasonController.dispose();
    _overviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: wishlistEditorInputDecorationTheme(context),
      ),
      child: WishlistEditorShell(
        title: 'Edit City',
        onBack: () => Navigator.of(context).maybePop(),
        topActions: <Widget>[
          WishlistEditorTopBarIconAction(
            icon: Icons.check_rounded,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
        body: ListView(
          physics: const BouncingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            16,
            wishlistEditorTopOverlayClearanceOf(context),
            16,
            40,
          ),
          children: <Widget>[
            WishlistEditorHeroCard(
              title: _cityController.text.trim().isEmpty
                  ? 'Untitled city'
                  : _cityController.text.trim(),
              badge: _city.isExtra ? 'Extra city' : 'Route stop',
              subtitle: _reasonController.text.trim().isEmpty
                  ? 'Shape the story, pacing, and activities for this stop.'
                  : _reasonController.text.trim(),
              imageUrl: _city.image?.imageUrl,
              chips: <String>[
                '${_resolvedDays()} days',
                '${_city.timeline.length} timeline stops',
                '${_city.thingsToDo.length} activities',
              ],
            ),
            const SizedBox(height: 18),
            WishlistEditorSectionCard(
              title: 'Stop basics',
              subtitle:
                  'Keep the essentials here, then shape the city flow and activity list below.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'City',
                      prefixIcon: Icon(Icons.location_city_outlined),
                    ),
                    onChanged: (value) {
                      _city.city = value;
                      _notifyDraftChanged();
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _daysController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Days',
                            prefixIcon: Icon(Icons.schedule_outlined),
                          ),
                          onChanged: (value) {
                            final parsed = int.tryParse(value.trim());
                            if (parsed != null && parsed > 0) {
                              _city.days = parsed;
                            }
                            _notifyDraftChanged();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SwitchListTile(
                          value: _city.isExtra,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Extra city'),
                          onChanged: (value) {
                            setState(() {
                              _city.isExtra = value;
                            });
                            _notifyDraftChanged();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Why this city belongs',
                      prefixIcon: Icon(Icons.push_pin_outlined),
                    ),
                    onChanged: (value) {
                      _city.reason = value;
                      _notifyDraftChanged();
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Cover image',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickCityImageFromDevice,
                          icon: const Icon(Icons.upload_file_rounded),
                          label: const Text('Upload image'),
                        ),
                      ),
                    ],
                  ),
                  if (_city.image != null &&
                      _city.image!.imageUrl.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    AddTripCoverImagePreview(uri: _city.image!.imageUrl.trim()),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _overviewController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'City overview',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.menu_book_outlined),
                    ),
                    onChanged: (value) {
                      _city.overview = value;
                      _notifyDraftChanged();
                    },
                  ),
                  if (_city.image != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      _city.image!.source == 'manual'
                          ? 'Using your uploaded city cover.'
                          : 'Current image: ${_city.image!.source} | ${_city.image!.license}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            WishlistEditorSectionCard(
              title: 'Timeline',
              subtitle:
                  'This is the day-by-day rhythm for the city. Add, reorder, and refine stops here.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  WishlistManualEditSubSectionHeader(
                    title: 'Stops',
                    onAdd: () async {
                      if (await widget.controller
                          .addTimelineStep(context, _city)) {
                        setState(_notifyDraftChanged);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  if (_city.timeline.isEmpty)
                    const WishlistManualEditInlineHint(
                      text: 'No timeline stops for this city yet.',
                    )
                  else
                    ..._city.timeline.asMap().entries.map((entry) {
                      final index = entry.key;
                      final step = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _EditableTimelineCard(
                          step: step,
                          canMoveUp: index > 0,
                          canMoveDown: index < _city.timeline.length - 1,
                          onMoveUp: index == 0
                              ? null
                              : () => setState(() {
                                    widget.controller.moveTimelineStep(
                                      _city,
                                      index,
                                      index - 1,
                                    );
                                    _notifyDraftChanged();
                                  }),
                          onMoveDown: index == _city.timeline.length - 1
                              ? null
                              : () => setState(() {
                                    widget.controller.moveTimelineStep(
                                      _city,
                                      index,
                                      index + 1,
                                    );
                                    _notifyDraftChanged();
                                  }),
                          onEdit: () async {
                            if (await widget.controller.editTimelineStep(
                              context,
                              _city,
                              index,
                            )) {
                              setState(_notifyDraftChanged);
                            }
                          },
                          onDelete: () => setState(() {
                            widget.controller.deleteTimelineStep(_city, index);
                            _notifyDraftChanged();
                          }),
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 12),
            WishlistEditorSectionCard(
              title: 'Things to do',
              subtitle:
                  'Keep the activity list lightweight, practical, and easy to scan.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  WishlistManualEditSubSectionHeader(
                    title: 'Activities',
                    onAdd: () async {
                      if (await widget.controller.addThing(context, _city)) {
                        setState(_notifyDraftChanged);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  if (_city.thingsToDo.isEmpty)
                    const WishlistManualEditInlineHint(
                      text: 'No activities for this city yet.',
                    )
                  else
                    ..._city.thingsToDo.asMap().entries.map((entry) {
                      final index = entry.key;
                      final thing = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _EditableThingCard(
                          label: thing.value,
                          canMoveUp: index > 0,
                          canMoveDown: index < _city.thingsToDo.length - 1,
                          onMoveUp: index == 0
                              ? null
                              : () => setState(() {
                                    widget.controller.moveThing(
                                      _city,
                                      index,
                                      index - 1,
                                    );
                                    _notifyDraftChanged();
                                  }),
                          onMoveDown: index == _city.thingsToDo.length - 1
                              ? null
                              : () => setState(() {
                                    widget.controller.moveThing(
                                      _city,
                                      index,
                                      index + 1,
                                    );
                                    _notifyDraftChanged();
                                  }),
                          onEdit: () async {
                            if (await widget.controller.editThing(
                              context,
                              _city,
                              index,
                            )) {
                              setState(_notifyDraftChanged);
                            }
                          },
                          onDelete: () => setState(() {
                            widget.controller.deleteThing(_city, index);
                            _notifyDraftChanged();
                          }),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _resolvedDays() {
    final parsed = int.tryParse(_daysController.text.trim());
    return parsed != null && parsed > 0 ? parsed : _city.days;
  }

  void _notifyDraftChanged() {
    widget.controller.clearError();
    widget.onDraftChanged();
  }

  Future<void> _pickCityImageFromDevice() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: false,
    );
    if (!mounted || result == null || result.files.isEmpty) {
      return;
    }

    final path = result.files.single.path;
    if (path == null || path.trim().isEmpty) {
      return;
    }

    setState(() {
      _city.image = buildManualWishlistImage(
        path.trim(),
        title: _cityController.text.trim().isEmpty
            ? 'City cover'
            : '${_cityController.text.trim()} cover',
      );
      _notifyDraftChanged();
    });
  }
}

class _EditableTimelineCard extends StatelessWidget {
  const _EditableTimelineCard({
    required this.step,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onEdit,
    required this.onDelete,
  });

  final EditableTimeline step;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FrostedSquircle(
      radius: 26,
      blurSigma: 14,
      color: scheme.surfaceContainerLowest.withValues(alpha: 0.86),
      borderColor: scheme.outlineVariant.withValues(alpha: 0.12),
      shadowColor: scheme.primary.withValues(alpha: 0.06),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.42),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    Icons.route_outlined,
                    size: 16,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      step.slot,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: scheme.secondary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step.place,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            step.note,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _MiniActionButton(
                label: 'Up',
                icon: Icons.keyboard_arrow_up_rounded,
                onTap: onMoveUp,
                enabled: canMoveUp,
              ),
              _MiniActionButton(
                label: 'Down',
                icon: Icons.keyboard_arrow_down_rounded,
                onTap: onMoveDown,
                enabled: canMoveDown,
              ),
              _MiniActionButton(
                label: 'Edit',
                icon: Icons.edit_outlined,
                onTap: onEdit,
              ),
              _MiniActionButton(
                label: 'Delete',
                icon: Icons.delete_outline,
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditableThingCard extends StatelessWidget {
  const _EditableThingCard({
    required this.label,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onEdit,
    required this.onDelete,
  });

  final String label;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FrostedSquircle(
      radius: 26,
      blurSigma: 14,
      color: scheme.surfaceContainerLowest.withValues(alpha: 0.86),
      borderColor: scheme.outlineVariant.withValues(alpha: 0.12),
      shadowColor: scheme.primary.withValues(alpha: 0.06),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    Icons.checklist_rounded,
                    size: 16,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _MiniActionButton(
                label: 'Up',
                icon: Icons.keyboard_arrow_up_rounded,
                onTap: onMoveUp,
                enabled: canMoveUp,
              ),
              _MiniActionButton(
                label: 'Down',
                icon: Icons.keyboard_arrow_down_rounded,
                onTap: onMoveDown,
                enabled: canMoveDown,
              ),
              _MiniActionButton(
                label: 'Edit',
                icon: Icons.edit_outlined,
                onTap: onEdit,
              ),
              _MiniActionButton(
                label: 'Delete',
                icon: Icons.delete_outline,
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  const _MiniActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return TextButton.icon(
      onPressed: enabled ? onTap : null,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        foregroundColor: scheme.onSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.12),
          ),
        ),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
