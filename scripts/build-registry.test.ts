import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { buildRegistry } from './build-registry';
import { mkdirSync, writeFileSync, rmSync } from 'fs';
import { resolve } from 'path';
import { tmpdir } from 'os';

describe('buildRegistry', () => {
  let tmpDir: string;

  beforeEach(() => {
    tmpDir = resolve(tmpdir(), `marketplace-test-${Date.now()}`);
    mkdirSync(resolve(tmpDir, 'plugins/my-plugin'), { recursive: true });
    writeFileSync(
      resolve(tmpDir, 'plugins/my-plugin/plugin.json'),
      JSON.stringify({
        name: 'my-plugin',
        version: '1.2.0',
        description: 'A test plugin',
        author: 'Tester',
      })
    );
  });

  afterEach(() => {
    rmSync(tmpDir, { recursive: true, force: true });
  });

  it('finds one plugin', () => {
    const registry = buildRegistry(tmpDir);
    expect(registry.plugins).toHaveLength(1);
  });

  it('maps plugin fields correctly', () => {
    const { plugins } = buildRegistry(tmpDir);
    expect(plugins[0].name).toBe('my-plugin');
    expect(plugins[0].version).toBe('1.2.0');
    expect(plugins[0].description).toBe('A test plugin');
    expect(plugins[0].author).toBe('Tester');
    expect(plugins[0].installPath).toBe('plugins/my-plugin');
  });

  it('sets registry version to 1', () => {
    expect(buildRegistry(tmpDir).version).toBe(1);
  });

  it('returns empty plugins when directory is empty', () => {
    rmSync(resolve(tmpDir, 'plugins'), { recursive: true });
    mkdirSync(resolve(tmpDir, 'plugins'), { recursive: true });
    expect(buildRegistry(tmpDir).plugins).toHaveLength(0);
  });

  it('handles multiple plugins', () => {
    mkdirSync(resolve(tmpDir, 'plugins/second-plugin'), { recursive: true });
    writeFileSync(
      resolve(tmpDir, 'plugins/second-plugin/plugin.json'),
      JSON.stringify({ name: 'second-plugin', version: '0.1.0', description: '', author: '' })
    );
    expect(buildRegistry(tmpDir).plugins).toHaveLength(2);
  });
});
