// JS-only async companion to the streaming OpenAIProvider.
//
// Rationale: the sync `collect_text` path uses curl via spawnSync so two
// concurrent callers inside the same JS event loop serialize. For tasks where
// only the final text matters (e.g. summarization), issue a non-streaming
// request with `stream: false` and return a Promise[String] so callers can
// `Promise.all` / chunk many at once.
//
// Compiled only for the "js" target (see moon.pkg).

///|
/// Build the OpenAI-compat request body for a non-streaming completion.
fn build_openai_body_nonstream(
  model : String,
  max_tokens : Int,
  system_prompt : String,
  messages : Array[@llm.Message],
  tools : Array[@llm.ToolDef],
) -> Json {
  let body : Map[String, Json] = {}
  body["model"] = model.to_json()
  body["max_tokens"] = Json::number(max_tokens.to_double())
  body["stream"] = Json::boolean(false)
  let msgs : Array[Json] = []
  if not(system_prompt.is_empty()) {
    msgs.push(@llm.Message::system(system_prompt).to_openai_json())
  }
  for msg in messages {
    msgs.push(msg.to_openai_json())
  }
  body["messages"] = Json::array(msgs)
  if not(tools.is_empty()) {
    body["tools"] = Json::array(tools.map(@llm.ToolDef::to_openai_json))
  }
  Json::object(body)
}

///|
/// JS-only async variant of `collect_text`. Issues a non-streaming request and
/// returns a `Promise[String]` that resolves to the assistant text, or `""`
/// on network/HTTP/parse error. Designed for concurrent summarization.
///
/// For errors the promise resolves to `""` rather than rejecting; callers
/// typically already have a sync fallback path and don't want to plumb
/// exceptions through a fan-out of parallel requests.
pub fn OpenAIProvider::collect_text_async(
  self : OpenAIProvider,
  messages : Array[@llm.Message],
  tools? : Array[@llm.ToolDef] = [],
) -> @ffi.Promise[String] {
  let path = match self.endpoint {
    Cloudflare(..) => "/run/" + self.config.model
    _ => "/v1/chat/completions"
  }
  let url = self.config.base_url + path
  let headers = build_openai_headers(self.config.api_key, self.endpoint)
  let body = build_openai_body_nonstream(
    self.config.model,
    self.config.max_tokens,
    self.config.system_prompt,
    messages,
    tools,
  )
  js_openai_collect_text_async(
    url,
    headers.stringify(),
    body.stringify(),
    self.config.timeout_sec,
  )
}

///|
/// JS implementation: fetch + parse OpenAI response → choices[0].message.content.
extern "js" fn js_openai_collect_text_async(
  url : String,
  headers_json : String,
  body_json : String,
  timeout_sec : Int,
) -> @ffi.Promise[String] =
  #| (url, headersJson, bodyJson, timeoutSec) => {
  #|   return (async () => {
  #|     try {
  #|       const headers = JSON.parse(headersJson);
  #|       const controller = new AbortController();
  #|       const timer = timeoutSec > 0
  #|         ? setTimeout(() => controller.abort(), timeoutSec * 1000)
  #|         : null;
  #|       try {
  #|         const res = await fetch(url, {
  #|           method: 'POST',
  #|           headers,
  #|           body: bodyJson,
  #|           signal: controller.signal,
  #|         });
  #|         const text = await res.text();
  #|         if (!res.ok) return '';
  #|         try {
  #|           const json = JSON.parse(text);
  #|           const content = json && json.choices && json.choices[0]
  #|             && json.choices[0].message && json.choices[0].message.content;
  #|           return typeof content === 'string' ? content : '';
  #|         } catch {
  #|           return '';
  #|         }
  #|       } finally {
  #|         if (timer) clearTimeout(timer);
  #|       }
  #|     } catch {
  #|       return '';
  #|     }
  #|   })();
  #| }
