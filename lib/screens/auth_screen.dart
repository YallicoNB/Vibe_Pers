import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/demo_store.dart';
import '../core/models.dart';
import 'home_screen.dart';
import 'zone_picker_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.store});
  final DemoStore store;
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final client = Supabase.instance.client;
  StreamSubscription<AuthState>? subscription;
  bool loading = true;
  bool hasProfile = false;
  String? error;

  @override
  void initState() {
    super.initState();
    subscription = client.auth.onAuthStateChange.listen(
      (_) => loadProfile(),
      onError: (Object _) {
        if (mounted) setState(() => error = 'No se pudo actualizar la sesión.');
      },
    );
    loadProfile();
  }

  Future<void> loadProfile() async {
    final user = client.auth.currentUser;
    if (user == null) {
      widget.store.clearProfile();
      if (mounted) {
        setState(() {
          loading = false;
          hasProfile = false;
          error = null;
        });
      }
      return;
    }
    if (widget.store.restoreCachedProfile(user.id) && mounted) {
      setState(() {
        hasProfile = true;
        loading = false;
        error = null;
      });
    } else if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final profile = await client
          .from('profiles')
          .select(
            'id,display_name,community_id,status,role,leader_community_id',
          )
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted || client.auth.currentUser?.id != user.id) return;
      if (profile == null) {
        widget.store.clearProfile();
        setState(() {
          hasProfile = false;
          loading = false;
        });
      } else if (profile['status'] != 'ACTIVO') {
        widget.store.clearProfile();
        setState(() {
          hasProfile = false;
          loading = false;
          error = 'Tu perfil requiere revisión.';
        });
      } else {
        final c = await client
            .from('communities')
            .select('id,name,area_label,center_lat,center_lng')
            .eq('id', profile['community_id'] as String)
            .single();
        final areaRows = await client.rpc('list_community_areas');
        final boundary = <LatLng>[];
        for (final row in areaRows as List) {
          if (row['id'] != c['id'] || row['boundary_geojson'] == null) continue;
          final geo = jsonDecode(
            row['boundary_geojson'] as String,
          ) as Map<String, dynamic>;
          for (final item in (geo['coordinates'] as List).first as List) {
            final pair = item as List;
            boundary.add(
              LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble()),
            );
          }
        }
        if (!mounted || client.auth.currentUser?.id != user.id) return;
        widget.store.bindProfile(
          user.id,
          profile['display_name'] as String,
          Community(
            id: c['id'] as String,
            name: c['name'] as String,
            area: c['area_label'] as String,
            lat: (c['center_lat'] as num?)?.toDouble() ?? -11.938,
            lng: (c['center_lng'] as num?)?.toDouble() ?? -76.696,
          ),
          boundary,
          isLeader:
              profile['role'] == 'LIDER_VECINAL' &&
              profile['leader_community_id'] == c['id'],
        );
        setState(() {
          hasProfile = true;
          loading = false;
        });
        widget.store.refreshRemote();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          hasProfile = widget.store.authenticatedNeighbor?.id == user.id;
          error = hasProfile
              ? null
              : 'No se pudo cargar tu perfil. Revisa la conexión.';
        });
      }
    }
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: loadProfile,
                  child: const Text('Reintentar'),
                ),
                TextButton(
                  onPressed: () => client.auth.signOut(),
                  child: const Text('Cerrar sesión'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (client.auth.currentUser == null) return const AccessScreen();
    if (!hasProfile) return CompleteProfileScreen(onCompleted: loadProfile);
    return HomeScreen(store: widget.store, onProfileChanged: loadProfile);
  }
}

class AccessScreen extends StatefulWidget {
  const AccessScreen({super.key});
  @override
  State<AccessScreen> createState() => _AccessScreenState();
}

class _AccessScreenState extends State<AccessScreen> {
  final formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  bool register = false;
  bool busy = false;
  String? message;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final auth = Supabase.instance.client.auth;
      if (register) {
        await auth.signUp(email: email.text.trim(), password: password.text);
        if (mounted) {
          setState(
            () => message = 'Cuenta de correo creada. Confirma el correo y luego completa el perfil. El registro vecinal solo termina si el DNI es único.',
          );
        }
      } else {
        await auth.signInWithPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => message = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => message = 'No se pudo conectar. Inténtalo de nuevo.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/Logo_vibePers.jpeg',
              height: 32,
              width: 32,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          const Text('MiBarrio'),
        ],
      ),
    ),
    body: Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    register ? Icons.person_add_alt_1 : Icons.groups,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    register ? 'Crear cuenta' : 'Bienvenido a tu comunidad',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                    ),
                    validator: (v) => v == null || !v.contains('@')
                        ? 'Escribe un correo válido'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: password,
                    obscureText: true,
                    autofillHints: [
                      register
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    decoration: const InputDecoration(labelText: 'Contraseña'),
                    validator: (v) => v == null || v.length < 8
                        ? 'Usa al menos 8 caracteres'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  if (message != null) ...[
                    Text(message!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                  ],
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: Text(
                      busy
                          ? 'Espera…'
                          : register
                          ? 'Crear cuenta de correo'
                          : 'Iniciar sesión',
                    ),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() {
                            register = !register;
                            message = null;
                          }),
                    child: Text(
                      register ? 'Ya tengo cuenta' : 'Crear una cuenta',
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'El correo se confirma antes del primer ingreso. El mercado y SOS siguen siendo una demostración.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key, required this.onCompleted});
  final Future<void> Function() onCompleted;
  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final number = TextEditingController();
  ZoneSelection? zone;
  Uint8List? front;
  Uint8List? back;
  bool busy = false;
  String? message;

  @override
  void dispose() {
    name.dispose();
    number.dispose();
    super.dispose();
  }

  Future<void> chooseZone() async {
    final result = await Navigator.push<ZoneSelection>(
      context,
      MaterialPageRoute(builder: (_) => const ZonePickerScreen()),
    );
    if (result != null && mounted) {
      setState(() {
        zone = result;
        message = null;
      });
    }
  }

  Future<void> pickImage(bool isFront) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        throw const FormatException('Cada foto debe medir menos de 5 MB.');
      }
      _mime(bytes);
      if (mounted) {
        setState(() {
          if (isFront) {
            front = bytes;
          } else {
            back = bytes;
          }
          message = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => message = e is FormatException
              ? e.message
              : 'No se pudo abrir la cámara o galería.',
        );
      }
    }
  }

  String _mime(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    throw const FormatException('Usa una foto JPG o PNG.');
  }

  String _errorMessage(Object error) {
    final raw = error is PostgrestException
        ? error.message
        : error is StorageException
        ? error.message
        : '';
    if (raw.contains('DOCUMENT_ALREADY_USED')) {
      return 'Ese DNI ya pertenece a otra cuenta. Tu perfil vecinal no se guardó.';
    }
    if (raw.contains('COMMUNITY_OVERLAP')) {
      return 'Tu zona se superpone con otra. Únete a ella o ajusta el contorno.';
    }
    if (raw.contains('BOUNDARY_SIZE')) {
      return 'La zona debe medir entre 0,01 y 50 km².';
    }
    if (raw.contains('INVALID_BOUNDARY')) {
      return 'El contorno se cruza o no es válido. Dibújalo de nuevo.';
    }
    if (raw.contains('DOCUMENT_PHOTOS_REQUIRED')) {
      return 'Faltan las dos fotos del DNI.';
    }
    return 'No se pudo completar el registro. Revisa la conexión e inténtalo de nuevo.';
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    if (zone == null || front == null || back == null) {
      setState(() => message = 'Define tu zona y añade ambas caras del DNI.');
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    final client = Supabase.instance.client;
    final uploaded = <String>[];
    try {
      final uid = client.auth.currentUser!.id;
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      final frontMime = _mime(front!);
      final backMime = _mime(back!);
      final frontPath =
          '$uid/front-$stamp${frontMime == 'image/png' ? '.png' : '.jpg'}';
      final backPath =
          '$uid/back-$stamp${backMime == 'image/png' ? '.png' : '.jpg'}';
      await client.storage
          .from('identity-documents')
          .uploadBinary(
            frontPath,
            front!,
            fileOptions: FileOptions(contentType: frontMime),
          );
      uploaded.add(frontPath);
      await client.storage
          .from('identity-documents')
          .uploadBinary(
            backPath,
            back!,
            fileOptions: FileOptions(contentType: backMime),
          );
      uploaded.add(backPath);
      await client.rpc(
        'complete_registration_v2',
        params: {
          'p_display_name': name.text.trim(),
          'p_community_name': zone!.name,
          'p_boundary': zone!.geoJson,
          'p_existing_community_id': zone!.existingId,
          'p_doc_number': number.text.trim(),
          'p_front_path': frontPath,
          'p_back_path': backPath,
        },
      );
      uploaded.clear();
      front = null;
      back = null;
      await widget.onCompleted();
    } on FormatException catch (e) {
      if (mounted) setState(() => message = e.message);
    } catch (e) {
      if (uploaded.isNotEmpty) {
        try {
          await client.storage.from('identity-documents').remove(uploaded);
        } catch (_) {}
      }
      if (mounted) setState(() => message = _errorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _photoField(bool isFront, Uint8List? bytes) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(
            isFront ? 'DNI: anverso' : 'DNI: reverso',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (bytes != null)
            Image.memory(bytes, height: 130, fit: BoxFit.contain),
          OutlinedButton.icon(
            onPressed: busy ? null : () => pickImage(isFront),
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text(bytes == null ? 'Tomar o elegir foto' : 'Repetir foto'),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Completa tu perfil'),
      actions: [
        TextButton(
          onPressed: () => Supabase.instance.client.auth.signOut(),
          child: const Text('Salir'),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Text(
                'Registro vecinal',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Prototipo: usa solo un número e imágenes ficticias de DNI. Tu comunidad no representa una delimitación oficial.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: name,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'Nombre visible'),
                validator: (v) =>
                    (v?.trim().length ?? 0) < 2 ? 'Escribe tu nombre' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: number,
                maxLength: 8,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Número de DNI (8 dígitos)',
                ),
                validator: (v) =>
                    RegExp(r'^[0-9]{8}$').hasMatch(v?.trim() ?? '')
                    ? null
                    : 'El DNI debe tener 8 dígitos',
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.map_outlined),
                  title: Text(
                    zone == null
                        ? 'Delimitar mi zona en el mapa'
                        : zone!.existingId == null
                        ? zone!.name!
                        : 'Comunidad seleccionada en el mapa',
                  ),
                  subtitle: const Text(
                    'Dibuja una zona nueva o únete a una existente.',
                  ),
                  onTap: busy ? null : chooseZone,
                ),
              ),
              const SizedBox(height: 8),
              _photoField(true, front),
              _photoField(false, back),
              const SizedBox(height: 10),
              if (message != null)
                Text(
                  message!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              FilledButton(
                onPressed: busy ? null : submit,
                child: Text(busy ? 'Guardando…' : 'Completar registro'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
