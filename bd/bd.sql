-- Sistema de Control de Inventario Inteligente
-- Base de datos PostgreSQL (Supabase)
-- Fecha: 02/03/2026

-- ============================================
-- TABLA: productos
-- ============================================
CREATE TABLE IF NOT EXISTS public.productos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sku TEXT UNIQUE NOT NULL,
    nombre TEXT NOT NULL,
    categoria TEXT NOT NULL,
    stock_actual INTEGER NOT NULL DEFAULT 0,
    stock_minimo INTEGER NOT NULL DEFAULT 0,
    fecha_vencimiento DATE NULL,
    activo BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Índices para productos
CREATE INDEX IF NOT EXISTS idx_productos_sku ON public.productos(sku);
CREATE INDEX IF NOT EXISTS idx_productos_activo ON public.productos(activo);
CREATE INDEX IF NOT EXISTS idx_productos_fecha_vencimiento ON public.productos(fecha_vencimiento);

-- ============================================
-- TABLA: movimientos
-- ============================================
CREATE TABLE IF NOT EXISTS public.movimientos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    producto_id UUID NOT NULL REFERENCES public.productos(id) ON DELETE CASCADE,
    tipo TEXT NOT NULL CHECK (tipo IN ('ENTRADA', 'SALIDA', 'AJUSTE')),
    cantidad INTEGER NOT NULL,
    origen TEXT NOT NULL CHECK (origen IN ('WEBHOOK', 'ARCHIVO', 'MANUAL')),
    referencia TEXT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Índices para movimientos
CREATE INDEX IF NOT EXISTS idx_movimientos_producto_id ON public.movimientos(producto_id);
CREATE INDEX IF NOT EXISTS idx_movimientos_tipo ON public.movimientos(tipo);
CREATE INDEX IF NOT EXISTS idx_movimientos_created_at ON public.movimientos(created_at);

-- ============================================
-- TABLA: salidas
-- ============================================
CREATE TABLE IF NOT EXISTS public.salidas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    producto_id UUID NOT NULL REFERENCES public.productos(id) ON DELETE CASCADE,
    tipo_salida TEXT NOT NULL CHECK (tipo_salida IN ('VENTA', 'CONSUMO_INTERNO', 'DONACION', 'MERMA', 'OTRO')),
    destinatario TEXT NULL,                        -- cliente, área, institución, etc.
    cantidad INTEGER NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(10,2) NULL DEFAULT 0,  -- opcional, solo aplica para ventas
    total NUMERIC(10,2) GENERATED ALWAYS AS (cantidad * precio_unitario) STORED,
    origen TEXT NOT NULL CHECK (origen IN ('WEBHOOK', 'ARCHIVO', 'MANUAL')),
    referencia TEXT NULL,                          -- ticket, factura, nota, etc.
    fecha_salida DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Índices para salidas
CREATE INDEX IF NOT EXISTS idx_salidas_producto_id ON public.salidas(producto_id);
CREATE INDEX IF NOT EXISTS idx_salidas_tipo_salida ON public.salidas(tipo_salida);
CREATE INDEX IF NOT EXISTS idx_salidas_fecha_salida ON public.salidas(fecha_salida);
CREATE INDEX IF NOT EXISTS idx_salidas_destinatario ON public.salidas(destinatario);
CREATE INDEX IF NOT EXISTS idx_salidas_created_at ON public.salidas(created_at);

-- ============================================
-- TABLA: alertas
-- ============================================
CREATE TABLE IF NOT EXISTS public.alertas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tipo TEXT NOT NULL CHECK (tipo IN ('STOCK_BAJO', 'VENCIMIENTO_PROXIMO', 'ERROR')),
    nivel TEXT NOT NULL CHECK (nivel IN ('INFO', 'WARNING', 'CRITICAL')),
    mensaje TEXT NOT NULL,
    producto_id UUID NULL REFERENCES public.productos(id) ON DELETE CASCADE,
    salida_id UUID NULL REFERENCES public.salidas(id) ON DELETE CASCADE,
    resuelta BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Índices para alertas
CREATE INDEX IF NOT EXISTS idx_alertas_tipo ON public.alertas(tipo);
CREATE INDEX IF NOT EXISTS idx_alertas_nivel ON public.alertas(nivel);
CREATE INDEX IF NOT EXISTS idx_alertas_producto_id ON public.alertas(producto_id);
CREATE INDEX IF NOT EXISTS idx_alertas_salida_id ON public.alertas(salida_id);
CREATE INDEX IF NOT EXISTS idx_alertas_resuelta ON public.alertas(resuelta);
CREATE INDEX IF NOT EXISTS idx_alertas_created_at ON public.alertas(created_at);

-- ============================================
-- TABLA: audit_log
-- ============================================
CREATE TABLE IF NOT EXISTS public.audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workflow TEXT NOT NULL,
    accion TEXT NOT NULL,
    detalle TEXT NOT NULL,
    payload_resumen JSONB NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Índices para audit_log
CREATE INDEX IF NOT EXISTS idx_audit_log_workflow ON public.audit_log(workflow);
CREATE INDEX IF NOT EXISTS idx_audit_log_accion ON public.audit_log(accion);
CREATE INDEX IF NOT EXISTS idx_audit_log_created_at ON public.audit_log(created_at);

-- ============================================
-- TABLA: error_log
-- ============================================
CREATE TABLE IF NOT EXISTS public.error_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workflow TEXT NOT NULL,
    paso TEXT NOT NULL,
    error_msg TEXT NOT NULL,
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Índices para error_log
CREATE INDEX IF NOT EXISTS idx_error_log_workflow ON public.error_log(workflow);
CREATE INDEX IF NOT EXISTS idx_error_log_paso ON public.error_log(paso);
CREATE INDEX IF NOT EXISTS idx_error_log_created_at ON public.error_log(created_at);

-- ============================================
-- VISTAS ÚTILES (OPCIONAL)
-- ============================================

-- Vista: Inventario actual con alertas
CREATE OR REPLACE VIEW public.v_inventario_alertas AS
SELECT 
    p.id,
    p.sku,
    p.nombre,
    p.categoria,
    p.stock_actual,
    p.stock_minimo,
    p.fecha_vencimiento,
    CASE 
        WHEN p.stock_actual <= p.stock_minimo THEN 'STOCK_BAJO'
        WHEN p.fecha_vencimiento IS NOT NULL AND p.fecha_vencimiento <= CURRENT_DATE + INTERVAL '15 days' THEN 'VENCIMIENTO_PROXIMO'
        ELSE 'OK'
    END AS estado,
    p.created_at
FROM public.productos p
WHERE p.activo = true
ORDER BY p.sku;

-- Vista: Salidas del día
CREATE OR REPLACE VIEW public.v_salidas_hoy AS
SELECT 
    s.id,
    s.producto_id,
    p.sku,
    p.nombre,
    s.tipo_salida,
    s.destinatario,
    s.cantidad,
    s.precio_unitario,
    s.total,
    s.fecha_salida,
    s.origen,
    s.referencia
FROM public.salidas s
JOIN public.productos p ON s.producto_id = p.id
WHERE s.fecha_salida = CURRENT_DATE
ORDER BY s.created_at DESC;

-- ============================================
-- COMENTARIOS DESCRIPTIVOS
-- ============================================
COMMENT ON TABLE public.productos IS 'Almacena los productos del inventario (medicamentos, insumos)';
COMMENT ON TABLE public.movimientos IS 'Registra entradas, salidas y ajustes de stock';
COMMENT ON TABLE public.salidas IS 'Registra las salidas de stock: ventas, consumos internos, donaciones, mermas, etc.';
COMMENT ON TABLE public.alertas IS 'Alertas automáticas generadas por el sistema';
COMMENT ON TABLE public.audit_log IS 'Bitácora de auditoría de todas las operaciones';
COMMENT ON TABLE public.error_log IS 'Registro de errores del sistema';

COMMENT ON COLUMN public.productos.sku IS 'Código único del producto (SKU / código de barras)';
COMMENT ON COLUMN public.productos.stock_actual IS 'Cantidad disponible actualmente';
COMMENT ON COLUMN public.productos.stock_minimo IS 'Nivel mínimo que genera alerta de reposición';
COMMENT ON COLUMN public.movimientos.tipo IS 'ENTRADA: reposición de stock, SALIDA: descuento por salida, AJUSTE: corrección';
COMMENT ON COLUMN public.movimientos.origen IS 'Fuente del movimiento: webhook, archivo o manual';
COMMENT ON COLUMN public.salidas.tipo_salida IS 'VENTA: venta a cliente, CONSUMO_INTERNO: uso interno, DONACION, MERMA: producto dañado/vencido, OTRO';
COMMENT ON COLUMN public.salidas.total IS 'Total calculado automáticamente: cantidad * precio_unitario (0 si no aplica precio)';
COMMENT ON COLUMN public.alertas.nivel IS 'INFO: informativo, WARNING: atención, CRITICAL: urgente';

-- ============================================================
-- SEED DATA — Datos de prueba iniciales
-- Ejecutar después de las secciones anteriores
-- ============================================================

-- ============================================================
-- A) PRODUCTOS
-- ============================================================
INSERT INTO public.productos (id, sku, nombre, categoria, stock_actual, stock_minimo, fecha_vencimiento, activo)
VALUES
  ('a1000000-0000-0000-0000-000000000001', 'AMOX-500',    'Amoxicilina 500mg (caja 20)',       'Antibióticos',   150, 50,  '2027-06-30', true),
  ('a1000000-0000-0000-0000-000000000002', 'IBUP-400',    'Ibuprofeno 400mg (caja 30)',        'Analgésicos',    200, 80,  '2026-12-31', true),
  ('a1000000-0000-0000-0000-000000000003', 'PARA-500',    'Paracetamol 500mg (caja 50)',       'Analgésicos',    30,  40,  '2026-04-15', true),  -- stock bajo
  ('a1000000-0000-0000-0000-000000000004', 'METF-850',    'Metformina 850mg (caja 30)',        'Antidiabéticos', 90,  30,  '2027-01-15', true),
  ('a1000000-0000-0000-0000-000000000005', 'LORAT-10',    'Loratadina 10mg (caja 20)',         'Antialérgicos',  60,  25,  NULL,         true),
  ('a1000000-0000-0000-0000-000000000006', 'VENC-TEST',   'Producto próximo a vencer',        'Prueba',         20,  5,   '2026-03-10', true),  -- stock bajo + vencimiento próximo
  ('a1000000-0000-0000-0000-000000000007', 'ALCOHOL-70',  'Alcohol isopropílico 70% (1L)',    'Insumos',        80,  20,  '2026-09-30', true),
  ('a1000000-0000-0000-0000-000000000008', 'JERINGAS-5',  'Jeringas 5ml (caja 100)',          'Insumos',        500, 100, NULL,         true);


-- ============================================================
-- B) MOVIMIENTOS (entradas iniciales de stock)
-- ============================================================
INSERT INTO public.movimientos (id, producto_id, tipo, cantidad, origen, referencia)
VALUES
  ('b1000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'ENTRADA', 150, 'MANUAL',  'Carga inicial'),
  ('b1000000-0000-0000-0000-000000000002', 'a1000000-0000-0000-0000-000000000002', 'ENTRADA', 200, 'MANUAL',  'Carga inicial'),
  ('b1000000-0000-0000-0000-000000000003', 'a1000000-0000-0000-0000-000000000003', 'ENTRADA', 50,  'ARCHIVO', 'Compra #101'),
  ('b1000000-0000-0000-0000-000000000004', 'a1000000-0000-0000-0000-000000000006', 'ENTRADA', 20,  'WEBHOOK', 'Pedido #202'),
  ('b1000000-0000-0000-0000-000000000005', 'a1000000-0000-0000-0000-000000000008', 'ENTRADA', 500, 'WEBHOOK', 'Pedido #303'),
  -- Salidas ya registradas
  ('b1000000-0000-0000-0000-000000000006', 'a1000000-0000-0000-0000-000000000003', 'SALIDA',  20,  'WEBHOOK', 'Venta #001'),
  ('b1000000-0000-0000-0000-000000000007', 'a1000000-0000-0000-0000-000000000006', 'SALIDA',  10,  'WEBHOOK', 'Consumo interno'),
  -- Ajuste de inventario
  ('b1000000-0000-0000-0000-000000000008', 'a1000000-0000-0000-0000-000000000003', 'AJUSTE',  -5,  'MANUAL',  'Corrección conteo físico');


-- ============================================================
-- C) SALIDAS (ventas, consumos, donaciones, mermas)
-- ============================================================
INSERT INTO public.salidas (id, producto_id, tipo_salida, destinatario, cantidad, precio_unitario, origen, referencia, fecha_salida)
VALUES
  -- Venta mostrador (cliente anónimo)
  ('c1000000-0000-0000-0000-000000000001',
   'a1000000-0000-0000-0000-000000000002',
   'VENTA', NULL, 2, 15.50, 'WEBHOOK', 'Ticket #001', '2026-03-01'),

  -- Venta con cliente registrado
  ('c1000000-0000-0000-0000-000000000002',
   'a1000000-0000-0000-0000-000000000001',
   'VENTA', 'María López', 1, 45.00, 'WEBHOOK', 'Ticket #002', '2026-03-01'),

  -- Consumo interno (sin precio)
  ('c1000000-0000-0000-0000-000000000003',
   'a1000000-0000-0000-0000-000000000007',
   'CONSUMO_INTERNO', 'Área de enfermería', 5, 0, 'MANUAL', 'Uso clínica', '2026-03-02'),

  -- Merma por vencimiento
  ('c1000000-0000-0000-0000-000000000004',
   'a1000000-0000-0000-0000-000000000006',
   'MERMA', NULL, 10, 0, 'MANUAL', 'Producto vencido dado de baja', '2026-03-02');


-- ============================================================
-- D) ALERTAS
-- ============================================================
INSERT INTO public.alertas (id, tipo, nivel, mensaje, producto_id, salida_id, resuelta)
VALUES
  -- Stock bajo (PARA-500: stock=30 < minimo=40)
  ('d1000000-0000-0000-0000-000000000001',
   'STOCK_BAJO', 'CRITICAL',
   'Stock de Paracetamol 500mg por debajo del mínimo. Actual: 30 | Mínimo: 40',
   'a1000000-0000-0000-0000-000000000003', NULL, false),

  -- Stock bajo + vencimiento próximo (VENC-TEST)
  ('d1000000-0000-0000-0000-000000000002',
   'STOCK_BAJO', 'WARNING',
   'Stock bajo de Producto próximo a vencer. Actual: 20 | Mínimo: 5',
   'a1000000-0000-0000-0000-000000000006', NULL, false),

  -- Vencimiento próximo (VENC-TEST vence 2026-03-10, ~7 días)
  ('d1000000-0000-0000-0000-000000000003',
   'VENCIMIENTO_PROXIMO', 'CRITICAL',
   'Producto próximo a vencer vence en 7 días (2026-03-10). Revisar existencias.',
   'a1000000-0000-0000-0000-000000000006', NULL, false),

  -- Vencimiento próximo (PARA-500 vence 2026-04-15, ~43 días)
  ('d1000000-0000-0000-0000-000000000004',
   'VENCIMIENTO_PROXIMO', 'INFO',
   'Paracetamol 500mg vence en 43 días (2026-04-15).',
   'a1000000-0000-0000-0000-000000000003', NULL, false),

  -- Alerta resuelta (ejemplo histórico)
  ('d1000000-0000-0000-0000-000000000005',
   'STOCK_BAJO', 'WARNING',
   'Stock bajo de Ibuprofeno 400mg (resuelto tras reposición).',
   'a1000000-0000-0000-0000-000000000002', NULL, true);


-- ============================================================
-- E) AUDIT LOG
-- ============================================================
INSERT INTO public.audit_log (id, workflow, accion, detalle, payload_resumen)
VALUES
  ('e1000000-0000-0000-0000-000000000001',
   'WF1_Ingesta_Inventario', 'ENTRADA',
   'Entrada de stock registrada para AMOX-500.',
   '{"sku":"AMOX-500","cantidad":150,"tipo_evento":"ENTRADA"}'::jsonb),

  ('e1000000-0000-0000-0000-000000000002',
   'WF1_Ingesta_Inventario', 'SALIDA',
   'Venta registrada para IBUP-400.',
   '{"sku":"IBUP-400","cantidad":2,"tipo_evento":"VENTA"}'::jsonb),

  ('e1000000-0000-0000-0000-000000000003',
   'WF2_Procesamiento_Reglas_Alertas', 'ALERTA_GENERADA',
   'Alerta STOCK_BAJO generada para PARA-500.',
   '{"producto_id":"a1000000-0000-0000-0000-000000000003","stock_actual":30}'::jsonb),

  ('e1000000-0000-0000-0000-000000000004',
   'WF2_Procesamiento_Reglas_Alertas', 'ALERTA_GENERADA',
   'Alerta VENCIMIENTO_PROXIMO generada para VENC-TEST.',
   '{"producto_id":"a1000000-0000-0000-0000-000000000006","fecha_vencimiento":"2026-03-10"}'::jsonb),

  ('e1000000-0000-0000-0000-000000000005',
   'WF3_Salida_Reportes', 'REPORTE_GENERADO',
   'Reporte semanal de inventario guardado en /data/reports.',
   '{"archivo":"reporte_inventario_semana.csv","registros":8}'::jsonb);


-- ============================================================
-- F) ERROR LOG
-- ============================================================
INSERT INTO public.error_log (id, workflow, paso, error_msg, payload)
VALUES
  -- Payload sin SKU
  ('f1000000-0000-0000-0000-000000000001',
   'WF1_Ingesta_Inventario', 'IF_Validacion',
   'Campo requerido ausente: sku',
   '{"nombre":"Producto sin SKU","cantidad":10}'::jsonb),

  -- Cantidad inválida
  ('f1000000-0000-0000-0000-000000000002',
   'WF1_Ingesta_Inventario', 'IF_Validacion',
   'Cantidad debe ser mayor a 0. Recibido: -5',
   '{"sku":"IBUP-400","cantidad":-5}'::jsonb),

  -- Stock insuficiente para salida
  ('f1000000-0000-0000-0000-000000000003',
   'WF1_Ingesta_Inventario', 'IF_StockDisponible',
   'Stock insuficiente para salida. Solicitado: 300 | Disponible: 30',
   '{"sku":"PARA-500","tipo_salida":"VENTA","cantidad":300}'::jsonb);

-- ============================================================
-- FIN DEL SCRIPT
-- ============================================================
