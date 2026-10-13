# Changelog

## 0.1.2 - 2026-10-13

Auditoría integral de datos, lógica, backend y experiencia de usuario:

- **Datos**: corrección del historial de aportes/retiros al editar préstamos; borrado en cascada de activos que limpia movimientos, metas y préstamos huérfanos; migración de esquema v16 reparadora de datos huérfanos y textos dañados; al elegir "Otro" en un movimiento la categoría se crea y guarda, y la migración v17 reconvierte los movimientos antiguos "Otro" + nota en categorías personalizadas sin perder datos.
- **Lógica**: "Total por cobrar" para préstamos; carga de deuda manejada sin ingresos; totales desglosados por moneda en activos, patrimonio y movimientos; préstamos a terceros excluidos de presupuesto y estadísticas.
- **Backend**: backup en `.zip` que incluye comprobantes; restauración atómica con reversión ante fallos; vaciado de datos que también borra comprobantes y reinicia las secuencias de SQLite.
- **Experiencia**: guardado con bloqueo de doble envío y salida protegida; errores uniformes con mensajes propios del dominio; estados vacíos y filas de desglose unificadas; tipografía mínima de 12pt; versión real en "Acerca de" (`package_info_plus`); código muerto de notificaciones eliminado.