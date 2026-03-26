import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { createRequestHandler } from '../request-router.ts';
import { SessionStore } from '../session-store.ts';
import type { SessionState } from '../types.ts';
import type { DeviceInfo } from '../../utils/device.ts';
import { LeaseRegistry } from '../lease-registry.ts';

const ANDROID_DEVICE: DeviceInfo = {
  platform: 'android',
  id: 'emulator-5554',
  name: 'Pixel',
  kind: 'emulator',
  booted: true,
};

function makeStore(): SessionStore {
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'agent-device-router-screenshot-'));
  return new SessionStore(path.join(tempRoot, 'sessions'));
}

function makeSession(name: string): SessionState {
  return {
    name,
    device: ANDROID_DEVICE,
    createdAt: Date.now(),
    actions: [],
  };
}

test('screenshot resolves relative positional path against request cwd', async () => {
  const callerCwd = fs.mkdtempSync(path.join(os.tmpdir(), 'agent-device-screenshot-cwd-caller-'));
  const sessionStore = makeStore();
  sessionStore.set('default', makeSession('default'));

  let capturedPath: string | undefined;
  const handler = createRequestHandler({
    logPath: path.join(os.tmpdir(), 'daemon.log'),
    token: 'test-token',
    sessionStore,
    leaseRegistry: new LeaseRegistry(),
    trackDownloadableArtifact: () => 'artifact-id',
    dispatchCommand: async (_device, command, positionals) => {
      if (command === 'screenshot') {
        capturedPath = positionals[0];
      }
      return {};
    },
  });

  await handler({
    token: 'test-token',
    session: 'default',
    command: 'screenshot',
    positionals: ['evidence/test.png'],
    meta: { cwd: callerCwd, requestId: 'req-1' },
  });

  assert.ok(capturedPath, 'dispatch should have been called with a path');
  assert.equal(capturedPath, path.join(callerCwd, 'evidence/test.png'));
  assert.ok(path.isAbsolute(capturedPath), 'path passed to dispatch must be absolute');
  const recordedAction = sessionStore.get('default')?.actions.at(-1);
  assert.deepEqual(recordedAction?.positionals, [path.join(callerCwd, 'evidence/test.png')]);
});

test('screenshot keeps absolute positional path unchanged', async () => {
  const sessionStore = makeStore();
  sessionStore.set('default', makeSession('default'));

  const absolutePath = path.join(os.tmpdir(), 'evidence/test.png');
  let capturedPath: string | undefined;

  const handler = createRequestHandler({
    logPath: path.join(os.tmpdir(), 'daemon.log'),
    token: 'test-token',
    sessionStore,
    leaseRegistry: new LeaseRegistry(),
    trackDownloadableArtifact: () => 'artifact-id',
    dispatchCommand: async (_device, command, positionals) => {
      if (command === 'screenshot') {
        capturedPath = positionals[0];
      }
      return {};
    },
  });

  await handler({
    token: 'test-token',
    session: 'default',
    command: 'screenshot',
    positionals: [absolutePath],
    meta: { cwd: '/some/other/dir', requestId: 'req-2' },
  });

  assert.equal(capturedPath, absolutePath);
  const recordedAction = sessionStore.get('default')?.actions.at(-1);
  assert.deepEqual(recordedAction?.positionals, [absolutePath]);
});

test('screenshot resolves --out flag path against request cwd', async () => {
  const callerCwd = fs.mkdtempSync(path.join(os.tmpdir(), 'agent-device-screenshot-out-cwd-'));
  const sessionStore = makeStore();
  sessionStore.set('default', makeSession('default'));

  let capturedOut: string | undefined;

  const handler = createRequestHandler({
    logPath: path.join(os.tmpdir(), 'daemon.log'),
    token: 'test-token',
    sessionStore,
    leaseRegistry: new LeaseRegistry(),
    trackDownloadableArtifact: () => 'artifact-id',
    dispatchCommand: async (_device, command, _positionals, outPath) => {
      if (command === 'screenshot') {
        capturedOut = outPath;
      }
      return {};
    },
  });

  await handler({
    token: 'test-token',
    session: 'default',
    command: 'screenshot',
    positionals: [],
    flags: { out: 'evidence/test.png' },
    meta: { cwd: callerCwd, requestId: 'req-3' },
  });

  assert.ok(capturedOut, 'dispatch should have been called with out path');
  assert.equal(capturedOut, path.join(callerCwd, 'evidence/test.png'));
  assert.ok(path.isAbsolute(capturedOut), 'out path passed to dispatch must be absolute');
  const recordedAction = sessionStore.get('default')?.actions.at(-1);
  assert.equal(recordedAction?.flags.out, path.join(callerCwd, 'evidence/test.png'));
});
