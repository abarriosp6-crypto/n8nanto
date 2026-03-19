# AGENTS.md - Sistema de Control de Inventario Inteligente (n8n + Supabase)

Guía para agentes de código que trabajan en este repositorio.

## Descripción del Proyecto

Sistema de automatización de inventario usando **n8n workflows** con **PostgreSQL (Supabase)** como base de datos.
Gestiona entradas y salidas de productos (ventas, consumos internos, donaciones, mermas) y genera alertas automáticas por stock bajo y vencimientos próximos.

## Estructura del Proyecto

```
n8n/
├── bd/                        # Scripts SQL de base de datos
│   └── bd.sql                 # Schema completo (tablas, índices, vistas) + datos de prueba
├── data/                      # Archivos de entrada/salida
│   ├── inbox/                 # Archivos CSV/JSON de entrada
│   ├── outbox/                # Notificaciones generadas
│   ├── reports/               # Reportes CSV/HTML semanales
│   └── logs/                  # Logs de errores
├── workflows/                 # Workflows de n8n (formato JSON)
│   ├── WF1_Ingesta_Inventario.json
│   ├── WF2_Procesamiento_Reglas_Alertas.json
│   ├── WF3_Salida_Reportes.json
│   └── WF4_Error_Handler.json
├── n8n_data/                  # Volumen de datos de n8n
├── docker-compose.yml         # Configuración Docker
├── .env                       # Variables de entorno (NO COMMITEAR)
└── plan.md                    # Documentación del proyecto
```

## Comandos de Build/Lint/Test

### Docker & Deployment

```bash
# Iniciar todos los servicios (n8n + PostgreSQL)
docker-compose up -d

# Ver logs de n8n
docker-compose logs -f n8n

# Detener servicios
docker-compose down

# Reiniciar n8n sin perder datos
docker-compose restart n8n

# Reconstruir imágenes
docker-compose up -d --build
```

### Base de Datos

```bash
# Conectarse a PostgreSQL (desde host)
psql -h localhost -p 5432 -U postgres -d postgres

# Ejecutar schema inicial (incluye datos de prueba)
psql -h localhost -p 5432 -U postgres -d postgres -f bd/bd.sql

# Backup de base de datos
docker-compose exec supabase-db pg_dump -U postgres > backup.sql
```

### Workflows de n8n

```bash
# Acceder a la interfaz de n8n
http://localhost:5678

# Importar workflows (desde UI de n8n)
# Settings > Import from File > seleccionar workflows/*.json

# Exportar workflows modificados (desde UI de n8n)
# En cada workflow: ... > Download > guardar en workflows/
```

### Testing Manual

```bash
# Test WF1 - Entrada de producto (usando curl)
curl -X POST http://localhost:5678/webhook/inventory/intake \
  -H "Content-Type: application/json" \
  -d '{"tipo_evento":"ENTRADA","sku":"TEST001","nombre":"Producto Test","categoria":"Prueba","cantidad":50,"stock_minimo":10}'

# Test WF1 - Salida por VENTA
curl -X POST http://localhost:5678/webhook/inventory/intake \
  -H "Content-Type: application/json" \
  -d '{"tipo_evento":"SALIDA","sku":"TEST001","cantidad":5,"tipo_salida":"VENTA","destinatario":"Cliente ABC","precio_unitario":25.50,"referencia":"Ticket #001"}'

# Test WF1 - Salida por CONSUMO_INTERNO
curl -X POST http://localhost:5678/webhook/inventory/intake \
  -H "Content-Type: application/json" \
  -d '{"tipo_evento":"SALIDA","sku":"TEST001","cantidad":2,"tipo_salida":"CONSUMO_INTERNO","destinatario":"Área de Enfermería","referencia":"Uso clínica"}'

# Test WF1 - Salida por MERMA
curl -X POST http://localhost:5678/webhook/inventory/intake \
  -H "Content-Type: application/json" \
  -d '{"tipo_evento":"SALIDA","sku":"TEST001","cantidad":3,"tipo_salida":"MERMA","referencia":"Producto vencido"}'

# Verificar logs de n8n
docker-compose logs -f n8n | grep -i error
```

## Modelo de Datos (PostgreSQL)

### Tablas Principales

- **productos**: SKU, nombre, categoría, stock_actual, stock_minimo, fecha_vencimiento
- **movimientos**: Registra ENTRADA, SALIDA, AJUSTE de stock
- **salidas**: Detalle de salidas (tipo_salida, destinatario, precio_unitario, total, referencia)
- **alertas**: STOCK_BAJO, VENCIMIENTO_PROXIMO, ERROR
- **audit_log**: Bitácora de todas las operaciones
- **error_log**: Registro de errores con payload completo

### Vistas Útiles

- `v_inventario_alertas`: Inventario actual con estado (STOCK_BAJO, VENCIMIENTO_PROXIMO, OK)
- `v_salidas_hoy`: Salidas registradas en el día actual

## Estilo de Código y Convenciones

### Workflows n8n (JSON)

**Naming Conventions:**
- Workflows: `WF{número}_{Descripción}` (ej: `WF1_Ingesta_Inventario`)
- Nodos: Nombres descriptivos en español (ej: `Normalizar Campos`, `Validar Entrada`)
- IDs de nodos: kebab-case (ej: `webhook-node`, `set-normalize`)

**Estructura de Nodos:**
- Usar `Set` para normalizar y transformar datos al inicio
- Usar `IF` para validaciones de negocio
- Usar `Switch` para ramificar por tipo de evento
- Usar `Code` para lógica compleja (JavaScript)
- Siempre incluir manejo de errores (Error Trigger o ramas IF)

**Expresiones n8n:**
```javascript
// Normalizar strings
={{ $json.body.sku?.toString().trim().toUpperCase() }}

// Valores por defecto
={{ $json.body.categoria ?? 'General' }}

// Conversión de tipos
={{ Number($json.body.cantidad) }}

// Fechas
={{ $now.toISO() }}
={{ $json.fecha_vencimiento ?? null }}
```

### SQL (PostgreSQL)

**Naming Conventions:**
- Tablas: snake_case, plural (ej: `productos`, `movimientos`)
- Columnas: snake_case (ej: `stock_actual`, `fecha_vencimiento`)
- PKs: siempre `id UUID DEFAULT gen_random_uuid()`
- FKs: `{tabla}_id` (ej: `producto_id`, `salida_id`)
- Índices: `idx_{tabla}_{columna}` (ej: `idx_productos_sku`)
- Vistas: `v_{descripción}` (ej: `v_inventario_alertas`)

**Constraints:**
```sql
-- CHECK constraints para valores permitidos
CHECK (tipo IN ('ENTRADA', 'SALIDA', 'AJUSTE'))
CHECK (tipo_salida IN ('VENTA', 'CONSUMO_INTERNO', 'DONACION', 'MERMA', 'OTRO'))
CHECK (nivel IN ('INFO', 'WARNING', 'CRITICAL'))

-- NOT NULL en campos críticos
sku TEXT UNIQUE NOT NULL
cantidad INTEGER NOT NULL

-- Columnas generadas
total NUMERIC(10,2) GENERATED ALWAYS AS (cantidad * precio_unitario) STORED

-- Timestamps automáticos
created_at TIMESTAMPTZ DEFAULT now()
updated_at TIMESTAMPTZ DEFAULT now()
```

**Queries desde n8n:**
- Usar queries parametrizadas para evitar SQL injection
- Incluir índices en todas las columnas de filtrado frecuente
- Usar `RETURNING *` en INSERT/UPDATE para obtener el registro completo

### Variables de Entorno (.env)

**Requeridas:**
```bash
# n8n
N8N_ENCRYPTION_KEY=tu_clave_secreta_minimo_32_caracteres
N8N_HOST=localhost
N8N_PORT=5678
N8N_PROTOCOL=http

# PostgreSQL
SUPABASE_DB_HOST=localhost
SUPABASE_DB_PORT=5432
SUPABASE_DB_NAME=postgres
SUPABASE_DB_USER=postgres
SUPABASE_DB_PASSWORD=tu_password_seguro

# Configuración de negocio
N_DIAS_VENCIMIENTO=15
GENERIC_TIMEZONE=America/Guatemala
```

**Seguridad:**
- NUNCA commitear `.env` al repositorio (incluir en `.gitignore`)
- Usar credenciales de n8n para almacenar conexiones DB
- No hardcodear credenciales en workflows

### Manejo de Errores

**Estrategia Global:**
1. **Error Trigger (WF4)**: Captura errores no manejados de cualquier workflow
2. **Validaciones IF**: Validar payload antes de procesar (campos requeridos, rangos)
3. **Logging Dual**: Insertar en `error_log` (DB) + escribir en `/data/logs/errors.log`
4. **Respuestas HTTP**: Retornar 400 con mensaje descriptivo en webhooks

**Ejemplo de Validación:**
```javascript
// En nodo IF
{{ $json.sku && $json.cantidad > 0 && $json.tipo_evento }}
```

**Ejemplo de Error Log:**
```sql
INSERT INTO error_log (workflow, paso, error_msg, payload)
VALUES ($1, $2, $3, $4::jsonb)
RETURNING *;
```

## Workflows Principales

### WF1: Ingesta de Inventario (Entrada/Salida)
- **Trigger**: Webhook POST `/webhook/inventory/intake`
- **Eventos**: ENTRADA, SALIDA
- **Validaciones**: Campos requeridos, cantidad > 0, stock disponible
- **Salidas**: Registros en productos, movimientos, salidas, audit_log

### WF2: Procesamiento de Reglas y Alertas
- **Trigger**: Cron cada 5 minutos
- **Reglas**: Stock bajo, vencimiento próximo
- **Deduplicación**: No duplicar alertas en últimas 24h
- **Salidas**: Registros en alertas, audit_log

### WF3: Salida y Reportes
- **Trigger**: Cron semanal (lunes 08:00)
- **Genera**: CSV de inventario completo, alertas activas
- **Ubicación**: `/data/reports/reporte_inventario_YYYY-MM-DD.csv`
- **Salidas**: Archivos + registros en audit_log

### WF4: Error Handler
- **Trigger**: Error Trigger (global)
- **Captura**: Errores no manejados de WF1, WF2, WF3
- **Salidas**: error_log (DB) + `/data/logs/errors.log`

## Reglas de Negocio Críticas

1. **Stock Negativo**: NUNCA permitir `stock_actual < 0`
2. **Salidas**: Solo si `cantidad <= stock_actual`
3. **Alertas**: Deduplicar por producto/tipo en últimas 24h
4. **SKU**: Siempre UPPERCASE, único, no nulo
5. **Tipos de Salida**: VENTA, CONSUMO_INTERNO, DONACION, MERMA, OTRO
6. **Audit Trail**: Registrar TODAS las operaciones en `audit_log`

## Debugging y Troubleshooting

```bash
# Ver ejecuciones en n8n UI
http://localhost:5678 > Executions

# Verificar estado de workflows
SELECT workflow, accion, COUNT(*) 
FROM audit_log 
WHERE created_at > now() - interval '1 day'
GROUP BY workflow, accion;

# Ver errores recientes
SELECT * FROM error_log 
ORDER BY created_at DESC 
LIMIT 10;

# Verificar alertas activas
SELECT tipo, nivel, COUNT(*) 
FROM alertas 
WHERE resuelta = false 
GROUP BY tipo, nivel;
```

## Notas para Agentes

- Este es un proyecto de n8n workflows, NO un proyecto Node.js tradicional
- No hay package.json en raíz (solo en n8n_data/nodes para nodos personalizados)
- Los "tests" se ejecutan enviando requests HTTP y verificando DB
- La UI de n8n es la herramienta principal de desarrollo
- Siempre verificar logs en DB (audit_log, error_log) además de logs Docker
- Documentar cambios en workflows exportando JSON actualizado
