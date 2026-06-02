const http = require("http");
const fs = require("fs");
const path = require("path");
const { URL } = require("url");

const PORT = 3000;
const HOST = "localhost";
const BASE_DIR = __dirname;
const REPORTS_DIR = path.join(BASE_DIR, "..", "data", "reports");
const LOGS_DIR = path.join(BASE_DIR, "..", "data", "logs");

const MIME_TYPES = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "application/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon"
};

function sendFile(filePath, res) {
  fs.readFile(filePath, (err, data) => {
    if (err) {
      res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
      res.end("404 - Archivo no encontrado");
      return;
    }

    const ext = path.extname(filePath).toLowerCase();
    const contentType = MIME_TYPES[ext] || "application/octet-stream";
    res.writeHead(200, { "Content-Type": contentType });
    res.end(data);
  });
}

function sendJson(res, statusCode, payload) {
  res.writeHead(statusCode, { "Content-Type": "application/json; charset=utf-8" });
  res.end(JSON.stringify(payload));
}

function readLastLines(filePath, maxLines, callback) {
  fs.readFile(filePath, "utf8", (err, content) => {
    if (err) {
      callback(err);
      return;
    }
    const lines = content.split(/\r?\n/).filter(Boolean);
    callback(null, lines.slice(-maxLines));
  });
}

function handleApi(req, res) {
  if (req.method === "POST" && req.url === "/api/n8n-webhook") {
    let raw = "";
    req.on("data", (chunk) => {
      raw += chunk;
    });
    req.on("end", () => {
      try {
        const { baseUrl, endpoint, payload } = JSON.parse(raw || "{}");
        const target = new URL(`${String(baseUrl || "").replace(/\/$/, "")}${endpoint || ""}`);
        const body = JSON.stringify(payload || {});

        const proxyReq = http.request(
          {
            hostname: target.hostname,
            port: target.port || 80,
            path: `${target.pathname}${target.search}`,
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "Content-Length": Buffer.byteLength(body)
            }
          },
          (proxyRes) => {
            let proxyData = "";
            proxyRes.on("data", (chunk) => {
              proxyData += chunk;
            });
            proxyRes.on("end", () => {
              const contentType = proxyRes.headers["content-type"] || "";
              let parsedBody = proxyData;
              if (String(contentType).includes("application/json")) {
                try {
                  parsedBody = JSON.parse(proxyData || "{}");
                } catch (_err) {
                  parsedBody = proxyData;
                }
              }
              sendJson(res, proxyRes.statusCode || 500, {
                ok: (proxyRes.statusCode || 500) < 400,
                status: proxyRes.statusCode || 500,
                body: parsedBody
              });
            });
          }
        );

        proxyReq.on("error", (err) => {
          sendJson(res, 502, { ok: false, error: err.message });
        });

        proxyReq.write(body);
        proxyReq.end();
      } catch (err) {
        sendJson(res, 400, { ok: false, error: `Payload invalido: ${err.message}` });
      }
    });
    return true;
  }

  if (req.method === "GET" && req.url.startsWith("/api/reports")) {
    fs.readdir(REPORTS_DIR, (err, files) => {
      if (err) {
        sendJson(res, 500, { ok: false, error: "No se pudieron leer reportes" });
        return;
      }

      const reports = files
        .filter((name) => name.toLowerCase().endsWith(".csv") || name.toLowerCase().endsWith(".html"))
        .map((name) => {
          const fullPath = path.join(REPORTS_DIR, name);
          const stat = fs.statSync(fullPath);
          return {
            name,
            sizeBytes: stat.size,
            modifiedAt: stat.mtime.toISOString(),
            url: `/data/reports/${encodeURIComponent(name)}`
          };
        })
        .sort((a, b) => b.modifiedAt.localeCompare(a.modifiedAt));

      sendJson(res, 200, { ok: true, reports });
    });
    return true;
  }

  if (req.method === "GET" && req.url.startsWith("/api/errors")) {
    const filePath = path.join(LOGS_DIR, "errors.log");
    readLastLines(filePath, 40, (err, lines) => {
      if (err) {
        sendJson(res, 200, { ok: true, lines: [] });
        return;
      }
      sendJson(res, 200, { ok: true, lines });
    });
    return true;
  }

  if (req.method === "GET" && req.url.startsWith("/api/health")) {
    sendJson(res, 200, {
      ok: true,
      timestamp: new Date().toISOString(),
      notes: "WF2 se ejecuta por cron cada 5 minutos en n8n"
    });
    return true;
  }

  return false;
}

const server = http.createServer((req, res) => {
  if (handleApi(req, res)) {
    return;
  }

  if (req.method === "GET" && req.url.startsWith("/data/reports/")) {
    const reportFile = decodeURIComponent(req.url.replace("/data/reports/", ""));
    const reportPath = path.join(REPORTS_DIR, reportFile);
    sendFile(reportPath, res);
    return;
  }

  const requestedPath = decodeURIComponent(req.url.split("?")[0]);
  const safePath = path.normalize(requestedPath).replace(/^([.][.][/\\])+/, "");
  let filePath = path.join(BASE_DIR, safePath === "/" ? "index.html" : safePath);

  if (!filePath.startsWith(BASE_DIR)) {
    res.writeHead(403, { "Content-Type": "text/plain; charset=utf-8" });
    res.end("403 - Acceso denegado");
    return;
  }

  fs.stat(filePath, (err, stats) => {
    if (!err && stats.isDirectory()) {
      filePath = path.join(filePath, "index.html");
    }
    sendFile(filePath, res);
  });
});

server.listen(PORT, HOST, () => {
  console.log(`Servidor activo en http://${HOST}:${PORT}`);
});
