///|
/// Perform an SSE streaming fetch request (synchronous via curl).
/// headers_json and body are JSON strings.
/// timeout_sec: 0 means no timeout.
/// on_line is called for each SSE data line (without "data: " prefix).
/// on_error is called on error.
/// on_done is called when the stream is complete.
pub extern "js" fn js_fetch_sse(
  url : String,
  http_method : String,
  headers_json : String,
  body : String,
  timeout_sec : Int,
  on_line : (String) -> Unit,
  on_error : (String) -> Unit,
  on_done : () -> Unit,
) -> Unit =
  #|(url, httpMethod, headersJson, body, timeoutSec, onLine, onError, onDone) => {
  #|  try {
  #|    const { spawnSync } = require('child_process');
  #|    const headers = JSON.parse(headersJson);
  #|    const args = ['-sS', '-X', httpMethod, url];
  #|    if (timeoutSec > 0) { args.push('--max-time', String(timeoutSec)); }
  #|    for (const [key, value] of Object.entries(headers)) {
  #|      args.push('-H', `${key}: ${value}`);
  #|    }
  #|    if (body) { args.push('-d', body); }
  #|    const result = spawnSync('curl', args, { encoding: 'utf-8', maxBuffer: 50 * 1024 * 1024 });
  #|    if (result.error) { onError(result.error.message || String(result.error)); return; }
  #|    if (result.status !== 0) { onError(`curl exit code ${result.status}: ${result.stderr}`); return; }
  #|    const stdout = result.stdout || '';
  #|    const lines = stdout.split('\n');
  #|    for (const line of lines) {
  #|      const trimmed = line.trim();
  #|      if (trimmed.startsWith('data: ')) {
  #|        const data = trimmed.slice(6);
  #|        if (data !== '[DONE]') { onLine(data); }
  #|      }
  #|    }
  #|    onDone();
  #|  } catch (e) {
  #|    onError(e.message || String(e));
  #|  }
  #|}

///|
/// Perform a non-streaming fetch request (synchronous via curl).
/// Returns the response body as a string.
/// timeout_sec: 0 means no timeout.
pub extern "js" fn js_fetch(
  url : String,
  http_method : String,
  headers_json : String,
  body : String,
  timeout_sec : Int,
  on_result : (String) -> Unit,
  on_error : (String) -> Unit,
) -> Unit =
  #|(url, httpMethod, headersJson, body, timeoutSec, onResult, onError) => {
  #|  try {
  #|    const { spawnSync } = require('child_process');
  #|    const headers = JSON.parse(headersJson);
  #|    const args = ['-sS', '-X', httpMethod, url];
  #|    if (timeoutSec > 0) { args.push('--max-time', String(timeoutSec)); }
  #|    for (const [key, value] of Object.entries(headers)) {
  #|      args.push('-H', `${key}: ${value}`);
  #|    }
  #|    if (body) { args.push('-d', body); }
  #|    const result = spawnSync('curl', args, { encoding: 'utf-8', maxBuffer: 50 * 1024 * 1024 });
  #|    if (result.error) { onError(result.error.message || String(result.error)); return; }
  #|    if (result.status !== 0) { onError(`curl exit code ${result.status}: ${result.stderr}`); return; }
  #|    onResult(result.stdout || '');
  #|  } catch (e) {
  #|    onError(e.message || String(e));
  #|  }
  #|}
