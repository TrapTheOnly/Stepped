import 'package:flutter/material.dart';

import '../../data/db/app_db.dart';
import 'gemini_trip_planner.dart';
import 'wishlist_plan_manual_edit_dialogs.dart';
import 'wishlist_plan_manual_edit_logic.dart';
import 'wishlist_plan_manual_edit_models.dart';

class WishlistPlanManualEditController {
  WishlistPlanManualEditController();

  final TextEditingController countryController = TextEditingController();
  final TextEditingController summaryController = TextEditingController();
  final TextEditingController durationDaysController = TextEditingController();
  final TextEditingController durationReasonController = TextEditingController();

  bool didHydrate = false;
  bool isSaving = false;
  String? errorText;
  String durationSource = 'ai_recommended';

  int _nextId = 1;
  List<EditableTimeWindow> timeWindows = <EditableTimeWindow>[];
  List<EditableCity> cities = <EditableCity>[];
  Map<String, dynamic>? requestPayload;

  void dispose() {
    countryController.dispose();
    summaryController.dispose();
    durationDaysController.dispose();
    durationReasonController.dispose();
  }

  void hydrate({
    required WishlistItemRecord item,
    required GeminiTripPlanner planner,
  }) {
    final hydrated = hydrateWishlistManualState(
      item: item,
      planner: planner,
      allocateId: allocateId,
    );
    countryController.text = hydrated.country;
    summaryController.text = hydrated.summary;
    durationDaysController.text = hydrated.durationDays;
    durationReasonController.text = hydrated.durationReason;
    durationSource = hydrated.durationSource;
    timeWindows = hydrated.timeWindows;
    cities = hydrated.cities;
    requestPayload = hydrated.requestPayload;
    didHydrate = true;
  }

  int allocateId() {
    final id = _nextId;
    _nextId += 1;
    return id;
  }

  void clearError() {
    errorText = null;
  }

  Future<bool> addTimeWindow(BuildContext context) async {
    final created = await showWishlistManualTimeWindowDialog(
      context,
      allocateId: allocateId,
    );
    if (created == null) {
      return false;
    }
    timeWindows.add(created);
    errorText = null;
    return true;
  }

  Future<bool> editTimeWindow(BuildContext context, int index) async {
    final updated = await showWishlistManualTimeWindowDialog(
      context,
      existing: timeWindows[index],
      allocateId: allocateId,
    );
    if (updated == null) {
      return false;
    }
    timeWindows[index] = updated.copyWith(id: timeWindows[index].id);
    errorText = null;
    return true;
  }

  bool deleteTimeWindow(int index) {
    timeWindows.removeAt(index);
    errorText = null;
    return true;
  }

  bool moveWindow(int from, int to) {
    final item = timeWindows.removeAt(from);
    timeWindows.insert(to, item);
    errorText = null;
    return true;
  }

  Future<bool> addCity(BuildContext context) async {
    final city = await showWishlistManualCityDialog(
      context,
      allocateId: allocateId,
    );
    if (city == null) {
      return false;
    }
    cities.add(city);
    errorText = null;
    return true;
  }

  bool deleteCity(int index) {
    cities.removeAt(index);
    errorText = null;
    return true;
  }

  bool moveCity(int from, int to) {
    final city = cities.removeAt(from);
    cities.insert(to, city);
    errorText = null;
    return true;
  }

  Future<bool> addTimelineStep(BuildContext context, EditableCity city) async {
    final created = await showWishlistManualTimelineDialog(
      context,
      allocateId: allocateId,
    );
    if (created == null) {
      return false;
    }
    city.timeline.add(created);
    errorText = null;
    return true;
  }

  Future<bool> editTimelineStep(
    BuildContext context,
    EditableCity city,
    int index,
  ) async {
    final updated = await showWishlistManualTimelineDialog(
      context,
      existing: city.timeline[index],
      allocateId: allocateId,
    );
    if (updated == null) {
      return false;
    }
    city.timeline[index] = updated.copyWith(id: city.timeline[index].id);
    errorText = null;
    return true;
  }

  bool deleteTimelineStep(EditableCity city, int index) {
    city.timeline.removeAt(index);
    errorText = null;
    return true;
  }

  bool moveTimelineStep(EditableCity city, int from, int to) {
    final item = city.timeline.removeAt(from);
    city.timeline.insert(to, item);
    errorText = null;
    return true;
  }

  Future<bool> addThing(BuildContext context, EditableCity city) async {
    final created = await showWishlistManualThingDialog(
      context,
      allocateId: allocateId,
    );
    if (created == null) {
      return false;
    }
    city.thingsToDo.add(created);
    errorText = null;
    return true;
  }

  Future<bool> editThing(
    BuildContext context,
    EditableCity city,
    int index,
  ) async {
    final updated = await showWishlistManualThingDialog(
      context,
      existing: city.thingsToDo[index],
      allocateId: allocateId,
    );
    if (updated == null) {
      return false;
    }
    city.thingsToDo[index] = updated.copyWith(id: city.thingsToDo[index].id);
    errorText = null;
    return true;
  }

  bool deleteThing(EditableCity city, int index) {
    city.thingsToDo.removeAt(index);
    errorText = null;
    return true;
  }

  bool moveThing(EditableCity city, int from, int to) {
    final item = city.thingsToDo.removeAt(from);
    city.thingsToDo.insert(to, item);
    errorText = null;
    return true;
  }

  String? validateDraft() {
    return validateWishlistManualDraft(
      country: countryController.text,
      summary: summaryController.text,
      durationDaysRaw: durationDaysController.text,
      cities: cities,
    );
  }

  GeminiTripPlan? toDraftPlan() {
    return buildWishlistManualDraftPlan(
      country: countryController.text,
      summary: summaryController.text,
      durationDaysRaw: durationDaysController.text,
      durationReason: durationReasonController.text,
      durationSource: durationSource,
      timeWindows: timeWindows,
      cities: cities,
    );
  }
}
