const esbuild = require("esbuild");
const fs = require("fs");
const { execSync } = require("child_process");

esbuild
  .build({
    entryPoints: ["src/frontend/app.ts"], // Replace with your entry file
    bundle: true, // Bundle all dependencies into a single file
    outfile: "out/frontend/app.js", // Output file
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
  .then(() => {
    const input = "src/frontend/index.html";
    const outfile = "out/frontend/index.html";

    // Add a timestamp as version ID
    let html = fs.readFileSync(input, "utf8");
    html = html.replace(
      /<script src=".\/app\.js"/,
      `<script src="./app\.js?v=${Date.now()}"`,
    );

    fs.writeFileSync(outfile, html, "utf8");
  })
  .then(() => {
    // copy static files
    execSync(`cp -r src/frontend/img out/frontend/img`);
    execSync(`cp -r src/frontend/fonts out/frontend/fonts`);
  })
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
