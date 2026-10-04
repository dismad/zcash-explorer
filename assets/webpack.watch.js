const { spawn } = require("child_process");

const args = process.argv.slice(2).filter((arg) => arg !== "--watch-stdin");
if (!args.includes("--watch")) args.push("--watch");

const child = spawn(
  process.execPath,
  [require.resolve("webpack/bin/webpack.js"), ...args],
  { stdio: "inherit" }
);

process.stdin.on("end", () => child.kill("SIGTERM"));
process.on("SIGINT", () => child.kill("SIGINT"));
child.on("exit", (code) => process.exit(code ?? 0));
