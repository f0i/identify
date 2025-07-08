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
      "src/frontend/zitadel.ts", // OAuth via zitadel
      "src/frontend/callback.ts", // OAuth callback
      "src/frontend/auth0.ts", // OAuth via Auth0
      "src/frontend/candid.ts", // Candid decoder
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
  .then(() => copyWithCacheBuster("zitadel", "zitadel"))
  .then(() => copyWithCacheBuster("auth0", "auth0"))
  .then(() => copyWithCacheBuster("candid", "candid"))
  .then(() => copyWithCacheBuster("callback", "callback"))
  .then(() => {
    // copy static files
    execSync(`cp -r src/frontend/img out/frontend/img`);
    execSync(`cp -r src/frontend/fonts out/frontend/fonts`);
  })
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
