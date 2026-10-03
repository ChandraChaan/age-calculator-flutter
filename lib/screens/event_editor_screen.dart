import 'package:agecalculator/engine/civil_date.dart';
import 'package:agecalculator/engine/local_time.dart';
import 'package:agecalculator/engine/recurrence.dart';
import 'package:agecalculator/models/event.dart';
import 'package:agecalculator/state/event_controller.dart';
import 'package:agecalculator/widgets/date_picker_field.dart';
import 'package:agecalculator/widgets/event_category_style.dart';
import 'package:agecalculator/widgets/event_tile.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const int _maxTitleLength = 80;
const int _maxNotesLength = 500;
const double _maxContentWidth = 720;
const String _saveFailedMessage = "Couldn't save. Please try again.";

enum _Mode { create, edit, duplicate, saveBirthday }

typedef _Fields = ({
  String title,
  EventCategory category,
  CivilDate date,
  LocalTime? time,
  Recurrence recurrence,
  String notes,
});

/// Creates, edits or duplicates an event. Pops with the saved [Event], or
/// with nothing when the user leaves without saving.
class EventEditorScreen extends StatefulWidget {
  const EventEditorScreen.create({
    super.key,
    required this.events,
    required CivilDate this.initialDate,
  }) : initial = null,
       _mode = _Mode.create;

  const EventEditorScreen.edit({
    super.key,
    required this.events,
    required Event event,
  }) : initial = event,
       initialDate = null,
       _mode = _Mode.edit;

  /// [draft] comes from [EventController.duplicateDraft].
  const EventEditorScreen.duplicate({
    super.key,
    required this.events,
    required Event draft,
  }) : initial = draft,
       initialDate = null,
       _mode = _Mode.duplicate;

  /// A new yearly, all-day birthday on [dateOfBirth], titled "Birthday".
  const EventEditorScreen.saveBirthday({
    super.key,
    required this.events,
    required CivilDate dateOfBirth,
  }) : initial = null,
       initialDate = dateOfBirth,
       _mode = _Mode.saveBirthday;

  final EventController events;

  /// The event being edited or duplicated; `null` for a new event.
  final Event? initial;

  /// The preselected date of a new event.
  final CivilDate? initialDate;

  final _Mode _mode;

  @override
  State<EventEditorScreen> createState() => _EventEditorScreenState();
}

class _EventEditorScreenState extends State<EventEditorScreen> {
  // The time picker starts here when the event has no time yet.
  static final _defaultPickerTime = LocalTime(9, 0);

  late final _Fields _initialFields;
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late EventCategory _category;
  late CivilDate _date;
  LocalTime? _time;
  LocalTime? _lastTime;
  late Recurrence _recurrence;
  bool _repeatChosen = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _initialFields = switch (widget._mode) {
      _Mode.create => (
        title: '',
        category: EventCategory.event,
        date: widget.initialDate!,
        time: null,
        recurrence: Recurrence.none,
        notes: '',
      ),
      _Mode.saveBirthday => (
        title: 'Birthday',
        category: EventCategory.birthday,
        date: widget.initialDate!,
        time: null,
        recurrence: Recurrence.yearly,
        notes: '',
      ),
      _Mode.edit || _Mode.duplicate => (
        title: initial!.title,
        category: initial.category,
        date: initial.date,
        time: initial.time,
        recurrence: initial.recurrence,
        notes: initial.notes ?? '',
      ),
    };
    final title = _initialFields.title;
    _title = widget._mode == _Mode.saveBirthday
        // Selected, so typing a name replaces the default "Birthday".
        ? TextEditingController.fromValue(
            TextEditingValue(
              text: title,
              selection: TextSelection(
                baseOffset: 0,
                extentOffset: title.length,
              ),
            ),
          )
        : TextEditingController(text: title);
    _title.addListener(_onTextChanged);
    _notes = TextEditingController(text: _initialFields.notes)
      ..addListener(_onTextChanged);
    _category = _initialFields.category;
    _date = _initialFields.date;
    _time = _initialFields.time;
    _recurrence = _initialFields.recurrence;
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  _Fields get _fields => (
    title: _title.text,
    category: _category,
    date: _date,
    time: _time,
    recurrence: _recurrence,
    notes: _notes.text,
  );

  bool get _hasChanges => _fields != _initialFields;

  bool get _canSave => !_saving && _title.text.trim().isNotEmpty;

  String get _screenTitle => switch (widget._mode) {
    _Mode.create || _Mode.saveBirthday => 'New event',
    _Mode.edit => 'Edit event',
    _Mode.duplicate => 'Duplicate event',
  };

  void _selectCategory(EventCategory category) {
    setState(() {
      _category = category;
      final yearlyByDefault =
          category == EventCategory.birthday ||
          category == EventCategory.anniversary;
      if (yearlyByDefault && !_repeatChosen) _recurrence = Recurrence.yearly;
    });
  }

  void _selectRecurrence(Recurrence? recurrence) {
    if (recurrence == null) return;
    setState(() {
      _recurrence = recurrence;
      _repeatChosen = true;
    });
  }

  void _setAllDay(bool allDay) {
    if (!allDay) {
      _pickTime();
      return;
    }
    setState(() {
      _lastTime = _time;
      _time = null;
    });
  }

  Future<void> _pickTime() async {
    final start = _time ?? _lastTime ?? _defaultPickerTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: start.hour, minute: start.minute),
    );
    if (picked == null || !mounted) return;
    setState(() => _time = LocalTime(picked.hour, picked.minute));
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty || _saving) return;
    final notes = _notes.text.trim();
    final base =
        widget.initial ??
        // add() replaces this placeholder ID and these timestamps.
        Event(
          id: 'draft',
          title: title,
          category: _category,
          date: _date,
          recurrence: _recurrence,
          enabled: true,
          createdAt: DateTime.utc(1970),
          updatedAt: DateTime.utc(1970),
        );
    final event = base.copyWith(
      title: title,
      category: _category,
      date: _date,
      time: _time,
      recurrence: _recurrence,
      notes: notes.isEmpty ? null : notes,
    );
    if (widget._mode == _Mode.saveBirthday &&
        event.category == EventCategory.birthday &&
        !await _confirmAnotherBirthday(event.date)) {
      return;
    }
    if (!mounted) return;

    setState(() => _saving = true);
    final Event? saved;
    if (widget._mode == _Mode.edit) {
      final updated = await widget.events.update(event);
      saved = updated ? widget.events.eventById(event.id) : null;
    } else {
      saved = await widget.events.add(event);
    }
    if (!mounted) return;
    if (saved == null) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(_saveFailedMessage)));
      return;
    }
    Navigator.of(context).pop(saved);
  }

  /// `true` when no birthday exists on [date] yet, or the user chooses to
  /// save another one.
  Future<bool> _confirmAnotherBirthday(CivilDate date) async {
    final existing = findBirthdaysOn(widget.events.events, date);
    if (existing.isEmpty) return true;
    final day = DateFormat('d MMMM yyyy').format(date.toDateTime());
    final saveAnother = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(
          "A birthday on $day already exists ('${existing.first.title}'). "
          'Save another?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save anyway'),
          ),
        ],
      ),
    );
    return saveAnother == true;
  }

  Future<void> _onPopInvoked(bool didPop, Event? result) async {
    if (didPop) return;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final time = _time;
    return PopScope<Event>(
      canPop: !_hasChanges,
      onPopInvokedWithResult: _onPopInvoked,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Cancel',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(_screenTitle),
          actions: [
            TextButton(
              onPressed: _canSave ? _save : null,
              child: const Text('Save'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    controller: _title,
                    autofocus:
                        widget._mode == _Mode.create ||
                        widget._mode == _Mode.saveBirthday,
                    maxLength: _maxTitleLength,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _FieldLabel('Category'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final category in EventCategory.values)
                        _CategoryChip(
                          category: category,
                          selected: category == _category,
                          onSelected: () => _selectCategory(category),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  DatePickerField(
                    label: 'Date',
                    placeholder: 'Select date',
                    selectedDate: _date.toDateTime(),
                    onDateSelected: (date) =>
                        setState(() => _date = CivilDate.fromDateTime(date)),
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2100, 12, 31),
                    helpText: 'Select date',
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('All day'),
                    value: time == null,
                    onChanged: _setAllDay,
                  ),
                  if (time != null) ...[
                    const _FieldLabel('Time'),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.schedule_rounded),
                      label: Text(formatEventTime(context, time)),
                    ),
                  ],
                  const SizedBox(height: 16),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Repeat',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Recurrence>(
                        value: _recurrence,
                        isExpanded: true,
                        isDense: true,
                        itemHeight: null,
                        onChanged: _selectRecurrence,
                        items: [
                          for (final recurrence in Recurrence.values)
                            DropdownMenuItem(
                              value: recurrence,
                              child: Text(recurrenceLabel(recurrence)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _notes,
                    maxLength: _maxNotesLength,
                    minLines: 3,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onSelected,
  });

  final EventCategory category;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final style = EventCategoryStyle.of(category);
    return ChoiceChip(
      avatar: Icon(
        style.icon,
        color: style.color(Theme.of(context).colorScheme),
      ),
      label: Text(style.label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
    );
  }
}
