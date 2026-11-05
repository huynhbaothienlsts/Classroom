import http from "node:http";
import { readFile, stat } from "node:fs/promises";
import path from "node:path";
import { spawn } from "node:child_process";

const root = path.resolve(process.argv[2] || "dist");
if (!process.argv[2]) await new Promise((resolve, reject) => {
  const build = spawn(process.execPath, ["scripts/build.mjs"], { stdio: "inherit" });
  build.on("exit", code => code === 0 ? resolve() : reject(new Error("Build failed")));
});
const types = { ".html":"text/html; charset=utf-8", ".js":"text/javascript", ".css":"text/css", ".map":"application/json", ".png":"image/png" };
http.createServer(async (req,res) => {
  try {
    let file = path.join(root, decodeURIComponent(req.url.split("?")[0]));
    if ((await stat(file).catch(()=>null))?.isDirectory()) file = path.join(file,"index.html");
    if (!(await stat(file).catch(()=>null))) file = path.join(root,"index.html");
    const data = await readFile(file); res.writeHead(200,{"Content-Type":types[path.extname(file)]||"application/octet-stream"}); res.end(data);
  } catch { res.writeHead(500); res.end("Server error"); }
}).listen(4173,"127.0.0.1",()=>console.log("Local: http://127.0.0.1:4173"));
