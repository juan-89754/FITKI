import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/format/app_format.dart';
import '../../../shared/format/miles_input_formatter.dart';
import '../../../shared/forms/activo_obligatorio.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/mixins/guardando_mixin.dart';
import '../../../data/models/transaction.dart';
import '../../../data/models/asset.dart';
import '../../../data/models/categoria_personalizada.dart';
import '../../../logic/asignaciones/asignacion_logic.dart';
import '../../../logic/categorias/categoria_labels.dart';
import '../../../data/providers/shared_providers.dart';
import '../../../data/storage/comprobante_storage.dart';
import '../../asignaciones/asignacion_providers.dart';

class MovimientoFormScreen extends ConsumerStatefulWidget {
  final Transaction? movimiento;

  const MovimientoFormScreen({super.key, this.movimiento});

  @override
  ConsumerState<MovimientoFormScreen> createState() =>
      _MovimientoFormScreenState();
}

class _MovimientoFormScreenState extends ConsumerState<MovimientoFormScreen>
    with GuardandoMixin {
  File? _comprobante;
  String? _comprobantePathActual;
  String? _comprobanteNombreActual;
  String? _comprobanteMimeActual;
  int? _comprobanteSizeActual;
  bool _eliminarComprobante = false;
  final _formKey = GlobalKey<FormState>();
  final _montoController = TextEditingController();
  final _notaController = TextEditingController();
  final _categoriaOtroController = TextEditingController();

  String _tipo = 'gasto';
  String _categoria = 'alimentacion';
  int? _activoId;
  late DateTime _fecha;

  /// Bolsillo del plan AFCA al que se imputa el gasto. Es lo que hace que el
  /// plan y los movimientos no se desincronicen: sin este vínculo el "gastado"
  /// de cada bolsillo se quedaría en cero para siempre.
  int? _planDetalleId;

  /// true cuando el usuario eligió el destino a mano; así un cambio posterior
  /// de cuenta o categoría no lo reemplaza por la sugerencia automática.
  bool _destinoElegidoAMano = false;

  final DateFormat _fechaFormat = DateFormat('dd MMM yyyy');

  bool get _isEditing => widget.movimiento != null;

  @override
  void initState() {
    super.initState();
    final m = widget.movimiento;
    if (m != null) {
      _tipo = m.tipo;
      _categoria = m.categoria;
      _montoController.text = AppFormat.montoParaEditar(m.monto);
      _activoId = m.activoId;
      _fecha = m.fecha;
      _notaController.text = m.nota ?? '';
      _planDetalleId = m.planDetalleId;
      _destinoElegidoAMano = m.planDetalleId != null;
      _comprobantePathActual = m.comprobantePath;
      _comprobanteNombreActual = m.comprobanteNombre;
      _comprobanteMimeActual = m.comprobanteMimeType;
      _comprobanteSizeActual = m.comprobanteSizeBytes;
    } else {
      _fecha = DateTime.now();
    }
  }

  @override
  void dispose() {
    _montoController.dispose();
    _notaController.dispose();
    _categoriaOtroController.dispose();
    super.dispose();
  }

  List<String> _opcionesCategoria() {
    final personalizadas = ref
            .read(categoriasPersonalizadasStreamProvider)
            .value ??
        const <CategoriaPersonalizada>[];
    final categorias = categoriasDeTipo(_tipo, personalizadas);
    if (categorias.contains(_categoria)) return categorias;
    return [...categorias, _categoria];
  }

  /// Categoría real del movimiento: con "Otro" es el nombre escrito, resuelto
  /// contra las existentes igual que al guardar.
  String get _categoriaEfectiva {
    if (_categoria != 'otro') return _categoria;
    final nombre = _categoriaOtroController.text.trim();
    if (nombre.isEmpty) return '';
    final personalizadas = ref
            .read(categoriasPersonalizadasStreamProvider)
            .value ??
        const <CategoriaPersonalizada>[];
    return resolverCategoriaDeNombre(
      nombre: nombre,
      tipo: _tipo,
      existentes: personalizadas,
    );
  }

  List<ResumenDetalle> _bolsillosCandidatos() {
    final resumenes = ref.read(resumenesPlanProvider);
    return AsignacionLogic.bolsillosCandidatos(
      categoria: _categoriaEfectiva,
      activoId: _activoId,
      resumenes: resumenes,
    );
  }

  String _nombreDePlan(int? planId) {
    for (final resumen in ref.read(resumenesPlanProvider)) {
      if (resumen.plan.id == planId) return resumen.plan.nombre;
    }
    return 'Plan';
  }

  /// Mantiene el destino coherente con la cuenta y la categoría actuales.
  ///
  /// Si el vínculo actual ya no es un candidato (cambió la cuenta, la categoría
  /// o el plan se archivó) se limpia, porque apuntaría a un bolsillo que ya no
  /// corresponde. Solo se sugiere uno nuevo si el usuario no eligió a mano.
  void _revalidarDestino() {
    if (_tipo != 'gasto') {
      if (_planDetalleId != null) setState(() => _planDetalleId = null);
      return;
    }

    final candidatos = _bolsillosCandidatos();

    if (_planDetalleId != null) {
      final sigue = candidatos.any((c) => c.detalle.id == _planDetalleId);
      if (sigue) return;
      setState(() => _planDetalleId = null);
      if (_destinoElegidoAMano) return;
    }

    if (_destinoElegidoAMano || _activoId == null) return;

    final resumenes = ref.read(resumenesPlanProvider);
    final sugerido = AsignacionLogic.resolverVinculoAutomatico(
      categoria: _categoriaEfectiva,
      activoId: _activoId,
      planes: [for (final resumen in resumenes) resumen.plan],
      detalles: [
        for (final resumen in resumenes)
          for (final detalle in resumen.detalles) detalle.detalle,
      ],
    );
    if (sugerido != null && sugerido != _planDetalleId) {
      setState(() => _planDetalleId = sugerido);
    }
  }

  Future<void> _seleccionarFecha() async {
    final ahora = DateTime.now();
    final seleccionada = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(ahora.year - 5),
      lastDate: DateTime(ahora.year + 1, 12, 31),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppColors.primary,
                onPrimary: AppColors.textOnPrimary,
              ),
        ),
        child: child!,
      ),
    );
    if (seleccionada != null) {
      setState(() => _fecha = seleccionada);
    }
  }

  Future<void> _guardar() => ejecutarGuardado(_guardarReal);

  Future<void> _guardarReal() async {
    if (!_formKey.currentState!.validate()) return;

    // Todo movimiento va atado a una cuenta, sin importar su tipo: es lo que
    // hace que el saldo del activo cuadre con su historial y que los agregados
    // por categoría (estadísticas y bolsillos de AFCA) sumen bien. Antes solo
    // los gastos lo exigían, así que un ingreso se podía guardar con "Sin
    // activo" y el dinero aparecía de la nada sin tocar ningún saldo, en
    // silencio.
    final activos =
        ref.read(activosStreamProvider).asData?.value ?? const <Asset>[];
    final activoId = await resolverActivoDeGasto(
      context,
      activos: activos,
      actual: _activoId,
      mensajeSinActivos: 'Crea primero una cuenta o activo para registrar '
          'movimientos: todo el dinero entra y sale de una cuenta.',
    );
    if (activoId == null) return;
    _activoId = activoId;

    final monto = milesADouble(_montoController.text) ?? 0;

    // "Otro" nunca se guarda como slug: el nombre escrito en su campo dedicado
    // se convierte en la categoría real del movimiento. Si es un nombre nuevo
    // se crea la categoría personalizada (así aparece en "Categorías" y en los
    // dropdowns); si coincide con una fija o una ya creada, se reutiliza la
    // existente. La nota queda como nota, sin usarse para la categoría.
    var categoria = _categoria;
    String? nota = _notaController.text.trim().isEmpty
        ? null
        : _notaController.text.trim();
    if (_categoria == 'otro') {
      final nombreNuevo = _categoriaOtroController.text.trim();
      final personalizadas = ref
              .read(categoriasPersonalizadasStreamProvider)
              .value ??
          const <CategoriaPersonalizada>[];
      var resuelta = resolverCategoriaDeNombre(
        nombre: nombreNuevo,
        tipo: _tipo,
        existentes: personalizadas,
      );
      if (resuelta == nombreNuevo && nombreNuevo.isNotEmpty) {
        await ref.read(categoriaPersonalizadaRepositoryProvider).insert(
              CategoriaPersonalizada(
                nombre: nombreNuevo,
                icono: 'category_rounded',
                tipo: _tipo,
              ),
            );
        ref.invalidate(categoriasPersonalizadasStreamProvider);
        resuelta = nombreNuevo;
      }
      categoria = resuelta;
    }

    String? comprobantePath = _comprobantePathActual;
    String? comprobanteNombre = _comprobanteNombreActual;
    String? comprobanteMime = _comprobanteMimeActual;
    int? comprobanteSize = _comprobanteSizeActual;

    if (_eliminarComprobante) {
      await ComprobanteStorage().limpiarSiOrfano(_comprobantePathActual);
      comprobantePath = null;
      comprobanteNombre = null;
      comprobanteMime = null;
      comprobanteSize = null;
    } else if (_comprobante != null) {
      final archivo = await ComprobanteStorage().guardarArchivo(_comprobante!);
      comprobantePath = archivo.path;
      comprobanteNombre = archivo.nombre;
      comprobanteMime = _mimeDe(_comprobante!.path);
      comprobanteSize = archivo.sizeBytes;
      await ComprobanteStorage().limpiarSiOrfano(_comprobantePathActual);
    }

    final nuevo = Transaction(
      id: widget.movimiento?.id,
      tipo: _tipo,
      monto: monto,
      categoria: categoria,
      fecha: _fecha,
      activoId: _activoId,
      planDetalleId: _tipo == 'gasto' ? _planDetalleId : null,
      nota: nota,
      fechaCreacion: widget.movimiento?.fechaCreacion ?? DateTime.now(),
      comprobantePath: comprobantePath,
      comprobanteNombre: comprobanteNombre,
      comprobanteMimeType: comprobanteMime,
      comprobanteSizeBytes: comprobanteSize,
    );

    try {
      final movRepo = ref.read(movimientoRepositoryProvider);

      final original = widget.movimiento;
      if (_isEditing && original != null) {
        await movRepo.actualizarConAjusteDeSaldo(
          original: original,
          nuevo: nuevo,
        );
      } else {
        // El saldo lo descuenta el propio repositorio, en la misma
        // transacción que guarda el movimiento.
        await movRepo.insert(nuevo);
      }
    } catch (_) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'No se pudo guardar, intenta de nuevo',
          type: AppSnackbarType.error,
        );
      }
      return;
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final activosAsync = ref.watch(activosStreamProvider);
    // Suscripción reactiva: si el usuario crea/borra categorías, el dropdown
    // se reconstruye con la lista actualizada.
    ref.watch(categoriasPersonalizadasStreamProvider);

    return protegerSalida(
      Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar movimiento' : 'Nuevo movimiento'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSelectorTipo(),
            const SizedBox(height: 20),
            TextFormField(
              controller: _montoController,
              keyboardType: TextInputType.number,
              inputFormatters: const [MilesInputFormatter()],
              decoration: InputDecoration(
                labelText: 'Monto *',
                hintText: 'Ej. 1.500.000',
                prefixIcon: Icon(
                  Icons.attach_money_rounded,
                  color: _tipo == 'ingreso'
                      ? AppColors.primary
                      : AppColors.coral,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El monto es obligatorio';
                }
                final monto = milesADouble(value);
                if (monto == null || monto <= 0) {
                  return 'El monto debe ser mayor a 0';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _categoria,
              decoration: const InputDecoration(labelText: 'Categoría *'),
              items: _opcionesCategoria().map((categoria) {
                return DropdownMenuItem(
                  value: categoria,
                  child: Text(labelCategoria(categoria)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _categoria = value);
                  _revalidarDestino();
                }
              },
            ),
            const SizedBox(height: 16),
            activosAsync.when(
              data: (activos) {
                return DropdownButtonFormField<int?>(
                  initialValue: _activoId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Activo *'),
                  hint: const Text('Elige una cuenta'),
                  items: [
                    ...activos.map((asset) => DropdownMenuItem<int?>(
                          value: asset.id,
                          child: Text(
                            '${asset.nombre} · ${_formatearSaldo(asset)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                  ],
                  onChanged: (value) {
                    setState(() => _activoId = value);
                    _revalidarDestino();
                  },
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Text(
                'Error cargando activos: $e',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: AppColors.coral,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildDestinoPlan(),
            InkWell(
              onTap: _seleccionarFecha,
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Fecha *'),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _fechaFormat.format(_fecha),
                      style: Theme.of(context).textTheme.titleSmall!,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildComprobante(),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _categoria == 'otro'
                  ? TextFormField(
                      key: const ValueKey('campo-categoria-otro'),
                      controller: _categoriaOtroController,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => _revalidarDestino(),
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la categoría *',
                        hintText: 'Ej: Mascotas, Gimnasio, Becas',
                        alignLabelWithHint: true,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Escribe el nombre de la nueva categoría';
                        }
                        return null;
                      },
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('nota-opcional'),
              controller: _notaController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Nota (opcional)',
                hintText: 'Detalles adicionales...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: guardando ? null : _guardar,
              style: FilledButton.styleFrom(
                backgroundColor: _tipo == 'ingreso'
                    ? AppColors.primary
                    : AppColors.coral,
                foregroundColor: AppColors.textOnPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                _isEditing ? 'Guardar cambios' : 'Registrar movimiento',
                style: Theme.of(context).textTheme.titleMedium!,
              ),
            ),
            if (_activoId != null) ...[
              const SizedBox(height: 12),
              Text(
                _tipo == 'ingreso'
                    ? 'Se sumará al saldo del activo seleccionado.'
                    : 'Se descontará del saldo del activo seleccionado.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall!,
              ),
            ] else ...[
              const SizedBox(height: 12),
              Text(
                'Todo movimiento necesita una cuenta: es lo que mantiene el '
                'saldo del activo siempre cuadrado.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall!,
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }

  /// Destino del gasto dentro de un plan AFCA.
  ///
  /// Solo aparece para gastos y solo si hay bolsillos que puedan recibirlo: si
  /// la cuenta y la categoría no tienen plan activo, no hay nada que elegir y
  /// el campo se oculta en vez de quedar vacío. La sugerencia automática elige
  /// sola cuando hay una coincidencia única; el usuario siempre puede cambiarla
  /// o sacar el gasto del plan.
  ///
  /// La clave por vínculo obliga a reconstruir el campo cuando la sugerencia lo
  /// mueve: `DropdownButtonFormField` conserva su estado interno y ignoraría un
  /// `initialValue` posterior.
  Widget _buildDestinoPlan() {
    if (_tipo != 'gasto') return const SizedBox.shrink();

    final candidatos = _bolsillosCandidatos();
    if (candidatos.isEmpty && _planDetalleId == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<int?>(
        key: ValueKey(_planDetalleId),
        initialValue: _planDetalleId,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Destino del gasto',
          helperText: 'Se descuenta del plan que elijas al guardarlo.',
          helperMaxLines: 2,
        ),
        items: [
          const DropdownMenuItem<int?>(
            value: null,
            child: Text('Sin asignar (fuera de plan)'),
          ),
          for (final detalle in candidatos)
            DropdownMenuItem<int?>(
              value: detalle.detalle.id,
              child: Text(
                '${_nombreDePlan(detalle.detalle.planId)} · '
                '${AppFormat.moneda(detalle.restante)} libres',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (value) {
          setState(() {
            _planDetalleId = value;
            _destinoElegidoAMano = true;
          });
        },
      ),
    );
  }

  Widget _buildSelectorTipo() {
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(
          value: 'gasto',
          label: Text(
            'Gasto',
            style: Theme.of(context).textTheme.titleSmall!.copyWith(
                  color: _tipo == 'gasto'
                      ? AppColors.coral
                      : AppColors.textSecondary,
                ),
          ),
          icon: Icon(
            Icons.arrow_upward_rounded,
            size: 18,
            color: _tipo == 'gasto' ? AppColors.coral : AppColors.textSecondary,
          ),
        ),
        ButtonSegment(
          value: 'ingreso',
          label: Text(
            'Ingreso',
            style: Theme.of(context).textTheme.titleSmall!.copyWith(
                  color: _tipo == 'ingreso'
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
          ),
          icon: Icon(
            Icons.arrow_downward_rounded,
            size: 18,
            color: _tipo == 'ingreso'
                ? AppColors.primary
                : AppColors.textSecondary,
          ),
        ),
      ],
      selected: {_tipo},
      showSelectedIcon: false,
      onSelectionChanged: (selection) {
        setState(() {
          _tipo = selection.first;
          // Reinicio síncrono a una categoría fija del nuevo tipo; el
          // dropdown gasto/ingreso siempre la incluye y luego se rellena
          // con las personalizadas del tipo desde el stream provider.
          _categoria = _tipo == 'ingreso' ? 'salario' : 'alimentacion';
        });
        _revalidarDestino();
      },
    );
  }

  String _formatearSaldo(Asset asset) {
    final symbol = asset.moneda == 'USD' ? r'US$' : r'$';
    return AppFormat.moneda(asset.montoDisponible, symbol: symbol);
  }

  Widget _buildComprobante() {
    final tieneNuevo = _comprobante != null;
    final tieneActual = !_eliminarComprobante &&
        _comprobantePathActual != null &&
        _comprobantePathActual!.isNotEmpty;

    if (tieneNuevo) {
      final esImagen = _esImagen(_comprobante!.path);
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  esImagen
                      ? Icons.image_rounded
                      : Icons.description_rounded,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Comprobante seleccionado',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  onPressed: _quitarComprobante,
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Quitar comprobante',
                ),
              ],
            ),
            if (esImagen) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _comprobante!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 180,
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (tieneActual) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            Icon(Icons.attach_file_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _comprobanteNombreActual ?? 'Comprobante',
                style: Theme.of(context).textTheme.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: _quitarComprobante,
              child: const Text('Quitar'),
            ),
          ],
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: _seleccionarComprobante,
      icon: const Icon(Icons.add_photo_alternate_rounded),
      label: const Text('Adjuntar comprobante (opcional)'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Future<void> _seleccionarComprobante() async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (origen == null) return;

    try {
      final resultado = await ImagePicker().pickImage(
        source: origen,
        maxWidth: 2000,
        imageQuality: 85,
      );
      if (resultado == null) return;
      setState(() {
        _comprobante = File(resultado.path);
        _eliminarComprobante = false;
      });
    } catch (_) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'No se pudo seleccionar la imagen',
          type: AppSnackbarType.error,
        );
      }
    }
  }

  void _quitarComprobante() {
    setState(() {
      if (_comprobante != null) {
        _comprobante = null;
      } else {
        _eliminarComprobante = true;
      }
    });
  }

  bool _esImagen(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.heic');
  }

  String _mimeDe(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return 'image/jpeg';
  }
}
