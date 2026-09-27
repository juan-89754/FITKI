# FITKI

Fitki es una aplicación de finanzas personales que centraliza y organiza toda la información económica del usuario: activos, ingresos, gastos, deudas, préstamos, inversiones, presupuesto y metas de ahorro.

Su objetivo es darle una visión clara de la situación financiera y ayudar a tomar decisiones informadas, combinando el registro de datos con cálculos automáticos, alertas y recomendaciones sobre el presupuesto, las deudas y el ahorro.

## Estado del proyecto

Versión actual: `0.1.0`

La aplicación es **funcional y completamente local (offline)**: todos los datos se guardan en el dispositivo mediante SQLite. No requiere cuenta, ni servidor, ni conexión a internet, y ninguna información sale del equipo.

Módulos terminados y operativos:

| Módulo | Estado |
| --- | --- |
| Activos | ✅ Completo |
| Ingresos y gastos | ✅ Completo |
| Metas financieras | ✅ Completo |
| Deudas | ✅ Completo |
| Préstamos e inversiones | ✅ Completo |
| Cotizaciones y proyectos | ✅ Completo |
| Presupuesto y gastos diarios | ✅ Completo |
| Estadísticas | ✅ Completo |
| Perfil, apariencia, seguridad, categorías personalizadas y backup | ✅ Completo |
| Asistente financiero con IA | 🚧 No iniciado |

## Objetivo general

Desarrollar una plataforma inteligente para la gestión integral de finanzas personales que permita controlar ingresos, gastos, ahorros, préstamos, deudas y metas financieras, proporcionando recomendaciones para la toma de decisiones económicas.

## Funcionalidades

### Registro de activos

Permite registrar el patrimonio del usuario: cuentas bancarias, billeteras digitales, dinero en efectivo y otros.

- Campos: nombre, tipo, monto disponible, moneda (COP, USD o EUR), descripción y fecha de creación.
- Validaciones: el nombre es obligatorio y el monto debe ser mayor que cero.
- Cálculos: total por moneda y patrimonio total.
- Cada activo se puede crear, editar, eliminar y ajustar su monto directamente.

### Registro de gastos e ingresos

Módulo para llevar el control de los movimientos diarios de dinero.

- Campos: tipo (ingreso o gasto), monto, categoría, fecha, activo asociado (opcional) y nota.
- Validaciones: el monto es obligatorio y mayor que cero; si la categoría es *Otro* se exige describir a qué corresponde el movimiento.
- Al crear, editar o eliminar un movimiento, el saldo del activo asociado se actualiza de forma transaccional, de modo que los totales nunca quedan desincronizados.
- Cálculos: totales por categoría, total de ingresos, total de gastos y balance.

### Creación de metas financieras

- Campos: nombre, monto objetivo (opcional), finalidad, fecha estimada, comentarios y monto ahorrado.
- Validaciones: el nombre es obligatorio y el monto objetivo, si se informa, debe ser válido.
- Cálculos: monto restante, porcentaje de avance (limitado entre 0 y 100), semanas y meses restantes, y sugerencia de cuánto ahorrar por semana y por mes según el tiempo disponible.

> Las sugerencias se calculan con fórmulas deterministas (monto de la meta dividido entre el tiempo restante); no son recomendaciones generadas por un modelo de IA.

### Gestión de préstamos a terceros e inversiones

Dos secciones dentro del mismo módulo:

**Préstamos a terceros**
- Campos: beneficiario, monto prestado, monto recibido, fechas de préstamo y vencimiento, condiciones y observaciones.
- Cálculos: estado (activo o saldado), monto pendiente y total prestado que sigue activo.
- Permite registrar abonos parciales, que se acumulan sobre el monto pagado.

**Inversiones**
- Campos: tipo (divisas, bolsa, mercancías, eventos u otro), monto invertido, tasa y su período (anual o mensual), ganancia proyectada, ganancia real, fecha y notas.
- Cálculos: proyección de ganancia con interés simple y conversión entre tasas anuales y mensuales.
- Permite registrar la ganancia obtenida, que actualiza la ganancia real de la inversión.

### Gestión de deudas

- Campos: acreedor, monto pendiente, monto inicial, plazo, valor de la cuota, tasa de interés anual, fecha del próximo pago y observaciones.
- Validaciones: el acreedor es obligatorio, el monto inicial no puede ser menor que el pendiente y las cuotas e intereses, si se informan, deben ser válidos.
- Cálculos: cuotas restantes (con amortización opcional), monto pagado, porcentaje de avance y total pendiente.
- **Carga de deuda:** se compara la suma de las cuotas mensuales contra los ingresos del mes. El umbral de alerta es configurable por el usuario (10 % a 70 %, 40 % por defecto).
- Permite registrar pagos, ajustando el monto pendiente hasta llegar a cero.

### Gestión de cotizaciones

Permite planear compras o proyectos comparando opciones antes de decidir.

- Estructura: **proyecto** → **cotizaciones** → **ítems**.
- Ítems: producto o servicio, cantidad, precio unitario, enlace de compra, costos adicionales, notas y tipo (producto o servicio). Para los servicios las notas son obligatorias.
- Validaciones: el producto es obligatorio, la cantidad debe ser al menos 1 y el precio mayor que cero. Si hay filas de costos adicionales inválidas, la app lo avisa y pregunta si se guardan solo las válidas.
- Cálculos: subtotal por ítem, total por cotización y **comparación de la cotización más económica** dentro del proyecto.
- El enlace de compra se copia al portapapeles al tocarlo.

### Gastos presupuestados y gastos diarios

**Presupuesto mensual**
- Cada presupuesto parte de un activo (cuenta, billetera o efectivo) y de un monto total que se reparte entre las categorías.
- Validaciones: el total debe ser mayor que cero, debe haber al menos una partida y la suma de las partidas no puede superar el monto total. Las partidas de categoría *Otro* exigen una nota que explique qué cubren.
- Muestra el avance por categoría y por presupuesto, el monto sin asignar y avisos cuando se excede el límite.

**Gastos diarios (gastos hormiga)**
- Registro rápido desde una hoja inferior con nombre, valor, categoría y descripción opcional, además de un formulario completo que permite editar la fecha.
- Validaciones: el nombre es obligatorio y el valor debe ser mayor que cero.
- Se pueden editar y eliminar.

### Estadísticas y reportes

Panel con gráficos (`fl_chart`) que se recalcula solo ante cualquier cambio en los datos:

- **Resumen:** patrimonio total, balance del mes, promedio de avance de las metas, total de deudas pendientes y carga de deuda mensual frente al umbral configurado.
- **Gastos por categoría:** gráfico circular del mes actual, ordenado de mayor a menor y con su porcentaje sobre el total gastado.
- **Evolución del patrimonio:** gráfico de líneas de los últimos 6 meses.
- **Deudas vs. ingresos del mes:** barras comparativas con el porcentaje que representan las deudas sobre los ingresos.

### Funcionalidades transversales

**Perfil**
Nombre y foto (cámara o galería). La foto se copia a un archivo permanente de la app y la anterior se elimina al cambiarla.

**Apariencia**
Temas *Sistema*, *Claro* y *Rojo* (acento rojo en lugar del verde clásico). La preferencia se guarda y se aplica de inmediato.

**Seguridad**
- PIN de 4 a 6 dígitos, con paso de confirmación.
- El PIN se guarda como hash SHA-256 en `flutter_secure_storage` (Keychain en iOS/macOS, Android Keystore en Android), nunca en texto plano.
- Desbloqueo biométrico (huella o Face ID) cuando el dispositivo lo soporta.
- La app se bloquea al arrancar y cada vez que vuelve de segundo plano, sin perder la pantalla en la que estaba el usuario.
- Para desactivar el PIN se exige introducir el PIN actual. **No hay recuperación de PIN olvidado**: habría que reinstalar la app, lo que implica perder los datos locales.

**Categorías personalizadas**
- Se pueden crear categorías de gasto o ingreso con nombre e ícono.
- No se permiten nombres duplicados, ni frente a las categorías predefinidas ni frente a las existentes.
- Al eliminar una categoría, los movimientos y partidas de presupuesto que la usaban se reasignan a *Categoría eliminada*, de modo que el historial se conserva.

**Backup y restauración**
- **Generar backup:** copia el archivo `.db` completo y lo comparte mediante el diálogo nativo del sistema, sin pedir permisos de almacenamiento. Se muestra la fecha del último backup.
- **Restaurar:** se elige un archivo `.db`; antes de tocar la base real se valida que contenga todas las tablas de Fitki. Si el reemplazo falla a mitad de camino, la base original se revierte automáticamente y se informa que los datos se mantuvieron a salvo.
- **Borrar todos los datos:** requiere dos confirmaciones, la segunda escribiendo un texto. Conserva las preferencias (tema, PIN, biometría y umbral).

## Stack técnica

- **Flutter 3** / **Dart SDK >= 3.3.0**
- **Riverpod** para el estado y la inyección de dependencias
- **go_router** con `StatefulShellRoute` para la navegación
- **sqflite** como base de datos local (14 tablas, versión de esquema 8)
- **fl_chart** para los gráficos
- **shared_preferences** para preferencias no sensibles
- **flutter_secure_storage** para el hash del PIN
- **local_auth** para la biometría
- **image_picker** + **path_provider** para la foto de perfil
- **file_picker** + **share_plus** para backup y restauración
- **crypto** para el hash del PIN
- **intl** con localización `es` (fechas y moneda en español)
- **flutter_lints** para el análisis estático

Tipografías propias: **Manrope** y **Inter**.

## Arquitectura

El proyecto separa la lógica de negocio de la interfaz:

```
lib/
├── main.dart                  # Router, tema y bloqueo de la app (AppGate)
├── data/
│   ├── db/db_helper.dart      # Conexión SQLite, creación y migraciones
│   ├── models/                # Modelos con su definición SQL
│   ├── repositories/          # Acceso a datos por entidad
│   ├── preferences/           # Preferencias y almacenamiento seguro
│   └── providers/             # Providers compartidos
├── logic/                     # Reglas de negocio puras (sin UI ni Riverpod)
│   ├── activos/  movimientos/  metas/  deudas/
│   ├── prestamos/  inversiones/  cotizaciones/  presupuesto/
│   ├── estadisticas/          # Agregados y series para los gráficos
│   ├── backup/  seguridad/  categorias/
├── shared/                    # Tema, formato de números y widgets comunes
└── ui/                        # Pantallas agrupadas por módulo
```

Convenciones:

- Cada modelo declara su propio `createTableSQL`, y `DbHelper` lo reutiliza tanto en la creación inicial como en las migraciones, para que el esquema nunca diverja.
- Las capas de `logic/` son clases estáticas sin dependencias de Riverpod ni de la interfaz, con los cálculos concentrados y probables de forma aislada.
- Los streams de datos consultan la base cada 500 ms y solo emiten cuando el contenido cambia, por lo que todas las pantallas se actualizan solas tras cualquier escritura.

## Cómo ejecutar

Requisitos previos: Flutter 3 instalado y en el `PATH`.

```bash
# Obtener dependencias
flutter pub get

# Generar los iconos de la app (opcional)
dart run flutter_launcher_icons

# Análisis estático
flutter analyze

# Pruebas
flutter test

# Ejecución
flutter run                  # dispositivo o emulador connected
flutter run -d chrome        # web
```

Plataformas con scaffolding en el repositorio: Android, iOS, Web, Windows, macOS y Linux.

## Base de datos

Archivo único `fitki.db` con 14 tablas: `activos`, `movimientos`, `metas_financieras`, `prestamos`, `inversiones`, `deudas`, `proyectos_cotizacion`, `cotizaciones`, `items_cotizacion`, `presupuestos`, `gastos_presupuestados`, `gastos_diarios`, `categorias_personalizadas` y `perfil`.

El esquema se migra de forma incremental en `DbHelper._onUpgrade` (actualmente en la versión 8), de modo que las instalaciones existentes se actualizan sin perder datos.

## Pruebas

`test/widget_test.dart` contiene una prueba de humo que verifica que la app arranca y renderiza la pantalla de inicio. La cobertura de pruebas unitarias de la lógica de cálculo está pendiente.

## Privacidad

- Todos los datos se almacenan localmente en el dispositivo.
- No hay servidor, sincronización en la nube ni permisos de red: la app no transmite información financiera a ningún servicio.
- El único secreto (el hash del PIN) se guarda cifrado por el sistema operativo.

## Limitaciones conocidas y trabajo futuro

- **Asistente financiero con IA:** no implementado. No hay dependencias de red ni integraciones con modelos de lenguaje; las recomendaciones actuales provienen de fórmulas deterministas.
- **Reportes exportables:** los gráficos solo se muestran en pantalla, no se exportan a PDF ni se comparten.
- **Notificaciones y recordatorios:** la preferencia está contemplada, pero no hay motor de notificaciones implementado.
- **Conversión de divisas:** los activos en distintas monedas se suman directamente, sin conversión.
- **Cobertura de pruebas:** solo existe la prueba de humo; los cálculos de `lib/logic/` aún no tienen pruebas unitarias.
