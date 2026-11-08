import 'dart:async';

import 'package:flutter/material.dart';

import '../core/community_updates.dart';
import '../core/demo_store.dart';

String announcementDate(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final material = MaterialLocalizations.of(context);
  return '${material.formatMediumDate(local)} · ${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}

class AnnouncementTile extends StatelessWidget {
  const AnnouncementTile({
    super.key,
    required this.store,
    required this.announcement,
  });
  final DemoStore store;
  final CommunityAnnouncement announcement;

  @override
  Widget build(BuildContext context) {
    final emergency = announcement.isEmergency;
    final unread = !store.isAnnouncementRead(announcement);
    return Card(
      color: emergency ? const Color(0xFFFFE2E2) : null,
      child: ListTile(
        leading: Icon(
          emergency
              ? Icons.warning_amber_rounded
              : announcement.isMeeting
              ? Icons.event_outlined
              : Icons.campaign_outlined,
          color: emergency ? const Color(0xFFB42323) : null,
        ),
        title: Text(
          (emergency ? 'ALERTA · ' : '') + announcement.title,
          style: TextStyle(
            fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
            color: emergency ? const Color(0xFF8F1717) : null,
          ),
        ),
        subtitle: Text(
          (announcement.isMeeting && announcement.meetingAt != null
                  ? '${announcementDate(context, announcement.meetingAt!)}\n'
                  : '') +
              announcement.body,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: store.currentUser.isLeader
            ? IconButton(
                tooltip: 'Cerrar aviso',
                icon: const Icon(Icons.close),
                onPressed: () => _close(context),
              )
            : unread
            ? const Icon(Icons.circle, size: 10, color: Color(0xFFB42323))
            : null,
        onTap: () {
          unawaited(
            store.markAnnouncementRead(announcement).catchError((Object _) {}),
          );
          showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text((emergency ? 'ALERTA · ' : '') + announcement.title),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (emergency)
                      const Text(
                        'Aviso de emergencia de tu junta',
                        style: TextStyle(
                          color: Color(0xFFB42323),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    Text(
                      'Publicado: ${announcementDate(
                            dialogContext,
                            announcement.createdAt,
                          )}',
                    ),
                    if (announcement.isMeeting &&
                        announcement.meetingAt != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Reunión: ${announcementDate(
                              dialogContext,
                              announcement.meetingAt!,
                            )}',
                      ),
                      Text(
                        'Lugar: ${announcement.meetingPlace ?? 'Por confirmar'}',
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(announcement.body),
                    const SizedBox(height: 12),
                    Text(
                      'Publicado por ${store.person(announcement.authorId).name}',
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _close(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar aviso'),
        content: const Text('Dejará de aparecer a los vecinos de esta junta.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cerrar aviso'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await store.closeAnnouncement(announcement);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo cerrar el aviso. Revisa la conexión.'),
          ),
        );
      }
    }
  }
}
