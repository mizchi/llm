///|
pub struct AnthropicProvider {
  config : @llm.ProviderConfig
}

///|
pub fn AnthropicProvider::new(
  api_key : String,
  model? : String = "claude-sonnet-4-20250514",
  max_tokens? : Int = 4096,
  system_prompt? : String = "",
  base_url? : String = "https://api.anthropic.com",
  timeout_sec? : Int = 300,
  max_retries? : Int = 3,
) -> AnthropicProvider {
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
  }
}

///|
fn build_anthropic_headers(api_key : String) -> Json {
  {
    "Content-Type": "application/json".to_json(),
    "x-api-key": api_key.to_json(),
    "anthropic-version": "2023-06-01".to_json(),
  }
}

///|
fn build_anthropic_body(
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
  if not(system_prompt.is_empty()) {
    body["system"] = system_prompt.to_json()
  }
  let msgs : Array[Json] = []
  for msg in messages {
    match msg.role {
      System => ()
      _ => msgs.push(msg.to_anthropic_json())
    }
  }
  body["messages"] = Json::array(msgs)
  if not(tools.is_empty()) {
    body["tools"] = Json::array(tools.map(@llm.ToolDef::to_anthropic_json))
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
/// Parse a single SSE data line from Anthropic's streaming API.
pub fn parse_anthropic_event(data : String) -> @llm.StreamEvent? {
  let json = @json.parse(data) catch { _ => return None }
  let event_type = @llm.json_get_string(json, "type")
  match event_type {
    Some("message_start") => Some(@llm.StreamEvent::MessageStart)
    Some("content_block_start") =>
      match @llm.json_get_object(json, "content_block") {
        Some(block) =>
          match @llm.json_get_string(block, "type") {
            Some("tool_use") => {
              let id = get_str(block, "id", "")
              let name = get_str(block, "name", "")
              Some(@llm.StreamEvent::ToolCallStart(id~, name~))
            }
            _ => None
          }
        None => None
      }
    Some("content_block_delta") =>
      match @llm.json_get_object(json, "delta") {
        Some(d) =>
          match @llm.json_get_string(d, "type") {
            Some("text_delta") => {
              let text = get_str(d, "text", "")
              Some(@llm.StreamEvent::TextDelta(text))
            }
            Some("input_json_delta") => {
              let partial = get_str(d, "partial_json", "")
              let index = get_int(json, "index", 0)
              Some(
                @llm.StreamEvent::ToolCallDelta(
                  id=index.to_string(),
                  input_delta=partial,
                ),
              )
            }
            _ => None
          }
        None => None
      }
    Some("content_block_stop") => None
    Some("message_delta") =>
      match @llm.json_get_object(json, "delta") {
        Some(d) => {
          let stop_reason = get_str(d, "stop_reason", "stop")
          let finish_reason = @llm.FinishReason::from_string(stop_reason)
          let usage : @llm.Usage? = match @llm.json_get_object(json, "usage") {
            Some(u) => {
              let input_tokens = get_int(u, "input_tokens", 0)
              let output_tokens = get_int(u, "output_tokens", 0)
              Some(@llm.Usage::{ input_tokens, output_tokens })
            }
            None => None
          }
          Some(@llm.StreamEvent::MessageEnd(finish_reason~, usage~))
        }
        None => None
      }
    Some("error") => {
      let msg = match @llm.json_get_object(json, "error") {
        Some(e) => get_str(e, "message", "Unknown error")
        None => "Unknown error"
      }
      Some(@llm.StreamEvent::Error(msg))
    }
    _ => None
  }
}

///|
pub impl @llm.Provider for AnthropicProvider with stream(
  self,
  messages,
  tools,
  handler,
) {
  let url = self.config.base_url + "/v1/messages"
  let headers = build_anthropic_headers(self.config.api_key)
  let body = build_anthropic_body(
    self.config.model,
    self.config.max_tokens,
    self.config.system_prompt,
    messages,
    tools,
  )
  let active_tools : Map[String, (String, StringBuilder)] = {}
  @ffi.js_fetch_sse(
    url,
    "POST",
    headers.stringify(),
    body.stringify(),
    self.config.timeout_sec,
    fn(line) {
      match parse_anthropic_event(line) {
        Some(event) =>
          match event {
            @llm.StreamEvent::ToolCallStart(id~, name~) => {
              active_tools[id] = (name, StringBuilder::new())
              (handler.on_event)(event)
            }
            @llm.StreamEvent::ToolCallDelta(input_delta~, ..) => {
              for entry in active_tools.iter2() {
                let (_tool_id, (_, buf)) = entry
                buf.write_string(input_delta)
                break
              }
              (handler.on_event)(event)
            }
            @llm.StreamEvent::MessageEnd(..) => {
              for entry in active_tools.iter2() {
                let (tool_id, (tool_name, buf)) = entry
                let input_str = buf.to_string()
                let input = @json.parse(input_str) catch { _ => Json::null() }
                (handler.on_event)(
                  @llm.StreamEvent::ToolCallEnd(
                    id=tool_id,
                    name=tool_name,
                    input~,
                  ),
                )
              }
              active_tools.clear()
              (handler.on_event)(event)
            }
            _ => (handler.on_event)(event)
          }
        None => ()
      }
    },
    fn(error) { (handler.on_event)(@llm.StreamEvent::Error(error)) },
    fn() {  },
  )
}

///|
pub impl @llm.Provider for AnthropicProvider with name(_self) -> String {
  "anthropic"
}
