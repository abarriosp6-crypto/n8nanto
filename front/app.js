const form = document.getElementById("inventoryForm");
const statusEl = document.getElementById("status");
const responseBox = document.getElementById("responseBox");
const chips = Array.from(document.querySelectorAll(".chip"));
const inputTipoEvento = document.getElementById("tipo_evento");
const entradaFields = Array.from(document.querySelectorAll(".entrada-field"));
const salidaFields = Array.from(document.querySelectorAll(".salida-field"));
const btnEjemplo = document.getElementById("btnEjemplo");
const btnRefreshHealth = document.getElementById("btnRefreshHealth");
const btnRefreshReports = document.getElementById("btnRefreshReports");
const btnRefreshErrors = document.getElementById("btnRefreshErrors");
const btnGenerateReport = document.getElementById("btnGenerateReport");
const wf2Health = document.getElementById("wf2Health");
const reportsList = document.getElementById("reportsList");
const errorsBox = document.getElementById("errorsBox");

function setStatus(kind, text) {
  statusEl.className = `status ${kind}`;
  statusEl.textContent = text;
}

function showEventFields(tipo) {
  const isEntrada = tipo === "ENTRADA";
  entradaFields.forEach((field) => field.classList.toggle("hidden", !isEntrada));
  salidaFields.forEach((field) => field.classList.toggle("hidden", isEntrada));
}

function setActiveEvent(tipo) {
  inputTipoEvento.value = tipo;
  chips.forEach((chip) => {
    chip.classList.toggle("is-active", chip.dataset.evento === tipo);
  });
  showEventFields(tipo);
}

function getPayload() {
  const tipo_evento = inputTipoEvento.value;
  const data = {
    tipo_evento,
    sku: document.getElementById("sku").value.trim(),
    cantidad: Number(document.getElementById("cantidad").value)
  };

  if (tipo_evento === "ENTRADA") {
    data.nombre = document.getElementById("nombre").value.trim();
    data.categoria = document.getElementById("categoria").value.trim() || "General";
    data.stock_minimo = Number(document.getElementById("stock_minimo").value || 0);

    const fv = document.getElementById("fecha_vencimiento").value;
    if (fv) data.fecha_vencimiento = fv;
  } else {
    data.tipo_salida = document.getElementById("tipo_salida").value;
    const destinatario = document.getElementById("destinatario").value.trim();
    const referencia = document.getElementById("referencia").value.trim();

    if (destinatario) data.destinatario = destinatario;
    data.precio_unitario = Number(document.getElementById("precio_unitario").value || 0);
    if (referencia) data.referencia = referencia;
  }

  return data;
}

chips.forEach((chip) => {
  chip.addEventListener("click", () => setActiveEvent(chip.dataset.evento));
});

btnEjemplo.addEventListener("click", () => {
  const tipo = inputTipoEvento.value;
  if (tipo === "ENTRADA") {
    document.getElementById("sku").value = "TEST001";
    document.getElementById("cantidad").value = "50";
    document.getElementById("nombre").value = "Producto Test";
    document.getElementById("categoria").value = "Prueba";
    document.getElementById("stock_minimo").value = "10";
    document.getElementById("fecha_vencimiento").value = "";
  } else {
    document.getElementById("sku").value = "TEST001";
    document.getElementById("cantidad").value = "5";
    document.getElementById("tipo_salida").value = "VENTA";
    document.getElementById("destinatario").value = "Cliente ABC";
    document.getElementById("precio_unitario").value = "25.50";
    document.getElementById("referencia").value = "Ticket #001";
  }
});

form.addEventListener("submit", async (event) => {
  event.preventDefault();

  const baseUrl = document.getElementById("baseUrl").value.trim().replace(/\/$/, "");
  const endpoint = document.getElementById("endpoint").value.trim();
  const payload = getPayload();

  setStatus("loading", "Enviando evento...");
  responseBox.textContent = JSON.stringify({ request: payload }, null, 2);

  try {
    const res = await fetch("/api/n8n-webhook", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ baseUrl, endpoint, payload })
    });

    const data = await res.json();
    responseBox.textContent = JSON.stringify(data, null, 2);

    if (res.ok && data.ok) {
      setStatus("success", "Evento procesado correctamente");
    } else {
      setStatus("error", `Error ${data.status || res.status}: revisa el payload`);
    }
  } catch (error) {
    responseBox.textContent = JSON.stringify({ error: error.message }, null, 2);
    setStatus("error", "No se pudo conectar con n8n");
  }
});

async function loadWf2Health() {
  wf2Health.textContent = "Cargando estado...";
  try {
    const res = await fetch("/api/health");
    const data = await res.json();
    wf2Health.textContent = JSON.stringify(data, null, 2);
  } catch (error) {
    wf2Health.textContent = JSON.stringify({ ok: false, error: error.message }, null, 2);
  }
}

async function loadReports() {
  reportsList.innerHTML = "<p>Cargando reportes...</p>";
  try {
    const res = await fetch("/api/reports");
    const data = await res.json();

    if (!data.ok || data.reports.length === 0) {
      reportsList.innerHTML = "<p>No hay reportes en /data/reports.</p>";
      return;
    }

    reportsList.innerHTML = data.reports
      .map(
        (report) => `
          <article class="list-item">
            <div>
              <p><strong>${report.name}</strong></p>
              <p>${new Date(report.modifiedAt).toLocaleString("es-GT")} | ${report.sizeBytes} bytes</p>
            </div>
            <a href="${report.url}" target="_blank" rel="noopener noreferrer">Abrir</a>
          </article>
        `
      )
      .join("");
  } catch (error) {
    reportsList.innerHTML = `<p>Error cargando reportes: ${error.message}</p>`;
  }
}

async function loadErrors() {
  errorsBox.textContent = "Cargando errores...";
  try {
    const res = await fetch("/api/errors");
    const data = await res.json();
    errorsBox.textContent = (data.lines || []).join("\n") || "Sin errores registrados en errors.log";
  } catch (error) {
    errorsBox.textContent = `Error: ${error.message}`;
  }
}

async function generateReportNow() {
  const baseUrl = document.getElementById("baseUrl").value.trim().replace(/\/$/, "");
  const reportEndpoint = document.getElementById("reportEndpoint").value.trim();

  setStatus("loading", "Generando reporte WF3...");

  try {
    const res = await fetch("/api/n8n-webhook", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        baseUrl,
        endpoint: reportEndpoint,
        payload: { origen: "front_manual" }
      })
    });

    const data = await res.json();
    responseBox.textContent = JSON.stringify(data, null, 2);

    if (!res.ok || !data.ok) {
      setStatus("error", `WF3 manual fallo (${data.status || res.status})`);
      return;
    }

    setStatus("success", "WF3 ejecutado. Actualizando reportes...");
    await loadReports();
  } catch (error) {
    setStatus("error", "No se pudo ejecutar WF3 manual");
    responseBox.textContent = JSON.stringify({ error: error.message }, null, 2);
  }
}

btnRefreshHealth.addEventListener("click", loadWf2Health);
btnRefreshReports.addEventListener("click", loadReports);
btnRefreshErrors.addEventListener("click", loadErrors);
btnGenerateReport.addEventListener("click", generateReportNow);

setActiveEvent("ENTRADA");
loadWf2Health();
loadReports();
loadErrors();
