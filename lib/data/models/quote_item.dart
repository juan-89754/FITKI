import 'dart:convert';

class CostoAdicional {
  final String concepto;
  final double valor;

  const CostoAdicional({required this.concepto, required this.valor});

  Map<String, dynamic> toJson() => {'concepto': concepto, 'valor': valor};

  factory CostoAdicional.fromJson(Map<String, dynamic> json) {
    return CostoAdicional(
      concepto: json['concepto'] as String? ?? '',
      valor: (json['valor'] as num?)?.toDouble() ?? 0,
    );
  }
}

class QuoteItem {
  static const String tipoProducto = 'producto';
  static const String tipoServicio = 'servicio';

  final int? id;
  final int cotizacionId;
  final String productoServicio;
  final String tipo;
  final int cantidad;
  final double precioUnitario;
  final String? enlaceCompra;
  final double costosAdicionales;
  final List<CostoAdicional> costosAdicionalesDetalle;
  final String? notas;

  const QuoteItem({
    this.id,
    required this.cotizacionId,
    required this.productoServicio,
    this.tipo = 'producto',
    required this.cantidad,
    required this.precioUnitario,
    this.enlaceCompra,
    this.costosAdicionales = 0,
    this.costosAdicionalesDetalle = const [],
    this.notas,
  });

  double get subtotal => cantidad * precioUnitario;

  double get total => subtotal + costosAdicionales;

  static const String tableName = 'items_cotizacion';

  static const String createTableSQL = '''
    CREATE TABLE $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      cotizacion_id INTEGER NOT NULL,
      producto_servicio TEXT NOT NULL,
      cantidad INTEGER NOT NULL DEFAULT 1,
      precio_unitario REAL NOT NULL,
      enlace_compra TEXT,
      costos_adicionales REAL NOT NULL DEFAULT 0,
      costos_adicionales_detalle TEXT,
      notas TEXT,
      FOREIGN KEY (cotizacion_id) REFERENCES cotizaciones(id) ON DELETE CASCADE
    )
  ''';

  QuoteItem copyWith({
    int? id,
    int? cotizacionId,
    String? productoServicio,
    String? tipo,
    int? cantidad,
    double? precioUnitario,
    String? enlaceCompra,
    double? costosAdicionales,
    List<CostoAdicional>? costosAdicionalesDetalle,
    String? notas,
  }) {
    return QuoteItem(
      id: id ?? this.id,
      cotizacionId: cotizacionId ?? this.cotizacionId,
      productoServicio: productoServicio ?? this.productoServicio,
      tipo: tipo ?? this.tipo,
      cantidad: cantidad ?? this.cantidad,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      enlaceCompra: enlaceCompra ?? this.enlaceCompra,
      costosAdicionales: costosAdicionales ?? this.costosAdicionales,
      costosAdicionalesDetalle:
          costosAdicionalesDetalle ?? this.costosAdicionalesDetalle,
      notas: notas ?? this.notas,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'cotizacion_id': cotizacionId,
      'producto_servicio': productoServicio,
      'tipo': tipo,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
      'enlace_compra': enlaceCompra,
      'costos_adicionales': costosAdicionales,
      'costos_adicionales_detalle': costosAdicionalesDetalle.isEmpty
          ? null
          : jsonEncode(
              costosAdicionalesDetalle.map((c) => c.toJson()).toList()),
      'notas': notas,
    };
  }

  factory QuoteItem.fromMap(Map<String, dynamic> map) {
    final detalleRaw = map['costos_adicionales_detalle'] as String?;
    final detalle = <CostoAdicional>[];
    if (detalleRaw != null && detalleRaw.isNotEmpty) {
      try {
        final lista = jsonDecode(detalleRaw) as List<dynamic>;
        detalle.addAll(lista.map((e) {
          final obj = e as Map<String, dynamic>;
          return CostoAdicional.fromJson(obj);
        }));
      } catch (_) {
        // Detalle corrupto: se ignora, la suma sigue en costosAdicionales.
      }
    }
    return QuoteItem(
      id: map['id'] as int?,
      cotizacionId: map['cotizacion_id'] as int,
      productoServicio: map['producto_servicio'] as String,
      tipo: map['tipo'] as String? ?? tipoProducto,
      cantidad: map['cantidad'] as int,
      precioUnitario: (map['precio_unitario'] as num).toDouble(),
      enlaceCompra: map['enlace_compra'] as String?,
      costosAdicionales: (map['costos_adicionales'] as num).toDouble(),
      costosAdicionalesDetalle: detalle,
      notas: map['notas'] as String?,
    );
  }
}