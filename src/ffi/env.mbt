///|
/// Get an environment variable value. Returns empty string if not found.
pub extern "js" fn get_env(name : String) -> String =
  #|(name) => { try { return globalThis.process.env[name] || ''; } catch { return ''; } }
