const esbuild = require("esbuild");
const fs = require("fs");
const { execSync } = require("child_process");

const copyWithCacheBuster = (name, scriptName) => {
  const infile = "src/frontend/" + name + ".html";
  const outfile = "out/frontend/" + name + ".html";
  const pattern = new RegExp(`<script src="\\./${scriptName}\\.js"`);
  const replacement = `<script src="./${scriptName}.js?v=${Date.now()}"`;

  let html = fs.readFileSync(infile, "utf8");
  html = html.replace(pattern, replacement);

  fs.writeFileSync(outfile, html, "utf8");
};

esbuild
  .build({
    entryPoints: [
      "src/frontend/app.ts", // Main app
      "src/frontend/callback.ts", // OAuth callback
      "src/frontend/pkce-callback.ts", // PKCE callback
      "src/frontend/oidc-callback.ts", // OIDC callback
    ],
    bundle: true, // Bundle all dependencies into a single file
    outdir: "out/frontend/", // Output file
    minify: true, // Minify the output for production
    sourcemap: true, // Generate source maps for debugging
    target: "esnext", // The JavaScript version to target
    platform: "browser", // Ensure it's bundled for the browser
    loader: {
      ".ts": "ts", // Tell esbuild to handle TypeScript files
    },
    define: {
      "process.env": JSON.stringify({
        CANISTER_ID_BACKEND: process.env.CANISTER_ID_BACKEND,
        DFX_NETWORK: process.env.DFX_NETWORK,
        BUILD_TIME: new Date().toISOString().replace("T", " ").substring(0, 19),
      }), // pass in dfx environment variables
      global: "window",
    },
  })
  .then(() => copyWithCacheBuster("index", "app"))
  .then(() => copyWithCacheBuster("callback", "callback"))
  .then(() => copyWithCacheBuster("oidc-callback", "oidc-callback"))
  .then(() => copyWithCacheBuster("pkce-callback", "pkce-callback"))
  .then(() => {
    // copy static files
    execSync(`cp -r src/frontend/img out/frontend/`);
    execSync(`cp -r src/frontend/fonts out/frontend/`);
    execSync(`cp src/frontend/.ic-assets.json5 out/frontend/`);
  })
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
