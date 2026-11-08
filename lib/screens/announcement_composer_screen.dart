import 'package:flutter/material.dart';

import '../core/demo_store.dart';
import 'announcement_tile.dart';

class AnnouncementComposerScreen extends StatefulWidget {
  const AnnouncementComposerScreen({super.key, required this.store});
  final DemoStore store;

  @override
  State<AnnouncementComposerScreen> createState() =>
      _AnnouncementComposerScreenState();
}

class _AnnouncementComposerScreenState
    extends State<AnnouncementComposerScreen> {
  final formKey = GlobalKey<FormState>();
  final title = TextEditingController();
  final body = TextEditingController();
  final place = TextEditingController();
  String kind = 'GENERAL';
  DateTime? meetingAt;
  bool busy = false;
  String? error;

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    place.dispose();
    super.dispose();
  }

  Future<void> pickMeetingDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: meetingAt ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: meetingAt == null
          ? TimeOfDay.fromDateTime(now.add(const Duration(hours: 1)))
          : TimeOfDay.fromDateTime(meetingAt!),
    );
    if (time == null || !mounted) return;
    setState(
      () => meetingAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    if (kind == 'MEETING' &&
        (meetingAt == null || !meetingAt!.isAfter(DateTime.now()))) {
      setState(
        () => error = 'Selecciona una fecha y hora futuras para la reunión.',
      );
      return;
    }
    if (kind == 'EMERGENCY') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Publicar alerta roja'),
          content: const Text(
            'Este aviso aparecerá destacado en rojo para tu junta durante 24 horas. No contacta servicios de emergencia.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Publicar alerta'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.publishAnnouncement(
        kind: kind,
        title: title.text,
        body: body.text,
        meetingAt: kind == 'MEETING' ? meetingAt : null,
        meetingPlace: kind == 'MEETING' ? place.text : null,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'No se pudo publicar el aviso. Comprueba tu rol y la conexión.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nuevo aviso vecinal')),
    body: Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Solo los miembros de tu junta podrán ver este aviso.'),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: kind,
            decoration: const InputDecoration(labelText: 'Tipo de aviso'),
            items: const [
              DropdownMenuItem(value: 'GENERAL', child: Text('Aviso normal')),
              DropdownMenuItem(value: 'MEETING', child: Text('Junta vecinal')),
              DropdownMenuItem(
                value: 'EMERGENCY',
                child: Text('Alerta de emergencia'),
              ),
            ],
            onChanged: busy
                ? null
                : (value) => setState(() {
                    kind = value!;
                    error = null;
                  }),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: title,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Título'),
            validator: (value) => (value?.trim().length ?? 0) < 5
                ? 'Escribe al menos 5 caracteres.'
                : null,
          ),
          TextFormField(
            controller: body,
            maxLength: 2000,
            minLines: 3,
            maxLines: 7,
            decoration: const InputDecoration(labelText: 'Mensaje'),
            validator: (value) => (value?.trim().length ?? 0) < 10
                ? 'Escribe al menos 10 caracteres.'
                : null,
          ),
          if (kind == 'MEETING') ...[
            OutlinedButton.icon(
              onPressed: busy ? null : pickMeetingDate,
              icon: const Icon(Icons.event_outlined),
              label: Text(
                meetingAt == null
                    ? 'Elegir fecha y hora'
                    : announcementDate(context, meetingAt!),
              ),
            ),
            TextFormField(
              controller: place,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Lugar de reunión'),
              validator: (value) =>
                  (value?.trim().length ?? 0) < 3 ? 'Indica el lugar.' : null,
            ),
          ],
          if (kind == 'EMERGENCY')
            const Card(
              color: Color(0xFFFFE2E2),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Alerta roja dentro de la app. Se cierra automáticamente en 24 horas; puedes cerrarla antes.',
                ),
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                error!,
                style: const TextStyle(color: Color(0xFFB42323)),
              ),
            ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: busy ? null : submit,
            icon: const Icon(Icons.send_outlined),
            label: Text(busy ? 'Publicando...' : 'Publicar para mi junta'),
          ),
        ],
      ),
    ),
  );
}
