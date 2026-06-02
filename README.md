# Sistema Automatizado de Gestión de Farmacia

Proyecto final del curso **Análisis de Sistemas**.
Este sistema permite automatizar la gestión de inventario de una farmacia utilizando **n8n**, **PostgreSQL/Supabase**, **Docker** y un **frontend web local**.

## 1. Descripción del Proyecto

El proyecto consiste en un sistema automatizado para registrar movimientos de inventario, generar alertas por bajo stock o vencimiento próximo, crear reportes CSV y registrar errores mediante bitácoras.

El sistema está compuesto por un panel web, workflows desarrollados en n8n, una base de datos PostgreSQL y carpetas locales para almacenar reportes y archivos de log.

## 2. Tecnologías Utilizadas

- n8n
- Docker
- PostgreSQL / Supabase
- Node.js
- HTML
- CSS
- JavaScript
- Postman
- CSV
- Git / GitHub

## 3. Estructura del Repositorio

```txt
proyectoAnalisis/
│
├── docs/
│   └── Informe proyecto analisis.pdf
│   └── Diagramas.pdf
│
└── n8nanto/
    │
    ├── README.md
    ├── docker-compose.yml
    ├── .env
    ├── .gitignore
    ├── comandosdocker.md
    ├── plan.md
    │
    ├── bd/
    │   ├── bd.sql
    │   └── seed_data.sql
    │
    ├── data/
    │   ├── logs/
    │   │   └── errors.log
    │   ├── outbox/
    │   └── reports/
    │
    ├── front/
    │   ├── app.js
    │   ├── index.html
    │   ├── package.json
    │   ├── PLAN_FRONT.md
    │   ├── server.js
    │   └── styles.css
    │
    ├── n8n_data/
    │   ├── nodes/
    │   │   └── package.json
    │   ├── config
    │   ├── database.sqlite
    │   ├── database.sqlite-shm
    │   ├── database.sqlite-wal
    │   └── n8nEventLog.log
    │
    └── workflows/
        ├── WF1_Ingesta_Inventario.json
        ├── WF2_Procesamiento_Reglas_Alertas.json
        ├── WF3_Salida_Reportes.json
        └── WF4_Error_Handler.json
```

## 4. Workflows Implementados

### WF1 - Ingesta de Inventario

Este workflow recibe datos desde el frontend mediante un Webhook.
Permite registrar entradas y salidas de productos, validar datos, actualizar stock, registrar movimientos y guardar auditoría.

### WF2 - Procesamiento de Reglas y Alertas

Este workflow se ejecuta automáticamente mediante un Cron.
Revisa el inventario y genera alertas cuando detecta productos con bajo stock o próximos a vencer.

### WF3 - Generación de Reportes

Este workflow permite generar reportes automáticos del inventario.
Consulta productos y alertas, formatea la información y crea archivos CSV dentro de la carpeta `data/reports`.

### WF4 - Error Handler

Este workflow captura errores generados durante la ejecución del sistema.
Registra incidentes en la base de datos y genera archivos de log dentro de la carpeta `data/logs`.

## 5. Instalación

### Requisitos previos

Antes de ejecutar el proyecto se debe tener instalado:

* Docker
* Node.js
* npm
* Git

### Clonar el repositorio

```bash
git clone URL_DEL_REPOSITORIO
cd n8nanto
```

### Levantar n8n con Docker

```bash
docker compose up -d
```

Verificar que el contenedor esté activo:

```bash
docker ps
```

n8n estará disponible en:

```txt
http://localhost:5678
```

## 6. Ejecución del Frontend

Entrar a la carpeta del frontend:

```bash
cd front
```

Instalar dependencias:

```bash
npm install
```

Ejecutar el servidor:

```bash
npm start
```

El panel web estará disponible en:

```txt
http://localhost:3000
```

## 7. Base de Datos

El sistema utiliza PostgreSQL/Supabase como base de datos principal.

Los scripts se encuentran en la carpeta `bd/`:

* `bd.sql`: contiene la estructura de las tablas.
* `seed_data.sql`: contiene datos de prueba.

Tablas principales:

* productos
* movimientos
* salidas
* alertas
* audit_log
* error_log

## 8. Importación de Workflows en n8n

Los workflows exportados se encuentran en la carpeta `workflows/`.

Para importarlos:

1. Abrir n8n en `http://localhost:5678`.
2. Entrar a la sección de workflows.
3. Seleccionar la opción de importar workflow.
4. Cargar cada archivo JSON.
5. Configurar las credenciales de PostgreSQL/Supabase.
6. Publicar los workflows.

## 9. Uso del Sistema

1. Abrir el panel web en `http://localhost:3000`.
2. Registrar una entrada o salida de inventario.
3. Verificar la respuesta del sistema.
4. Consultar los registros en Supabase.
5. Generar reportes desde la sección WF3.
6. Revisar los archivos CSV en `data/reports`.
7. Consultar errores desde la sección WF4.

## 10. Pruebas Realizadas

| Caso | Descripción                                              | Resultado |
| ---- | -------------------------------------------------------- | --------- |
| WF1  | Registro de entrada de inventario desde frontend         | Correcto  |
| WF1  | Registro de salida de inventario con validación de stock | Correcto  |
| WF2  | Generación de alerta por stock bajo                      | Correcto  |
| WF2  | Generación de alerta por vencimiento próximo             | Correcto  |
| WF3  | Generación de reporte CSV                                | Correcto  |
| WF4  | Registro de errores en base de datos y archivo log       | Correcto  |

## 11. Documentación

La carpeta `docs/` contiene la documentación técnica del proyecto y los diagramas utilizados.

## 12. Autor

**Anthony Jacob Barrios Pérez**
Proyecto Final - Análisis de Sistemas
Universidad Mariano Gálvez de Guatemala
