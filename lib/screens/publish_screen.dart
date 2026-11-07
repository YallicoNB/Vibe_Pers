import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/demo_store.dart';
import '../core/models.dart';
import 'point_picker_screen.dart';

class PublishScreen extends StatefulWidget {
  const PublishScreen({super.key, required this.store});
  final DemoStore store;
  @override
  State<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends State<PublishScreen> {
  final formKey = GlobalKey<FormState>();
  final title = TextEditingController();
  final description = TextEditingController();
  final price = TextEditingController();
  final whatsapp = TextEditingController();
  String type = 'Producto';
  String category = 'Otros';
  String direction = 'Necesito';
  String mode = 'Préstamo';
  XFile? photo;
  LatLng? businessPoint;
  bool shareWhatsapp = false;
  bool busy = false;
  @override
  void dispose() {
    title.dispose();
    description.dispose();
    price.dispose();
    whatsapp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final help = type == 'Ayuda';
    return Scaffold(
      appBar: AppBar(title: const Text('Publicar')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              '1. Elige qué vas a publicar',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              children: ['Producto', 'Servicio', 'Ayuda']
                  .map(
                    (v) => ChoiceChip(
                      label: Text(v),
                      selected: type == v,
                      onSelected: (_) => setState(() {
                        type = v;
                        category = 'Otros';
                      }),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 18),
            const Text(
              '2. Completa una sola ficha',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (help) ...[
              DropdownButtonFormField<String>(
                initialValue: direction,
                decoration: const InputDecoration(labelText: 'Tipo de ayuda'),
                items: ['Necesito', 'Ofrezco']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => direction = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: mode,
                decoration: const InputDecoration(labelText: 'Modalidad'),
                items: ['Préstamo', 'Donación', 'Trueque', 'Voluntariado']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => mode = v!),
              ),
              const SizedBox(height: 12),
            ] else ...[
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items:
                    [
                          'Otros',
                          'Gasfitería',
                          'Electricidad',
                          'Carpintería',
                          'Clases',
                          'Cerrajería',
                          'Alimentos',
                          'Hogar',
                        ]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                onChanged: (v) => setState(() => category = v!),
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: title,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Título'),
              validator: (v) => (v?.trim().length ?? 0) < 5
                  ? 'Escribe al menos 5 caracteres'
                  : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: description,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Descripción'),
              validator: (v) => (v?.trim().length ?? 0) < 10
                  ? 'Escribe al menos 10 caracteres'
                  : null,
            ),
            if (!help) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Precio en soles (S/)',
                ),
                validator: (v) =>
                    double.tryParse((v ?? '').replaceAll(',', '.')) == null ||
                        double.parse((v ?? '').replaceAll(',', '.')) < 0
                    ? 'Ingresa un precio válido'
                    : null,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final result = await ImagePicker().pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 75,
                    maxWidth: 1200,
                  );
                  if (result != null && mounted) setState(() => photo = result);
                },
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  photo == null ? 'Agregar foto obligatoria' : 'Cambiar foto',
                ),
              ),
              if (photo != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('Foto seleccionada: ${photo!.name}'),
                ),
              CheckboxListTile(
                value: shareWhatsapp,
                contentPadding: EdgeInsets.zero,
                title: const Text('Publicar mi WhatsApp en esta ficha'),
                onChanged: (v) => setState(() => shareWhatsapp = v ?? false),
              ),
              if (shareWhatsapp)
                TextFormField(
                  controller: whatsapp,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Número de WhatsApp con código de país',
                  ),
                  validator: (v) =>
                      (v ?? '').replaceAll(RegExp(r'\D'), '').length < 10
                      ? 'Ingresa un número válido'
                      : null,
                ),
            ],
            const SizedBox(height: 10),
            if (widget.store.authenticatedNeighbor != null && !help)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(
                    businessPoint == null
                        ? 'Elegir punto del negocio'
                        : 'Punto del negocio seleccionado',
                  ),
                  subtitle: const Text(
                    'Usa un punto público aproximado si trabajas desde casa.',
                  ),
                  onTap: () async {
                    final point = await Navigator.push<LatLng>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PointPickerScreen(
                          center: LatLng(
                            widget.store.community.lat,
                            widget.store.community.lng,
                          ),
                        ),
                      ),
                    );
                    if (point != null && mounted) {
                      setState(() => businessPoint = point);
                    }
                  },
                ),
              ),
            if (widget.store.authenticatedNeighbor == null)
              Text('Zona: ${widget.store.community.area} · Ubicación ficticia'),
            const SizedBox(height: 14),
            const Text(
              '3. Publicar ahora',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: busy ? null : _publish,
              icon: const Icon(Icons.save_outlined),
              label: Text(
                busy
                    ? 'Guardando…'
                    : widget.store.authenticatedNeighbor != null && !help
                    ? 'Publicar para mis vecinos'
                    : 'Guardar publicación local',
              ),
            ),
            const SizedBox(height: 10),
            if (widget.store.authenticatedNeighbor == null || help)
              const Text(
                'La ayuda de esta demostración solo se guarda en este teléfono.',
                style: TextStyle(fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _publish() async {
    if (!formKey.currentState!.validate()) return;
    if (type != 'Ayuda' && photo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega una foto para publicar.')),
      );
      return;
    }
    if (widget.store.authenticatedNeighbor != null &&
        type != 'Ayuda' &&
        businessPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Elige un punto aproximado para tu negocio.'),
        ),
      );
      return;
    }
    if (widget.store.authenticatedNeighbor != null &&
        type != 'Ayuda' &&
        businessPoint != null &&
        !widget.store.containsPoint(
          businessPoint!.latitude,
          businessPoint!.longitude,
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El punto del negocio debe estar dentro de tu comunidad.',
          ),
        ),
      );
      return;
    }
    setState(() => busy = true);
    try {
      if (widget.store.authenticatedNeighbor != null && type != 'Ayuda') {
        final client = Supabase.instance.client;
        final uid = client.auth.currentUser!.id;
        final bytes = await photo!.readAsBytes();
        if (bytes.length > 10 * 1024 * 1024) {
          throw Exception('La foto supera 10 MB.');
        }
        final png = bytes.length > 3 && bytes[0] == 0x89 && bytes[1] == 0x50;
        final jpeg = bytes.length > 3 && bytes[0] == 0xff && bytes[1] == 0xd8;
        if (!png && !jpeg) throw Exception('Usa una foto JPG o PNG.');
        final path =
            '$uid/${DateTime.now().microsecondsSinceEpoch}${png ? '.png' : '.jpg'}';
        await client.storage
            .from('listing-photos')
            .uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(
                contentType: png ? 'image/png' : 'image/jpeg',
              ),
            );
        await client.from('listings').insert({
          'seller_id': uid,
          'community_id': widget.store.community.id,
          'kind': type == 'Servicio' ? 'SERVICE' : 'PRODUCT',
          'category': category,
          'title': title.text.trim(),
          'description': description.text.trim(),
          'price': double.parse(price.text.replaceAll(',', '.')),
          'zone': widget.store.community.name,
          'lat': businessPoint!.latitude,
          'lng': businessPoint!.longitude,
          'whatsapp_public': shareWhatsapp
              ? whatsapp.text.replaceAll(RegExp(r'\D'), '')
              : null,
          'photo_storage_path': path,
        });
        await widget.store.refreshRemote();
      } else if (type == 'Ayuda') {
        widget.store.addHelp(
          HelpPost(
            id: DemoStore.newId(),
            authorId: widget.store.currentUserId,
            communityId: widget.store.community.id,
            direction: direction,
            mode: mode,
            title: title.text.trim(),
            description: description.text.trim(),
            createdAt: DateTime.now(),
          ),
        );
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final photoFile = await File(photo!.path)
            .copy('${dir.path}/${DemoStore.newId()}.jpg');
        widget.store.addListing(
          Listing(
            id: DemoStore.newId(),
            ownerId: widget.store.currentUserId,
            communityId: widget.store.community.id,
            kind: type,
            category: category,
            title: title.text.trim(),
            description: description.text.trim(),
            price: double.parse(price.text.replaceAll(',', '.')),
            zone: widget.store.community.area,
            lat: widget.store.community.lat,
            lng: widget.store.community.lng,
            createdAt: DateTime.now(),
            whatsapp: shareWhatsapp
                ? whatsapp.text.replaceAll(RegExp(r'\D'), '')
                : null,
            photoPath: photoFile.path,
          ),
        );
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.store.authenticatedNeighbor != null && type != 'Ayuda'
                  ? 'Publicado para tu comunidad.'
                  : 'Guardado localmente para demostración.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar la publicación.')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
