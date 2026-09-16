#!/usr/bin/env node
// Rendert config/mcp.servers.json naar de configuratieformaten van
// opencode (opencode.json), Claude Code (.mcp.json) en codex (.codex/config.toml).
//
//   node bin/render-config.mjs           # schrijven
//   node bin/render-config.mjs --check   # alleen valideren + tonen
//
// Bron van variabelen (hoogste wint):
//   process.env  >  config/project.env  >  ~/.config/stamboom/secrets.env  >  defaults uit _vars
//
// ${TOKEN} wordt NOOIT ingevuld: die blijft een verwijzing naar de omgevingsvariabele
// en wordt per client in de juiste vorm geëmit.

import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { ROOT, parseEnvFile, loadProvided } from './lib/env.mjs';

/** Placeholders die niet worden ingevuld maar als env-referentie worden geëmit. */
const ENV_REFS = new Set(['TOKEN']);

// --- env-bestanden lezen ----------------------------------------------------

// --- placeholders uitbreiden ------------------------------------------------

/** Vindt de bij ${ horende sluitende } en houdt rekening met nesting. */
function findClosingBrace(str, openIdx) {
  let level = 0;
  for (let j = openIdx; j < str.length; j++) {
    if (str[j] === '{') level++;
    else if (str[j] === '}') {
      level--;
      if (level === 0) return j;
    }
  }
  return -1;
}

function lookup(name, ctx, depth) {
  const val = ctx[name];
  if (val !== undefined && val !== '') return expand(String(val), ctx, depth + 1);
  return '';
}

/**
 * Expandert ${VAR}, ${VAR:-default}, ${VAR-default} en $VAR, met ondersteuning voor
 * geneste placeholders in default-waarden. ${TOKEN} blijft ongemoeid (env-referentie).
 */
function expand(str, ctx, depth = 0) {
  if (typeof str !== 'string' || depth > 12) return str;
  let out = '';
  for (let i = 0; i < str.length; i++) {
    if (str[i] !== '$') {
      out += str[i];
      continue;
    }
    if (str[i + 1] === '{') {
      const close = findClosingBrace(str, i + 1);
      if (close === -1) {
        out += str[i];
        continue;
      }
      const body = str.slice(i + 2, close);
      const m = /^([A-Za-z_][A-Za-z0-9_]*)(:-|-)?(.*)$/s.exec(body);
      if (!m) {
        out += str.slice(i, close + 1);
        i = close;
        continue;
      }
      const [, name, sep, def] = m;
      if (ENV_REFS.has(name)) {
        out += str.slice(i, close + 1);
      } else if (ctx[name] !== undefined && ctx[name] !== '') {
        out += lookup(name, ctx, depth);
      } else if (sep) {
        out += expand(def, ctx, depth + 1);
      }
      i = close;
      continue;
    }
    const m = /^[A-Za-z_][A-Za-z0-9_]*/.exec(str.slice(i + 1));
    if (m) {
      out += lookup(m[0], ctx, depth);
      i += m[0].length;
      continue;
    }
    out += str[i];
  }
  return out;
}

function resolveCommand(cmd) {
  if (typeof cmd !== 'string' || cmd.includes('/')) return cmd;
  for (const dir of (process.env.PATH || '').split(':')) {
    if (!dir) continue;
    const candidate = join(dir, cmd);
    if (existsSync(candidate)) return candidate;
  }
  return cmd;
}

// --- inlezen ----------------------------------------------------------------

const cfg = JSON.parse(readFileSync(join(ROOT, 'config', 'mcp.servers.json'), 'utf8'));

const provided = loadProvided();

const vars = {};
for (const [k, spec] of Object.entries(cfg._vars || {})) {
  vars[k] = expand(spec, provided);
}

/** Chrome/Chromium opsporen voor de FamilySearch browser-login (BRAVE_PATH). */
function detectChrome() {
  const candidates = [
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    '/Applications/Brave Browser.app/Contents/MacOS/Brave Browser',
    '/Applications/Chromium.app/Contents/MacOS/Chromium',
    '/usr/bin/google-chrome',
    '/usr/bin/google-chrome-stable',
    '/usr/bin/chromium',
    '/usr/bin/chromium-browser',
    '/snap/bin/chromium',
  ];
  return candidates.find((p) => existsSync(p)) || '';
}

if (!vars.CHROME_PATH) vars.CHROME_PATH = detectChrome();

const ctx = { ...vars, ...provided };

const warnings = [];

function prepare(serverName, server) {
  const command = (server.command || []).map((c) => expand(c, ctx)).map(resolveCommand);
  const env = {};
  const envRefs = [];
  for (const [k, v] of Object.entries(server.environment || {})) {
    if (/^\$\{[A-Za-z_][A-Za-z0-9_]*\}$/.test(v) && ENV_REFS.has(v.slice(2, -1))) {
      envRefs.push(v.slice(2, -1));
    } else {
      const expanded = expand(v, ctx);
      if (expanded !== '') env[k] = expanded;
    }
  }
  return {
    name: serverName,
    type: server.type,
    command,
    env,
    envRefs,
    url: server.url ? expand(server.url, ctx) : undefined,
    timeout: server.timeout,
    enabled: server.enabled !== false,
  };
}

const servers = Object.entries(cfg.servers).map(([n, s]) => prepare(n, s));

// --- emitters ---------------------------------------------------------------

function emitOpencode() {
  const mcp = {};
  for (const s of servers) {
    if (s.type === 'remote') {
      mcp[s.name] = { type: 'remote', url: s.url, enabled: s.enabled };
      continue;
    }
    const environment = { ...s.env };
    for (const ref of s.envRefs) environment[ref] = `{env:${ref}}`;
    const entry = { type: 'local', command: s.command, enabled: s.enabled };
    if (Object.keys(environment).length) entry.environment = environment;
    if (s.timeout) entry.timeout = s.timeout;
    mcp[s.name] = entry;
  }
  return `${JSON.stringify(
    {
      $schema: 'https://opencode.ai/config.json',
      permission: { webfetch: 'allow', websearch: 'allow' },
      mcp,
    },
    null,
    2,
  )}\n`;
}

function emitClaudeMcp() {
  const mcpServers = {};
  for (const s of servers) {
    if (s.type === 'remote') {
      mcpServers[s.name] = { type: 'http', url: s.url };
      continue;
    }
    const env = { ...s.env };
    for (const ref of s.envRefs) env[ref] = `\${${ref}}`;
    const entry = { command: s.command[0], args: s.command.slice(1) };
    if (Object.keys(env).length) entry.env = env;
    mcpServers[s.name] = entry;
  }
  return `${JSON.stringify({ mcpServers }, null, 2)}\n`;
}

function tomlString(s) {
  return `"${String(s).replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`;
}

function emitCodexToml() {
  const out = [
    '# Gegenereerd door bin/render-config.mjs — niet handmatig aanpassen.',
    '',
  ];
  for (const s of servers) {
    out.push(`[mcp_servers.${s.name}]`);
    if (s.type === 'remote') {
      out.push(`url = ${tomlString(s.url)}`);
    } else {
      out.push(`command = ${tomlString(s.command[0])}`);
      const args = s.command.slice(1).map(tomlString).join(', ');
      out.push(`args = [${args}]`);
      if (s.envRefs.length) {
        out.push(`env_vars = [${s.envRefs.map(tomlString).join(', ')}]`);
      }
      if (s.timeout) out.push(`startup_timeout_sec = ${Math.round(s.timeout / 1000)}`);
    }
    if (Object.keys(s.env).length) {
      out.push('');
      out.push(`[mcp_servers.${s.name}.env]`);
      for (const [k, v] of Object.entries(s.env)) out.push(`${k} = ${tomlString(v)}`);
    }
    out.push('');
  }
  return out.join('\n');
}

// --- validatie --------------------------------------------------------------

for (const s of servers) {
  if (!s.name) warnings.push('server zonder naam');
  if (s.type === 'remote' && !s.url) warnings.push(`${s.name}: remote zonder url`);
  if (s.type === 'local') {
    if (!s.command.length) warnings.push(`${s.name}: local zonder command`);
    for (const c of s.command) {
      if (c.startsWith('/') && !existsSync(c)) {
        warnings.push(`${s.name}: pad bestaat nog niet -> ${c}`);
      }
    }
  }
}

const checkOnly = process.argv.includes('--check');
const outputs = {
  'opencode.json': emitOpencode(),
  '.mcp.json': emitClaudeMcp(),
  '.codex/config.toml': emitCodexToml(),
};

if (checkOnly) {
  for (const [file, content] of Object.entries(outputs)) {
    let ok = true;
    try {
      if (file.endsWith('.json')) JSON.parse(content);
    } catch (err) {
      ok = false;
      warnings.push(`${file}: ongeldige JSON (${err.message})`);
    }
    console.log(`${ok ? 'ok  ' : 'FAIL'} ${file}  (${content.length} bytes)`);
  }
} else {
  for (const [file, content] of Object.entries(outputs)) {
    const target = join(ROOT, file);
    mkdirSync(dirname(target), { recursive: true });
    writeFileSync(target, content);
    console.log(`geschreven: ${file}`);
  }
}

if (warnings.length) {
  console.log('\nwaarschuwingen:');
  for (const w of warnings) console.log(`  - ${w}`);
  if (!checkOnly && warnings.some((w) => w.includes('ongeldige'))) process.exitCode = 1;
} else {
  console.log('\ngeen waarschuwingen.');
}
