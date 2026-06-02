# Plan de frontend WF1-WF4

## Objetivo
Crear una interfaz web para operar WF1 y monitorear evidencias de WF2, WF3 y WF4 desde un panel unico.

## Fase 1 - Estructura
1. Definir pagina unica con secciones: configuracion, formulario de evento y respuesta.
2. Permitir cambiar URL base y endpoint para pruebas locales o remotas.
3. Agregar bloques de monitoreo por workflow.

## Fase 2 - UX
1. Soportar los dos tipos de evento actuales: ENTRADA y SALIDA.
2. Mostrar solo campos relevantes para cada tipo de evento.
3. Incluir boton para cargar payload de ejemplo rapido.
4. Incluir botones de recarga para estado, reportes y errores.

## Fase 3 - Integracion
1. Enviar solicitudes POST con `fetch` al webhook.
2. Mostrar estado de la solicitud: cargando, exito o error.
3. Renderizar respuesta HTTP completa (codigo + body).
4. Exponer API local en Node para listar reportes y mostrar `errors.log`.

## Fase 4 - Validacion
1. Probar ENTRADA con SKU nuevo.
2. Probar SALIDA con SKU existente.
3. Confirmar WF3 en lista de reportes (`/data/reports`).
4. Confirmar WF4 en bloque de errores (`/data/logs/errors.log`).
5. Confirmar cron de WF2 desde n8n Executions.

## Entregables
- `front/index.html`
- `front/styles.css`
- `front/app.js`
- `front/server.js`
