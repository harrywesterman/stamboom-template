#!/usr/bin/env node
// Healthcheck: start elke lokale MCP-server kort, doet de MCP-handshake en telt de
// tools. Remote servers worden op bereikbaarheid getest.
//
//   node bin/doctor.mjs [--verbose]
//
// Exitcode 0 = geen rode regels, 1 = minstens één harde fout.

import { spawn } from 'node:child_process';
import { existsSync, readFileSync, realpathSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { ROOT, SECRETS, loadProvided } from './lib/env.mjs';

const VERBOSE = process.argv.includes('--verbose');
const TIMEOUT_MS = Number(process.env.DOCTOR_TIMEOUT_MS || 60000);

const useColor = process.stdout.isTTY;
const c = (code) => (useColor ? `\u001b[${code}m` : '');
const paint = (txt, code) => `${c(code)}${txt}${c(0)}`;
const ok = (name, msg) => console.log(`  ${paint('ok', 32)}    ${name.padEnd(22)} ${msg}`);
const skip = (name, msg) => console.log(`  ${paint('skip', 33)}  ${name.padEnd(22)} ${msg}`);
const warn = (name, msg) => console.log(`  ${paint('warn', 33)}  ${name.padEnd(22)} ${msg}`);
const fail = (name, msg) => console.log(`  ${paint('FOUT', 31)}  ${name.padEnd(22)} ${msg}`);

const problems = [];
const provided = loadProvided();

function resolveEnvValue(value) {
  if (typeof value !== 'string') return value;
  return value
    .replace(/\{env:([A-Za-z_][A-Za-z0-9_]*)\}/g, (_, n) => provided[n] ?? '')
    .replace(/\$\{([A-Za-z_][A-Za-z0-9_]*)\}/g, (_, n) => provided[n] ?? '');
}

/** MCP-handshake over stdio; geeft het aantal tools terug. */
function pingStdio(name, command, env, timeoutMs = TIMEOUT_MS) {
  return new Promise((resolve) => {
    let child;
    try {
      child = spawn(command[0], command.slice(1), {
        env: { ...process.env, ...env },
        stdio: ['pipe', 'pipe', 'pipe'],
      });
    } catch (err) {
      return resolve({ ok: false, msg: `kon niet starten: ${err.message}` });
    }

    let buf = '';
    let settled = false;
    let stderr = '';
    const done = (result) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      try { child.kill('SIGTERM'); } catch { /* negeren */ }
      resolve(result);
    };

    const timer = setTimeout(() => {
      done({ ok: false, msg: `${timeoutMs / 1000}s timeout`, stderr });
    }, timeoutMs);

    child.on('error', (err) => done({ ok: false, msg: err.message }));
    child.stderr.on('data', (d) => { stderr += d.toString(); });

    const send = (obj) => { try { child.stdin.write(`${JSON.stringify(obj)}\n`); } catch { /* negeren */ } };

    let handshaken = false;
    child.stdout.on('data', (chunk) => {
      buf += chunk.toString();
      let idx;
      while ((idx = buf.indexOf('\n')) !== -1) {
        const line = buf.slice(0, idx).trim();
        buf = buf.slice(idx + 1);
        if (!line) continue;
        let msg;
        try { msg = JSON.parse(line); } catch { continue; }
        if (msg.id === 1 && !handshaken) {
          handshaken = true;
          send({ jsonrpc: '2.0', method: 'notifications/initialized' });
          send({ jsonrpc: '2.0', id: 2, method: 'tools/list' });
        } else if (msg.id === 2) {
          const tools = msg.result?.tools ?? [];
          done({ ok: true, msg: `${tools.length} tools`, tools });
        } else if (msg.error) {
          done({ ok: false, msg: msg.error.message || 'fout tijdens handshake' });
        }
      }
    });

    send({
      jsonrpc: '2.0',
      id: 1,
      method: 'initialize',
      params: {
        protocolVersion: '2024-11-05',
        capabilities: {},
        clientInfo: { name: 'stamboom-doctor', version: '1' },
      },
    });
  });
}

async function pingRemote(url) {
  try {
    const res = await fetch(url, { signal: AbortSignal.timeout(15000) });
    return { ok: true, msg: `bereikbaar (HTTP ${res.status})` };
  } catch (err) {
    return { ok: false, msg: `onbereikbaar: ${err.message}` };
  }
}

// --- serverlijst uit de gegenereerde opencode-config ------------------------

const opencodePath = join(ROOT, 'opencode.json');

console.log(paint('stamboom doctor', 1));
console.log(`  project:  ${ROOT}`);
console.log(`  secrets:  ${SECRETS} ${existsSync(SECRETS) ? '' : paint('(ontbreekt)', 33)}`);
console.log('');

if (!existsSync(opencodePath)) {
  fail('configuratie', 'opencode.json ontbreekt — draai eerst ./setup.sh');
  process.exit(1);
}

const cfg = JSON.parse(readFileSync(opencodePath, 'utf8'));
const servers = Object.entries(cfg.mcp || {});

console.log(paint('MCP-servers', 1));
for (const [name, server] of servers) {
  if (server.enabled === false) {
    skip(name, 'uitgeschakeld');
    continue;
  }
  if (server.type === 'remote') {
    const r = await pingRemote(server.url);
    if (r.ok) ok(name, r.msg);
    else {
      fail(name, r.msg);
      problems.push(name);
    }
    continue;
  }

  // Realpath: sommige bridges vergelijken import.meta.url met argv[1], en dat
  // mislukt zodra het pad via een symlink loopt (bv. /tmp -> /private/tmp).
  const command = server.command.map(resolveEnvValue).map((part) => {
    try {
      return part.startsWith('/') && existsSync(part) ? realpathSync(part) : part;
    } catch {
      return part;
    }
  });
  const env = {};
  for (const [k, v] of Object.entries(server.environment || {})) {
    const resolved = resolveEnvValue(v);
    if (resolved === '' && /TOKEN/.test(k)) {
      warn(name, `${k} is leeg — vul ${SECRETS} in`);
      problems.push(name);
      env[k] = resolved;
      continue;
    }
    env[k] = resolved;
  }

  if (command[0] && command[0].startsWith('/') && !existsSync(command[0])) {
    fail(name, `commando ontbreekt: ${command[0]} — draai ./setup.sh`);
    problems.push(name);
    continue;
  }

  const r = await pingStdio(name, command, env);
  if (r.ok) {
    ok(name, r.msg);
    if (VERBOSE && r.tools) {
      for (const t of r.tools) console.log(`           - ${t.name}`);
    }
  } else {
    const detail = VERBOSE && r.stderr ? ` :: ${r.stderr.trim().split('\n').slice(-2).join(' | ')}` : '';
    fail(name, r.msg + detail);
    problems.push(name);
  }
}

// --- lokale voorzieningen ---------------------------------------------------

console.log('');
console.log(paint('voorzieningen', 1));

const toolsDir = resolveEnvValue('{env:TOOLS_DIR}') || join(homedir(), '.local', 'share', 'stamboom-tools');
if (existsSync(toolsDir)) ok('tools-map', toolsDir);
else warn('tools-map', `${toolsDir} ontbreekt — draai ./setup.sh`);

const ocrModels = resolveEnvValue('{env:OCR_MODELS}') || join(homedir(), 'ocr-models');
for (const model of ['super.mlmodel', 'blla.mlmodel']) {
  const p = join(ocrModels, 'ARletta', 'models', model);
  if (existsSync(p)) ok(`model ${model}`, p);
  else warn(`model ${model}`, `${p} ontbreekt — draai ./setup.sh`);
}

const kraken = join(ocrModels, '.venv-kraken', 'bin', 'kraken');
if (existsSync(kraken)) ok('kraken', kraken);
else warn('kraken', 'venv ontbreekt — draai ./setup.sh');

const fsSession = join(homedir(), '.familysearch-mcp', 'config.json');
if (existsSync(fsSession)) ok('familysearch-sessie', fsSession);
else warn('familysearch-sessie', 'nog niet ingelogd — gebruik de MCP-tool familysearch_login-with-browser');

if (existsSync(join(ROOT, 'AGENTS.md'))) {
  const agents = readFileSync(join(ROOT, 'AGENTS.md'), 'utf8');
  if (agents.includes('{{')) warn('AGENTS.md', 'bevat nog placeholders — draai ./bin/init-project.sh');
  else ok('AGENTS.md', 'projectgegevens ingevuld');
}

console.log('');
if (problems.length) {
  console.log(paint(`${problems.length} probleem(en): ${problems.join(', ')}`, 31));
  process.exit(1);
}
console.log(paint('alles in orde', 32));
