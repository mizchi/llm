///|
/// Execute a command synchronously and return stdout.
pub extern "js" fn js_exec_sync(command : String, timeout_ms : Int) -> String =
  #|(command, timeoutMs) => {
  #|  try {
  #|    const { execSync } = require('child_process');
  #|    return execSync(command, { timeout: timeoutMs, encoding: 'utf-8' });
  #|  } catch (e) {
  #|    return 'ERROR: ' + (e.message || String(e));
  #|  }
  #|}

///|
/// Execute a command with streaming output (line by line).
/// Uses spawnSync for synchronous execution so callbacks fire before return.
pub extern "js" fn js_exec_stream(
  command : String,
  args_json : String,
  on_line : (String) -> Unit,
  on_done : () -> Unit,
  on_error : (String) -> Unit,
) -> Unit =
  #|(command, argsJson, onLine, onDone, onError) => {
  #|  try {
  #|    const { spawnSync } = require('child_process');
  #|    const args = JSON.parse(argsJson);
  #|    const result = spawnSync(command, args, { encoding: 'utf-8', maxBuffer: 50 * 1024 * 1024 });
  #|    if (result.error) { onError(result.error.message || String(result.error)); return; }
  #|    const stdout = result.stdout || '';
  #|    const lines = stdout.split('\n');
  #|    for (const line of lines) {
  #|      if (line.trim()) { onLine(line); }
  #|    }
  #|    onDone();
  #|  } catch (e) {
  #|    onError(e.message || String(e));
  #|  }
  #|}
