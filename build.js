const esbuild = require("esbuild");

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
      }), // pass in dfx environment variables
      global: "window",
    },
  })
  .catch(() => process.exit(1));
