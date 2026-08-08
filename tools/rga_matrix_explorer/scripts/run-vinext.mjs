import { spawn } from "node:child_process";

const command = process.argv[2];
if (!["dev", "build", "start"].includes(command)) {
  console.error("Usage: node scripts/run-vinext.mjs <dev|build|start>");
  process.exit(2);
}

const child = spawn("vinext", [command], {
  env: {
    ...process.env,
    WRANGLER_LOG_PATH: ".wrangler/wrangler.log",
  },
  shell: process.platform === "win32",
  stdio: "inherit",
});

child.on("error", (error) => {
  console.error(error);
  process.exit(1);
});

child.on("exit", (code, signal) => {
  if (signal) {
    console.error(`vinext ${command} exited on ${signal}`);
    process.exit(1);
  }
  process.exit(code ?? 1);
});
