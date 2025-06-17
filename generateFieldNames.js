const fs = require("fs");

const generateFieldNames = () => {
  const input = "./src/frontend/identify/candidFieldNames.txt";
  const output = "./src/frontend/identify/candidFieldNames.ts";

  const lines = fs
    .readFileSync(input, "utf8")
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean);

  const content = `// Generated using generateFieldNames.js.\nDo not edit manually!\n\nimport { createNameLookup } from "./candidDecoder";\nconst candidFieldNames = ${JSON.stringify(lines, null, 2)};\nexport const fieldNames = createNameLookup(candidFieldNames);\n`;
  console.error(content);

  fs.writeFileSync(output, content);
};

generateFieldNames();
