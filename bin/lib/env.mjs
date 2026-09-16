// Gedeelde helpers: paden en het inlezen van de env-bestanden.
import { existsSync, readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join, resolve as pathResolve } from 'node:path';
import { fileURLToPath } from 'node:url';

/** Repo-root (dit bestand staat in bin/lib/). */
export const ROOT = pathResolve(dirname(fileURLToPath(import.meta.url)), '..', '..');

/** Secrets staan buiten de repo, zodat ze alle projecten overleven. */
export const SECRETS =
  process.env.STAMBOOM_SECRETS || join(homedir(), '.config', 'stamboom', 'secrets.env');

/** Per-project variabelen (boom, webtrees-URL, root-persoon). */
export const PROJECT_ENV = join(ROOT, 'config', 'project.env');

export function parseEnvFile(path) {
  if (!existsSync(path)) return {};
  const out = {};
  for (const raw of readFileSync(path, 'utf8').split('\n')) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const eq = line.indexOf('=');
    if (eq === -1) continue;
    const key = line.slice(0, eq).trim();
    let value = line.slice(eq + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    out[key] = value;
  }
  return out;
}

/** Variabelen met precedentie: process.env > project.env > secrets.env > $HOME. */
export function loadProvided() {
  return {
    HOME: homedir(),
    ...parseEnvFile(SECRETS),
    ...parseEnvFile(PROJECT_ENV),
    ...process.env,
  };
}
