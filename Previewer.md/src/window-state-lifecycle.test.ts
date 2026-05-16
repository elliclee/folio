import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, it } from 'node:test'
import assert from 'node:assert/strict'

const tauriLibPath = join(process.cwd(), 'src-tauri', 'src', 'lib.rs')

describe('window state lifecycle', () => {
  it('registers window state after Tauri creates configured windows', () => {
    const source = readFileSync(tauriLibPath, 'utf8')
    const setupIndex = source.indexOf('.setup(|app|')
    const registrationIndex = source.indexOf('register_existing_document_window_states(app.handle())')

    assert.notEqual(setupIndex, -1)
    assert.notEqual(registrationIndex, -1)
    assert.ok(registrationIndex > setupIndex)
  })
})
