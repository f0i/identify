// jest.config.js
module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  // You might need to adjust this depending on where your test files are
  testMatch: ["**/candid*.test.ts"],
  moduleNameMapper: {
    // If you have path aliases in your tsconfig.json, you might need to map them here
    // Example: '^@/(.*)$': '<rootDir>/src/$1',
  },
};
