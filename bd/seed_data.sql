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
    destinatario TEXT NULL,
    cantidad INTEGER NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(10,2) NULL DEFAULT 0,
    total NUMERIC(10,2) GENERATED ALWAYS AS (cantidad * precio_unitario) STORED,
    origen TEXT NOT NULL CHECK (origen IN ('WEBHOOK', 'ARCHIVO', 'MANUAL')),
    referencia TEXT NULL,
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
