import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/haptics.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/gradual_mark.dart';
import '../../shared/widgets/settings_group.dart';
import '../daily_word/today_concepts_controller.dart';
import 'reminder_controller.dart';
import 'reminder_plan.dart';

/// The daily reminder as a standalone card.
class ReminderCard extends StatelessWidget {
  const ReminderCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: const ReminderRows(),
    );
  }
}

/// Settings rows for the daily reminder: on/off, time, and a live preview of
/// what the notification will say. Fits inside a [SettingsGroup].
class ReminderRows extends ConsumerStatefulWidget {
  const ReminderRows({super.key});

  @override
  ConsumerState<ReminderRows> createState() => _ReminderRowsState();
}

class _ReminderRowsState extends ConsumerState<ReminderRows> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Coming back from a system settings page: re-check delivery and
    // reschedule so new permissions take effect straight away.
    _lifecycle = AppLifecycleListener(onResume: () {
      ref.invalidate(reminderDeliveryProvider);
      ref.read(reminderControllerProvider.notifier).sync();
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final controller = ref.read(reminderControllerProvider.notifier);
    final settings = ref.watch(reminderControllerProvider).asData?.value ?? const ReminderSettings();
    final supported = controller.isSupported;
    final on = supported && settings.enabled;
    final time = TimeOfDay(hour: settings.hour, minute: settings.minute).format(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsRow(
          icon: Icons.notifications_active_rounded,
          iconColor: c.caution,
          title: 'Daily reminder',
          subtitle: !supported
              ? 'Available in the Android app'
              : on
                  ? 'Every day at $time'
                  : "A nudge with the day's first word",
          trailing: Switch(
            key: const ValueKey('reminder_switch'),
            value: on,
            activeThumbColor: c.onBrand,
            activeTrackColor: c.brand,
            onChanged: supported ? (value) => _toggle(context, ref, value) : null,
          ),
        ),
        AnimatedSize(
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: on
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Divider(height: 1, thickness: 1, indent: 62, color: c.border.withValues(alpha: 0.6)),
                    SettingsRow(
                      key: const ValueKey('reminder_time'),
                      icon: Icons.schedule_rounded,
                      iconColor: c.brand,
                      title: 'Reminder time',
                      value: time,
                      onTap: () => _pickTime(context, ref, settings),
                    ),
                    ..._deliveryRows(context),
                    Divider(height: 1, thickness: 1, indent: 62, color: c.border.withValues(alpha: 0.6)),
                    SettingsRow(
                      key: const ValueKey('reminder_test'),
                      icon: Icons.send_rounded,
                      iconColor: c.info,
                      title: 'Send a test reminder',
                      subtitle: 'Arrives in 1 minute. Lock your phone and wait',
                      onTap: () => _sendTest(context),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
                      child: _NotificationPreview(message: _previewMessage(ref)),
                    ),
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  /// Rows that fix delivery problems on this phone, shown only when needed.
  List<Widget> _deliveryRows(BuildContext context) {
    final c = context.colors;
    final delivery = ref.watch(reminderDeliveryProvider).asData?.value;
    if (delivery == null) return const [];
    final divider = Divider(height: 1, thickness: 1, indent: 62, color: c.border.withValues(alpha: 0.6));
    final maker = delivery.manufacturer.isEmpty
        ? 'this phone'
        : '${delivery.manufacturer[0].toUpperCase()}${delivery.manufacturer.substring(1)} phones';
    return [
      if (!delivery.exact) ...[
        divider,
        SettingsRow(
          key: const ValueKey('reminder_exact'),
          icon: Icons.alarm_on_rounded,
          iconColor: c.warningStrong,
          title: 'Deliver on time',
          subtitle: 'Allow exact alarms, or it can arrive up to an hour late',
          trailing: _ActionPill(label: 'Allow', onTap: () => _allowExact()),
          onTap: () => _allowExact(),
        ),
      ],
      if (delivery.needsAutostart) ...[
        divider,
        SettingsRow(
          key: const ValueKey('reminder_autostart'),
          icon: Icons.power_settings_new_rounded,
          iconColor: c.danger,
          title: 'Turn on Autostart',
          subtitle: 'On $maker, closing Gradual cancels reminders unless Autostart is on',
          trailing: _ActionPill(label: 'Open', onTap: _openAutostart),
          onTap: _openAutostart,
        ),
      ],
    ];
  }

  Future<void> _allowExact() async {
    Haptics.selection();
    await ref.read(reminderControllerProvider.notifier).allowExactTiming();
  }

  Future<void> _openAutostart() async {
    Haptics.selection();
    await ref.read(reminderPlatformProvider).openAutostartSettings();
  }

  Future<void> _sendTest(BuildContext context) async {
    Haptics.light();
    final when = await ref.read(reminderControllerProvider.notifier).sendTest();
    if (when != null && context.mounted) {
      final time = TimeOfDay.fromDateTime(when).format(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Test reminder set for $time. Lock your phone and wait.')),
      );
    }
  }

  ReminderMessage _previewMessage(WidgetRef ref) {
    final today = ref.watch(todayConceptsControllerProvider).asData?.value;
    if (today == null) return buildReminderMessage(const DayContent(isScheduled: false));
    // Preview the morning version, before any words are read.
    return buildReminderMessage(DayContent(
      concepts: today.concepts,
      isWeekendReview: today.isWeekendReview,
      isScheduled: !today.isFallback,
    ));
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool on) async {
    Haptics.selection();
    final ok = await ref.read(reminderControllerProvider.notifier).setEnabled(on);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Allow notifications for Gradual in your phone settings to get reminders.')),
      );
    }
  }

  Future<void> _pickTime(BuildContext context, WidgetRef ref, ReminderSettings settings) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: settings.hour, minute: settings.minute),
      helpText: 'Daily reminder time',
    );
    if (picked == null) return;
    Haptics.selection();
    await ref.read(reminderControllerProvider.notifier).setTime(picked.hour, picked.minute);
  }
}

/// A small mock of the Android notification so people see what they'll get.
class _NotificationPreview extends StatelessWidget {
  const _NotificationPreview({required this.message});

  final ReminderMessage message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: 'Preview: ${message.title}. ${message.body}',
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: BoxDecoration(
            color: c.surfaceSunken,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GradualMark(size: 14, color: c.brand),
                  const SizedBox(width: 6),
                  Text('Gradual', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textTertiary)),
                  Text(" · Today's words", style: TextStyle(fontSize: 11, color: c.textMuted)),
                  const Spacer(),
                  Text('PREVIEW',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: c.textMuted)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          message.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, height: 1.35, color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const GradualLogoTile(size: 36, showShadow: false),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          backgroundColor: c.brand,
          foregroundColor: c.onBrand,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        child: Text(label),
      ),
    );
  }
}
