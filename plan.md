# PROYECTO FINAL — Análisis de Sistemas I  
## Sistema de Control de Inventario Inteligente (n8n + Supabase)

**Autor:** ____________________  
**Fecha:** 02/03/2026  
**Modalidad:** Individual — Ejecución 100% local (recomendada)

---

## 1. Planteamiento del problema

En laboratorios, bodegas o áreas administrativas suele existir pérdida de control sobre el inventario: productos que se agotan sin aviso, préstamos no registrados, devoluciones tardías y artículos vencidos o próximos a vencer. Esto provoca interrupciones operativas, compras urgentes y riesgos (especialmente si se trata de insumos sensibles).

Este proyecto propone una solución local con **n8n** para automatizar el flujo de inventario (entradas, préstamos, devoluciones y alertas), utilizando **Supabase (PostgreSQL)** como persistencia, con salidas verificables (archivos y reportes) y bitácoras de auditoría.

---

## 2. Objetivo general

Diseñar e implementar una automatización local con n8n que gestione inventario y préstamos, valide reglas de negocio, genere alertas automáticas y produzca reportes verificables, almacenando todos los datos en Supabase (PostgreSQL) con bitácora de auditoría y manejo estructurado de errores.

### 2.1 Objetivos específicos
- Implementar **mínimo 3 workflows**: Ingesta/Devoluciones, Procesamiento de Reglas y Salida de Reportes.
- Persistir información en **Supabase/PostgreSQL** (tablas: productos, movimientos, préstamos, alertas, audit_log, error_log).
- Aplicar reglas de negocio: validación de campos, stock mínimo, control de vencimientos, deduplicación de alertas y control de préstamos.
- Generar evidencias de salida verificables: archivos CSV/TXT y registros en base de datos.
- Demostrar manejo de errores (Error Trigger + ramas IF), seguridad (variables de entorno) y pruebas con entradas válidas e inválidas.

---

## 3. Alcance y reglas de negocio

### 3.1 Alcance (incluye)
- Registro de productos (alta individual o carga masiva por archivo).
- Registro de entradas de stock (reposición).
- Registro de préstamos con validación de disponibilidad.
- Registro de devoluciones (ajuste de stock automático).
- Alertas automáticas por:
  - **Stock bajo** (`stock_actual <= stock_minimo`)
  - **Vencimiento próximo** (`fecha_vencimiento <= hoy + N días`, configurable)
  - **Préstamos vencidos** (`fecha_devolucion < hoy` y `devuelto = false`)
- Reporte automático (semanal) de inventario y alertas.
- Bitácora de ejecuciones (`audit_log`) y bitácora de errores (`error_log`).

### 3.2 Fuera de alcance (no incluye)
- Interfaz web completa (se simula con Postman / archivos JSON / webhooks).
- Control de roles y usuarios (funcionalidad opcional).

---

## 4. Arquitectura local

### 4.1 Componentes

| Componente | Rol |
|---|---|
| **n8n (Docker)** | Motor de automatización y workflows |
| **Supabase local (Docker)** | PostgreSQL + Studio (o Supabase Cloud free) |
| `/data/inbox` | Archivos de entrada (CSV/JSON para carga masiva) |
| `/data/outbox` | Notificaciones locales (TXT/JSON) |
| `/data/reports` | Reportes generados (CSV/HTML) |
| `/data/logs` | Logs adicionales de error |

> **Nota:** Si no se cuenta con Supabase local, se puede usar **Supabase Cloud (plan free)**. La recomendación del curso es local.

### 4.2 Configuración Docker (`docker-compose.yml`)

```yaml
version: '3.8'
services:
  n8n:
    image: n8nio/n8n
    ports:
      - "5678:5678"
    env_file: .env
    volumes:
      - n8n_data:/home/node/.n8n
      - ./data:/data
    depends_on:
      - supabase-db

  supabase-db:
    image: supabase/postgres:15.1.0.147
    ports:
      - "5432:5432"
    env_file: .env
    volumes:
      - supabase_data:/var/lib/postgresql/data

volumes:
  n8n_data:
  supabase_data:
```

### 4.3 Flujo general

```
[Webhook POST]──┐
[Archivo CSV]───┼──▶ WF1 Ingesta / Préstamos / Devoluciones
                │         │
                │    [productos] [movimientos] [préstamos] [audit_log]
                │
                └──── WF2 Procesamiento (Cron cada 5 min)
                           │
                      [alertas] [audit_log]
                           │
                       WF3 Salida (Cron semanal)
                           │
                      /data/reports  /data/outbox  [audit_log]
                           │
                       WF4 Error Handler (Error Trigger)
                           │
                      [error_log]  /data/logs/errors.log
```

---

## 5. Modelo de datos (Supabase / PostgreSQL)

> Esquema: `public`

### 5.1 Tablas principales

#### A) `productos`
| Campo | Tipo | Restricción |
|---|---|---|
| `id` | uuid | PK, default gen_random_uuid() |
| `sku` | text | UNIQUE, NOT NULL |
| `nombre` | text | NOT NULL |
| `categoria` | text | NOT NULL |
| `stock_actual` | int | NOT NULL, default 0 |
| `stock_minimo` | int | NOT NULL, default 0 |
| `fecha_vencimiento` | date | NULL |
| `activo` | boolean | default true |
| `created_at` | timestamptz | default now() |

#### B) `movimientos`
| Campo | Tipo | Descripción |
|---|---|---|
| `id` | uuid | PK |
| `producto_id` | uuid | FK → productos.id |
| `tipo` | text | `ENTRADA \| SALIDA \| AJUSTE` |
| `cantidad` | int | NOT NULL |
| `origen` | text | `WEBHOOK \| ARCHIVO \| MANUAL` |
| `referencia` | text | Opcional (ej. "Préstamo #001") |
| `created_at` | timestamptz | default now() |

> **Regla:** Todo préstamo genera un movimiento `SALIDA`; toda devolución genera un movimiento `ENTRADA`.

#### C) `prestamos`
| Campo | Tipo | Descripción |
|---|---|---|
| `id` | uuid | PK |
| `producto_id` | uuid | FK → productos.id |
| `solicitante` | text | NOT NULL |
| `cantidad` | int | NOT NULL |
| `fecha_prestamo` | date | NOT NULL |
| `fecha_devolucion` | date | Fecha comprometida de devolución |
| `devuelto` | boolean | default false |
| `fecha_devolucion_real` | date | NULL (se llena al devolver) |
| `created_at` | timestamptz | default now() |

#### D) `alertas`
| Campo | Tipo | Descripción |
|---|---|---|
| `id` | uuid | PK |
| `tipo` | text | `STOCK_BAJO \| VENCIMIENTO_PROXIMO \| PRESTAMO_VENCIDO \| ERROR` |
| `nivel` | text | `INFO \| WARNING \| CRITICAL` |
| `mensaje` | text | Descripción legible |
| `producto_id` | uuid | NULL (si aplica) |
| `prestamo_id` | uuid | NULL (si aplica) |
| `resuelta` | boolean | default false |
| `created_at` | timestamptz | default now() |

### 5.2 Bitácoras

#### E) `audit_log`
| Campo | Tipo | Descripción |
|---|---|---|
| `id` | uuid | PK |
| `workflow` | text | Nombre del workflow |
| `accion` | text | Acción realizada |
| `detalle` | text | Descripción del evento |
| `payload_resumen` | jsonb | NULL (datos del evento) |
| `created_at` | timestamptz | default now() |

#### F) `error_log`
| Campo | Tipo | Descripción |
|---|---|---|
| `id` | uuid | PK |
| `workflow` | text | Workflow donde ocurrió el error |
| `paso` | text | Nodo o paso del error |
| `error_msg` | text | Mensaje de error |
| `payload` | jsonb | Payload que causó el error |
| `created_at` | timestamptz | default now() |

---

## 6. Workflows en n8n (mínimo 3 + 1 recomendado)

> Se utilizarán **mínimo 6 nodos distintos** por workflow principal y manejo de errores con Error Trigger o ramas IF.

---

### Workflow 1 — INGESTA, PRÉSTAMOS Y DEVOLUCIONES
**Nombre:** `WF1_Ingesta_Inventario`  
**Trigger:** Webhook POST

El WF1 maneja tres operaciones según el campo `tipo_evento`:

| `tipo_evento` | Operación |
|---|---|
| `ENTRADA` | Sumar stock + INSERT movimiento ENTRADA |
| `PRESTAMO` | Validar stock → restar stock + INSERT préstamo + INSERT movimiento SALIDA |
| `DEVOLUCION` | Sumar stock + UPDATE préstamo (devuelto=true) + INSERT movimiento ENTRADA |

**Endpoints:**
- `POST /webhook/inventory/intake` → entrada de stock o producto nuevo
- `POST /webhook/inventory/loan` → registro de préstamo
- `POST /webhook/inventory/return` → devolución de préstamo

**Nodos (mínimo):**
1. **Webhook** (POST)
2. **Set** — normalizar campos (sku, cantidad, tipo_evento, solicitante, prestamo_id…)
3. **IF** — validación: campos requeridos presentes / cantidad > 0
4. **Switch** — ramificar por `tipo_evento` (ENTRADA / PRESTAMO / DEVOLUCION)
5. **Code** — construir objeto final + calcular nuevo stock
6. **PostgreSQL** — UPSERT producto + UPDATE stock
7. **PostgreSQL** — INSERT movimiento (ENTRADA o SALIDA según evento)
8. **PostgreSQL** — INSERT/UPDATE préstamo (si aplica)
9. **PostgreSQL** — INSERT audit_log
10. **Respond to Webhook** — respuesta OK / error 400

**Reglas clave:**
- Si `sku` no existe → crear producto automáticamente.
- Si `tipo_evento = PRESTAMO` y `cantidad > stock_actual` → rechazar y registrar en `error_log`.
- Si payload inválido → INSERT `error_log` + responder HTTP 400.

**Salidas verificables:**
- Registros en `productos`, `movimientos`, `prestamos`
- Registro en `audit_log`
- Respuesta HTTP del Webhook (200 OK o 400 Error)

---

### Workflow 2 — PROCESAMIENTO DE REGLAS Y ALERTAS
**Nombre:** `WF2_Procesamiento_Reglas_Alertas`  
**Trigger:** Cron (cada 5 minutos)

**Objetivo:** Evaluar el estado del inventario y préstamos para generar alertas automáticas sin repeticiones.

**Nodos:**
1. **Cron** (cada 5 min)
2. **PostgreSQL** — SELECT productos activos
3. **Split In Batches** — procesar producto por producto
4. **IF** — `stock_actual <= stock_minimo` → alerta STOCK_BAJO
5. **IF** — `fecha_vencimiento <= now() + N_DIAS_VENCIMIENTO` → alerta VENCIMIENTO_PROXIMO
6. **PostgreSQL** — INSERT alertas (con deduplicación, ver abajo)
7. **PostgreSQL** — SELECT préstamos no devueltos con fecha vencida
8. **IF** — `fecha_devolucion < hoy` → alerta PRESTAMO_VENCIDO
9. **PostgreSQL** — INSERT alertas (con deduplicación)
10. **PostgreSQL** — INSERT audit_log

**Deduplicación de alertas (query antes de INSERT):**
```sql
SELECT id FROM alertas
WHERE producto_id = $1
  AND tipo = $2
  AND resuelta = false
  AND created_at > now() - interval '24 hours'
LIMIT 1;
```
Si retorna filas → NO insertar. Solo insertamos si no existe alerta reciente.

**Parámetros configurables (variables de entorno o n8n vars):**
- `N_DIAS_VENCIMIENTO` (ej. 15 días)

---

### Workflow 3 — SALIDA Y REPORTES
**Nombre:** `WF3_Salida_Reportes`  
**Trigger:** Cron semanal (ej. lunes 08:00)

**Objetivo:** Generar reporte CSV/HTML del inventario y alertas de la semana, guardar localmente y registrar en auditoría.

**Nodos:**
1. **Cron** (semanal)
2. **PostgreSQL** — SELECT inventario completo (stock, alertas activas)
3. **PostgreSQL** — SELECT alertas última semana
4. **Code** — formatear datos como CSV/HTML
5. **Write Binary File** — guardar `./data/reports/reporte_inventario_YYYY-MM-DD.csv`
6. **Write Binary File** — guardar `./data/outbox/notificacion_reporte.txt`
7. **PostgreSQL** — INSERT audit_log
8. **IF (rama error)** — si algún paso falla → INSERT error_log + escribir en `/data/logs/errors.log`

**Salidas verificables:**
- Archivo CSV en `/data/reports`
- Archivo TXT en `/data/outbox`
- Registro en `audit_log`

---

### Workflow 4 (Recomendado) — MANEJADOR DE ERRORES GLOBAL
**Nombre:** `WF4_Error_Handler`  
**Trigger:** Error Trigger (captura errores de cualquier otro workflow)

**Nodos:**
1. **Error Trigger**
2. **Code** — extraer workflow, nodo, mensaje de error y payload del contexto del error
3. **PostgreSQL** — INSERT `error_log`
4. **Write Binary File** — append a `/data/logs/errors.log`

---

## 7. Manejo de errores

| Estrategia | Descripción |
|---|---|
| **Error Trigger (WF4)** | Captura errores no controlados de cualquier workflow |
| **Ramas IF internas** | Validaciones de negocio dentro de WF1 (payload inválido, stock insuficiente) |
| **error_log (tabla)** | Persistencia de todos los errores con payload original |
| **errors.log (archivo)** | Evidencia de errores en sistema de archivos |
| **Respuesta HTTP 400** | En WF1 (Webhook), respuesta controlada al cliente |

---

## 8. Seguridad

### 8.1 Variables de entorno (`.env`)
```
N8N_ENCRYPTION_KEY=tu_clave_secreta
SUPABASE_DB_HOST=localhost
SUPABASE_DB_PORT=5432
SUPABASE_DB_NAME=postgres
SUPABASE_DB_USER=postgres
SUPABASE_DB_PASSWORD=tu_password
N_DIAS_VENCIMIENTO=15
```

### 8.2 Buenas prácticas
- Credenciales configuradas en n8n como **Credentials** (nunca hardcodeadas en nodos).
- `.env` incluido en `.gitignore`.
- Validación de entradas en cada workflow antes de persistir.

---

## 9. Pruebas (evidencia obligatoria)

### 9.1 Casos de prueba

| # | Tipo | Descripción | Resultado esperado |
|---|------|-------------|--------------------|
| 1 | ✅ Válida | Registrar producto nuevo (ENTRADA, cantidad 50) | Producto creado, movimiento ENTRADA insertado |
| 2 | ✅ Válida | Entrada adicional a producto existente (cantidad 30) | stock_actual += 30, movimiento ENTRADA |
| 3 | ✅ Válida | Préstamo válido (cantidad <= stock disponible) | Préstamo creado, stock -= cantidad, movimiento SALIDA |
| 4 | ✅ Válida | Devolución de préstamo | devuelto=true, fecha_devolucion_real=hoy, stock += cantidad |
| 5 | ❌ Inválida | Payload sin `sku` | HTTP 400, registro en error_log |
| 6 | ❌ Inválida | Cantidad negativa o 0 | HTTP 400, registro en error_log |
| 7 | ❌ Inválida | Préstamo con cantidad > stock disponible | Rechazado, HTTP 400, registro en error_log |
| 8 | ⚙️ Regla | Stock bajo genera alerta | INSERT en alertas (STOCK_BAJO, sin duplicar en 24h) |
| 9 | ⚙️ Regla | Vencimiento próximo genera alerta | INSERT en alertas (VENCIMIENTO_PROXIMO) |
| 10 | ⚙️ Regla | Préstamo vencido genera alerta | INSERT en alertas (PRESTAMO_VENCIDO) |

### 9.2 Evidencia requerida
- Capturas de ejecución exitosa en n8n (vista de runs / nodos verdes).
- Capturas de tablas en Supabase Studio (`productos`, `movimientos`, `alertas`, `audit_log`, `error_log`).
- Archivos generados en `/data/reports` y `/data/outbox`.
- Capturas de respuestas HTTP (Postman o similar) para casos válidos e inválidos.

---
