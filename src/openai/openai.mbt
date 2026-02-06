///|
/// OpenAI-compatible endpoint types.
pub(all) enum OpenAIEndpoint {
  OpenAI
  OpenRouter
  Ollama
  Cloudflare(account_id~ : String)
  Custom(base_url~ : String)
}

///|
fn OpenAIEndpoint::base_url(self : OpenAIEndpoint) -> String {
  match self {
    OpenAI => "https://api.openai.com"
    OpenRouter => "https://openrouter.ai/api"
    Ollama => "http://localhost:11434"
    Cloudflare(account_id~) =>
      "https://api.cloudflare.com/client/v4/accounts/" + account_id + "/ai"
    Custom(base_url~) => base_url
  }
}

///|
pub struct OpenAIProvider {
  config : @llm.ProviderConfig
  endpoint : OpenAIEndpoint
}

///|
pub fn OpenAIProvider::new(
  api_key : String,
  endpoint? : OpenAIEndpoint = OpenAI,
  model? : String = "gpt-4o",
  max_tokens? : Int = 4096,
  system_prompt? : String = "",
  base_url? : String,
  timeout_sec? : Int = 300,
  max_retries? : Int = 3,
) -> OpenAIProvider {
  let url = match base_url {
    Some(u) => u
    None => endpoint.base_url()
  }
  {
    config: @llm.ProviderConfig::new(
      api_key,
      model,
      url,
      max_tokens~,
      system_prompt~,
      timeout_sec~,
      max_retries~,
    ),
    endpoint,
  }
}

///|
/// Create an OpenAI-compatible provider for any endpoint (vLLM, LiteLLM, etc.).
pub fn OpenAIProvider::new_compat(
  base_url : String,
  model : String,
  api_key? : String = "",
  max_tokens? : Int = 4096,
  system_prompt? : String = "",
  timeout_sec? : Int = 300,
  max_retries? : Int = 3,
) -> OpenAIProvider {
  let endpoint = if api_key.is_empty() { Ollama } else { Custom(base_url~) }
  {
    config: @llm.ProviderConfig::new(
      api_key,
      model,
      base_url,
      max_tokens~,
      system_prompt~,
      timeout_sec~,
      max_retries~,
    ),
    endpoint,
  }
}

///|
fn build_openai_headers(api_key : String, endpoint : OpenAIEndpoint) -> Json {
  let headers : Map[String, Json] = {}
  headers["Content-Type"] = "application/json".to_json()
  match endpoint {
    Ollama => ()
    _ => headers["Authorization"] = ("Bearer " + api_key).to_json()
  }
  match endpoint {
    OpenRouter => {
      headers["HTTP-Referer"] = "https://github.com/mizchi/llm".to_json()
      headers["X-Title"] = "mizchi/llm".to_json()
    }
    _ => ()
  }
  Json::object(headers)
}

///|
fn build_openai_body(
  model : String,
  max_tokens : Int,
  system_prompt : String,
  messages : Array[@llm.Message],
  tools : Array[@llm.ToolDef],
) -> Json {
  let body : Map[String, Json] = {}
  body["model"] = model.to_json()
  body["max_tokens"] = Json::number(max_tokens.to_double())
  body["stream"] = Json::boolean(true)
  let stream_options : Map[String, Json] = {}
  stream_options["include_usage"] = Json::boolean(true)
  body["stream_options"] = Json::object(stream_options)
  // Build messages array with system prompt
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
fn get_str(j : Json, field : String, default : String) -> String {
  match @llm.json_get_string(j, field) {
    Some(s) => s
    None => default
  }
}

///|
fn get_int(j : Json, field : String, default : Int) -> Int {
  match @llm.json_get_int(j, field) {
    Some(n) => n
    None => default
  }
}

///|
/// Parse a single SSE data line from OpenAI-compatible streaming API.
pub fn parse_openai_event(data : String) -> @llm.StreamEvent? {
  let json = @json.parse(data) catch { _ => return None }
  // Check for error
  match @llm.json_get_object(json, "error") {
    Some(err) => {
      let msg = get_str(err, "message", "Unknown error")
      return Some(@llm.StreamEvent::Error(msg))
    }
    None => ()
  }
  // Get choices[0]
  let choices = match @llm.json_get_array(json, "choices") {
    Some(arr) => arr
    None =>
      // Usage-only chunk (choices is empty or absent)
      match @llm.json_get_object(json, "usage") {
        Some(u) => {
          let usage : @llm.Usage? = Some(@llm.Usage::{
            input_tokens: get_int(u, "prompt_tokens", 0),
            output_tokens: get_int(u, "completion_tokens", 0),
          })
          return Some(
            @llm.StreamEvent::MessageEnd(
              finish_reason=@llm.FinishReason::Stop,
              usage~,
            ),
          )
        }
        None => return None
      }
  }
  if choices.is_empty() {
    // Usage-only chunk with empty choices array
    match @llm.json_get_object(json, "usage") {
      Some(u) => {
        let usage : @llm.Usage? = Some(@llm.Usage::{
          input_tokens: get_int(u, "prompt_tokens", 0),
          output_tokens: get_int(u, "completion_tokens", 0),
        })
        return Some(
          @llm.StreamEvent::MessageEnd(
            finish_reason=@llm.FinishReason::Stop,
            usage~,
          ),
        )
      }
      None => return None
    }
  }
  let choice = choices[0]
  // Check finish_reason
  match @llm.json_get_string(choice, "finish_reason") {
    Some(reason) => {
      let finish_reason = @llm.FinishReason::from_string(reason)
      let usage : @llm.Usage? = match @llm.json_get_object(json, "usage") {
        Some(u) => {
          let inp = get_int(u, "prompt_tokens", 0)
          let out = get_int(u, "completion_tokens", 0)
          if inp == 0 && out == 0 {
            None
          } else {
            Some(@llm.Usage::{ input_tokens: inp, output_tokens: out })
          }
        }
        None => None
      }
      return Some(@llm.StreamEvent::MessageEnd(finish_reason~, usage~))
    }
    None => ()
  }
  // Get delta
  let delta = match @llm.json_get_object(choice, "delta") {
    Some(d) => d
    None => return None
  }
  // Check for text content
  match @llm.json_get_string(delta, "content") {
    Some(text) =>
      if not(text.is_empty()) {
        return Some(@llm.StreamEvent::TextDelta(text))
      }
    None => ()
  }
  // Check for tool_calls
  match @llm.json_get_array(delta, "tool_calls") {
    Some(tool_calls) =>
      for tc in tool_calls {
        let id = get_str(tc, "id", "")
        let index = get_int(tc, "index", 0)
        match @llm.json_get_object(tc, "function") {
          Some(func) => {
            let name = get_str(func, "name", "")
            let arguments = get_str(func, "arguments", "")
            if not(name.is_empty()) {
              // Tool call start
              return Some(
                @llm.StreamEvent::ToolCallStart(
                  id=if id.is_empty() { index.to_string() } else { id },
                  name~,
                ),
              )
            }
            if not(arguments.is_empty()) {
              return Some(
                @llm.StreamEvent::ToolCallDelta(
                  id=if id.is_empty() { index.to_string() } else { id },
                  input_delta=arguments,
                ),
              )
            }
          }
          None => ()
        }
      }
    None => ()
  }
  None
}

///|
pub impl @llm.Provider for OpenAIProvider with stream(
  self,
  messages,
  tools,
  handler,
) {
  let path = match self.endpoint {
    Cloudflare(..) => "/run/" + self.config.model
    _ => "/v1/chat/completions"
  }
  let url = self.config.base_url + path
  let headers = build_openai_headers(self.config.api_key, self.endpoint)
  let body = build_openai_body(
    self.config.model,
    self.config.max_tokens,
    self.config.system_prompt,
    messages,
    tools,
  )
  // Track tool calls for building ToolCallEnd events
  let active_tools : Map[String, (String, StringBuilder)] = {}
  // Hold pending MessageEnd to merge with a later usage-only chunk
  let pending_end : Ref[@llm.StreamEvent?] = { val: None }
  @ffi.js_fetch_sse(
    url,
    "POST",
    headers.stringify(),
    body.stringify(),
    self.config.timeout_sec,
    fn(line) {
      match parse_openai_event(line) {
        Some(event) =>
          match event {
            @llm.StreamEvent::ToolCallStart(id~, name~) => {
              active_tools[id] = (name, StringBuilder::new())
              (handler.on_event)(event)
            }
            @llm.StreamEvent::ToolCallDelta(id~, input_delta~) => {
              match active_tools.get(id) {
                Some((_, buf)) => buf.write_string(input_delta)
                None => ()
              }
              (handler.on_event)(event)
            }
            @llm.StreamEvent::MessageEnd(
              finish_reason=cur_reason,
              usage=cur_usage
            ) =>
              match pending_end.val {
                Some(
                  @llm.StreamEvent::MessageEnd(finish_reason=prev_reason, ..)
                ) => {
                  // This is the usage-only chunk; merge with pending
                  for entry in active_tools.iter2() {
                    let (tool_id, (tool_name, buf)) = entry
                    let input_str = buf.to_string()
                    let input = @json.parse(input_str) catch {
                      _ => Json::null()
                    }
                    (handler.on_event)(
                      @llm.StreamEvent::ToolCallEnd(
                        id=tool_id,
                        name=tool_name,
                        input~,
                      ),
                    )
                  }
                  active_tools.clear()
                  pending_end.val = None
                  (handler.on_event)(
                    @llm.StreamEvent::MessageEnd(
                      finish_reason=prev_reason,
                      usage=cur_usage,
                    ),
                  )
                }
                _ =>
                  // First MessageEnd (has finish_reason, may lack usage)
                  match cur_usage {
                    Some(_) => {
                      // Already has usage, emit directly
                      for entry in active_tools.iter2() {
                        let (tool_id, (tool_name, buf)) = entry
                        let input_str = buf.to_string()
                        let input = @json.parse(input_str) catch {
                          _ => Json::null()
                        }
                        (handler.on_event)(
                          @llm.StreamEvent::ToolCallEnd(
                            id=tool_id,
                            name=tool_name,
                            input~,
                          ),
                        )
                      }
                      active_tools.clear()
                      (handler.on_event)(
                        @llm.StreamEvent::MessageEnd(
                          finish_reason=cur_reason,
                          usage=cur_usage,
                        ),
                      )
                    }
                    None =>
                      // Hold it; usage chunk may follow
                      pending_end.val = Some(event)
                  }
              }
            _ => (handler.on_event)(event)
          }
        None => ()
      }
    },
    fn(error) { (handler.on_event)(@llm.StreamEvent::Error(error)) },
    fn() {
      // Flush pending MessageEnd if usage chunk never arrived
      match pending_end.val {
        Some(evt) => {
          for entry in active_tools.iter2() {
            let (tool_id, (tool_name, buf)) = entry
            let input_str = buf.to_string()
            let input = @json.parse(input_str) catch { _ => Json::null() }
            (handler.on_event)(
              @llm.StreamEvent::ToolCallEnd(id=tool_id, name=tool_name, input~),
            )
          }
          active_tools.clear()
          pending_end.val = None
          (handler.on_event)(evt)
        }
        None => ()
      }
    },
  )
}

///|
pub impl @llm.Provider for OpenAIProvider with name(self) -> String {
  match self.endpoint {
    OpenAI => "openai"
    OpenRouter => "openrouter"
    Ollama => "ollama"
    Cloudflare(..) => "cloudflare"
    Custom(..) => "custom"
  }
}

///|
/// Model info returned from OpenRouter /api/v1/models.
pub(all) struct ModelInfo {
  id : String
  name : String
  context_length : Int
  pricing_prompt : String
  pricing_completion : String
}

///|
pub impl Show for ModelInfo with output(self, logger) {
  logger.write_string(self.id)
  logger.write_string(" (")
  logger.write_string(self.name)
  logger.write_string(", ctx=")
  logger.write_string(self.context_length.to_string())
  logger.write_string(")")
}

///|
/// Fetch model list from OpenRouter API.
pub fn list_openrouter_models() -> Array[ModelInfo] {
  let models : Array[ModelInfo] = []
  let headers : Map[String, Json] = {}
  headers["Accept"] = "application/json".to_json()
  let headers_json = Json::object(headers).stringify()
  @ffi.js_fetch(
    "https://openrouter.ai/api/v1/models",
    "GET",
    headers_json,
    "",
    30,
    fn(body) {
      let json = @json.parse(body) catch { _ => return }
      let data = match @llm.json_get_array(json, "data") {
        Some(arr) => arr
        None => return
      }
      for item in data {
        let id = get_str(item, "id", "")
        let name = get_str(item, "name", "")
        let context_length = match @llm.json_get_int(item, "context_length") {
          Some(n) => n
          None => 0
        }
        let (pricing_prompt, pricing_completion) = match
          @llm.json_get_object(item, "pricing") {
          Some(p) => (get_str(p, "prompt", "0"), get_str(p, "completion", "0"))
          None => ("0", "0")
        }
        models.push({
          id,
          name,
          context_length,
          pricing_prompt,
          pricing_completion,
        })
      }
    },
    fn(_error) {  },
  )
  models
}
