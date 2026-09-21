#!/usr/bin/env node
// Launch the Jev agent harness through the configured Godot MCP runner.
//
// The legacy godot-mcp server is the sanctioned project runner for this repo
// (see docs/agent-workflows/runtime.md). This client speaks its stdio JSON-RPC
// directly so a long agent run can be supervised, logged, and stopped without
// babysitting an editor session.
//
// Usage:
//   node tools/jev/run_jev_scene.mjs --project <projectDir> --scene <scene> --log <file>

import { spawn } from 'node:child_process';
import { appendFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

function parseArgs(argv) {
  const args = {
    project: '',
    scene: 'tests/agent/JevRunHarness.tscn',
    log: '',
    server: 'C:/Users/Flipm/Documents/godot-mcp/build/index.js',
    godotPath: process.env.GODOT_PATH || '',
    completeMarker: 'JEV_RUN_COMPLETE',
    timeoutSeconds: 2700,
    pollMilliseconds: 2000,
    startGraceSeconds: 300,
  };
  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    const next = argv[index + 1];
    switch (token) {
      case '--project': args.project = next; index += 1; break;
      case '--scene': args.scene = next; index += 1; break;
      case '--log': args.log = next; index += 1; break;
      case '--server': args.server = next; index += 1; break;
      case '--godot-path': args.godotPath = next; index += 1; break;
      case '--timeout-seconds': args.timeoutSeconds = Number(next); index += 1; break;
      case '--complete-marker': args.completeMarker = next; index += 1; break;
      case '--poll-milliseconds': args.pollMilliseconds = Number(next); index += 1; break;
      case '--start-grace-seconds': args.startGraceSeconds = Number(next); index += 1; break;
      default:
        if (token.startsWith('--')) throw new Error(`Unknown argument: ${token}`);
    }
  }
  if (!args.project) throw new Error('--project is required');
  if (!args.log) throw new Error('--log is required');
  if (!args.godotPath) throw new Error('--godot-path or GODOT_PATH is required');
  args.project = resolve(args.project);
  args.log = resolve(args.log);
  args.server = resolve(args.server);
  args.godotPath = resolve(args.godotPath);
  return args;
}

class McpClient {
  constructor(serverPath, env) {
    this.nextId = 1;
    this.pending = new Map();
    this.buffer = '';
    this.stderrTail = [];
    this.child = spawn(process.execPath, [serverPath], {
      cwd: dirname(serverPath),
      env: { ...process.env, ...env, DEBUG: 'false' },
      stdio: ['pipe', 'pipe', 'pipe'],
    });
    this.child.stdout.setEncoding('utf8');
    this.child.stderr.setEncoding('utf8');
    this.child.stdout.on('data', (chunk) => this.#onStdout(chunk));
    this.child.stderr.on('data', (chunk) => {
      this.stderrTail.push(chunk);
      if (this.stderrTail.length > 40) this.stderrTail.shift();
    });
    this.closed = new Promise((resolveClosed) => {
      this.child.on('exit', (code, signal) => resolveClosed({ code, signal }));
    });
  }

  #onStdout(chunk) {
    this.buffer += chunk;
    let index = this.buffer.indexOf('\n');
    while (index !== -1) {
      const line = this.buffer.slice(0, index).trim();
      this.buffer = this.buffer.slice(index + 1);
      if (line) this.#onMessage(line);
      index = this.buffer.indexOf('\n');
    }
  }

  #onMessage(line) {
    let message;
    try {
      message = JSON.parse(line);
    } catch {
      return;
    }
    if (message.id === undefined || message.id === null) return;
    const entry = this.pending.get(message.id);
    if (!entry) return;
    this.pending.delete(message.id);
    if (message.error) entry.reject(new Error(`${entry.method}: ${message.error.message ?? 'failed'}`));
    else entry.resolve(message.result);
  }

  request(method, params) {
    const id = this.nextId;
    this.nextId += 1;
    const payload = { jsonrpc: '2.0', id, method, params: params ?? {} };
    return new Promise((resolveRequest, rejectRequest) => {
      this.pending.set(id, { resolve: resolveRequest, reject: rejectRequest, method });
      this.child.stdin.write(`${JSON.stringify(payload)}\n`);
    });
  }

  notify(method, params) {
    this.child.stdin.write(`${JSON.stringify({ jsonrpc: '2.0', method, params: params ?? {} })}\n`);
  }

  async callTool(name, args) {
    const result = await this.request('tools/call', { name, arguments: args ?? {} });
    const texts = (result?.content ?? [])
      .filter((item) => item?.type === 'text')
      .map((item) => String(item.text));
    if (result?.isError) throw new Error(`${name} failed: ${texts.join(' | ')}`);
    return texts.join('\n');
  }

  async close() {
    try {
      this.child.stdin.end();
    } catch {
      // ignore
    }
    const closed = await Promise.race([
      this.closed,
      new Promise((resolveClosed) => setTimeout(() => resolveClosed({ code: null, signal: 'timeout' }), 5000)),
    ]);
    if (closed.signal === 'timeout') this.child.kill();
    return closed;
  }
}

function sleep(milliseconds) {
  return new Promise((done) => setTimeout(done, milliseconds));
}

function extractLines(payloadText) {
  try {
    const parsed = JSON.parse(payloadText);
    return {
      output: Array.isArray(parsed.output) ? parsed.output : [],
      errors: Array.isArray(parsed.errors) ? parsed.errors : [],
    };
  } catch {
    return { output: [payloadText], errors: [] };
  }
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  mkdirSync(dirname(args.log), { recursive: true });
  if (existsSync(args.log)) {
    // keep prior runs intact; the orchestrator names logs per run
  }
  writeFileSync(args.log, '');

  const passthrough = {};
  for (const key of ['JEV_RUN_DIR', 'JEV_MODE', 'JEV_RUN_SEED', 'JEV_STARTER']) {
    if (process.env[key]) passthrough[key] = process.env[key];
  }
  const client = new McpClient(args.server, { GODOT_PATH: args.godotPath, ...passthrough });
  const startedAt = Date.now();
  const summary = { status: 'unknown', scene: args.scene, project: args.project, log: args.log };
  let writtenOutput = 0;
  let writtenErrors = 0;
  let sawStart = false;
  try {
    await client.request('initialize', {
      protocolVersion: '2024-11-05',
      capabilities: {},
      clientInfo: { name: 'bwp-jev-run', version: '1.0.0' },
    });
    client.notify('notifications/initialized', {});
    await client.callTool('run_project', { projectPath: args.project, scene: args.scene });
    const deadline = startedAt + args.timeoutSeconds * 1000;
    const startDeadline = startedAt + args.startGraceSeconds * 1000;
    for (;;) {
      await sleep(args.pollMilliseconds);
      let payload;
      try {
        payload = await client.callTool('get_debug_output', {});
      } catch (error) {
        // The game can exit on its own (probe scenes quit themselves). A clean
        // exit after real output is a finished run, not a supervision failure.
        summary.status = sawStart ? 'process_ended' : 'never_started';
        if (sawStart) {
          const seen = readFileSync(args.log, 'utf8');
          if (seen.includes(args.completeMarker)) summary.status = 'complete';
        }
        summary.detail = String(error.message ?? error);
        break;
      }
      const { output, errors } = extractLines(payload);
      const newOutput = output.slice(writtenOutput);
      const newErrors = errors.slice(writtenErrors);
      writtenOutput = output.length;
      writtenErrors = errors.length;
      if (newOutput.length > 0) {
        appendFileSync(args.log, newOutput.map((line) => `out| ${line}`).join('\n') + '\n');
      }
      if (newErrors.length > 0) {
        appendFileSync(args.log, newErrors.map((line) => `err| ${line}`).join('\n') + '\n');
      }
      const joined = [...output, ...errors].join('\n');
      if (joined.includes(args.completeMarker)) {
        summary.status = 'complete';
        break;
      }
      if (/Debugger Break/i.test(joined)) {
        summary.status = 'debugger_break';
        break;
      }
      if (output.length > 0 || errors.length > 0) sawStart = true;
      if (!sawStart && Date.now() > startDeadline) {
        summary.status = 'harness_never_started';
        break;
      }
      if (Date.now() > deadline) {
        summary.status = 'timeout';
        break;
      }
    }
    if (summary.status !== 'complete') {
      appendFileSync(args.log, `runner| stopped with status ${summary.status}\n`);
    }
    try {
      const stopped = await client.callTool('stop_project', {});
      let finalOutput = [];
      let finalErrors = [];
      try {
        const parsed = JSON.parse(stopped);
        finalOutput = Array.isArray(parsed.finalOutput) ? parsed.finalOutput : [];
        finalErrors = Array.isArray(parsed.finalErrors) ? parsed.finalErrors : [];
      } catch {
        // The server reported plain text; nothing extra to append.
      }
      const tail = finalOutput.slice(writtenOutput);
      if (tail.length > 0) appendFileSync(args.log, tail.map((line) => `out| ${line}`).join('\n') + '\n');
      if (finalErrors.length > writtenErrors) {
        appendFileSync(args.log, finalErrors.slice(writtenErrors).map((line) => `err| ${line}`).join('\n') + '\n');
      }
    } catch {
      // The process may already have exited on its own after quit(0).
    }
  } finally {
    const closed = await client.close();
    summary.exit = closed;
    summary.seconds = Math.round((Date.now() - startedAt) / 100) / 10;
  }
  console.log(JSON.stringify(summary, null, 2));
  process.exit(summary.status === 'complete' ? 0 : 1);
}

main().catch((error) => {
  console.error(String(error?.stack ?? error));
  process.exit(2);
});
