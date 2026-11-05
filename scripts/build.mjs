import { build } from "esbuild";
import { cp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import path from "node:path";

const root = process.cwd();
const out = path.join(root, "dist");
await rm(out, { recursive: true, force: true });
await mkdir(path.join(out, "assets"), { recursive: true });
await build({
  entryPoints: [path.join(root, "src/main.jsx")],
  outfile: path.join(out, "assets/app.js"),
  bundle: true,
  minify: true,
  sourcemap: true,
  format: "esm",
  jsx: "automatic",
  target: ["es2020"],
  loader: { ".js": "jsx", ".jsx": "jsx", ".css": "css" },
});
await cp(path.join(root, "public"), out, { recursive: true });
await cp(path.join(root, "index.html"), path.join(out, "index.html"));
const buildVersion = process.env.GITHUB_SHA || Date.now().toString(36);
const html = (await readFile(path.join(out, "index.html"), "utf8"))
  .replace("./assets/app.css", `./assets/app.css?v=${buildVersion}`)
  .replace("./config.js", `./config.js?v=${buildVersion}`)
  .replace("./assets/app.js", `./assets/app.js?v=${buildVersion}`);
await writeFile(path.join(out, "index.html"), html);
await writeFile(path.join(out, "404.html"), html);
console.log("LabFlow build complete: dist/");
