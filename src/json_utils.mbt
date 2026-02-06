///|
/// Convert a ContentBlock to JSON (Anthropic format).
pub fn ContentBlock::to_anthropic_json(self : ContentBlock) -> Json {
  match self {
    Text(s) => { "type": "text".to_json(), "text": s.to_json() }
    ToolUse(id~, name~, input~) =>
      {
        "type": "tool_use".to_json(),
        "id": id.to_json(),
        "name": name.to_json(),
        "input": input,
      }
    ToolResult(tool_use_id~, content~, is_error~) =>
      {
        "type": "tool_result".to_json(),
        "tool_use_id": tool_use_id.to_json(),
        "content": content.to_json(),
        "is_error": is_error.to_json(),
      }
  }
}

///|
/// Convert a ContentBlock to JSON (OpenAI format).
pub fn ContentBlock::to_openai_json(self : ContentBlock) -> Json {
  match self {
    Text(s) => { "type": "text".to_json(), "text": s.to_json() }
    ToolUse(id~, name~, input~) =>
      {
        "type": "function".to_json(),
        "id": id.to_json(),
        "function": {
          "name": name.to_json(),
          "arguments": input.stringify().to_json(),
        },
      }
    ToolResult(tool_use_id~, content~, ..) =>
      {
        "role": "tool".to_json(),
        "tool_call_id": tool_use_id.to_json(),
        "content": content.to_json(),
      }
  }
}

///|
/// Convert a Message to Anthropic JSON format.
pub fn Message::to_anthropic_json(self : Message) -> Json {
  let content_arr = self.content.map(ContentBlock::to_anthropic_json)
  {
    "role": self.role.to_string().to_json(),
    "content": Json::array(content_arr),
  }
}

///|
/// Convert a Message to OpenAI JSON format.
pub fn Message::to_openai_json(self : Message) -> Json {
  // For simple text-only messages, use string content
  if self.content.length() == 1 {
    match self.content[0] {
      Text(s) =>
        return {
          "role": self.role.to_string().to_json(),
          "content": s.to_json(),
        }
      ToolResult(tool_use_id~, content~, ..) =>
        return {
          "role": "tool".to_json(),
          "tool_call_id": tool_use_id.to_json(),
          "content": content.to_json(),
        }
      _ => ()
    }
  }
  // For assistant messages with tool_use, extract tool_calls
  match self.role {
    Assistant => {
      let text_parts : Array[String] = []
      let tool_calls : Array[Json] = []
      for block in self.content {
        match block {
          Text(s) => text_parts.push(s)
          ToolUse(id~, name~, input~) =>
            tool_calls.push({
              "id": id.to_json(),
              "type": "function".to_json(),
              "function": {
                "name": name.to_json(),
                "arguments": input.stringify().to_json(),
              },
            })
          _ => ()
        }
      }
      let result : Map[String, Json] = {}
      result["role"] = "assistant".to_json()
      result["content"] = text_parts.join("").to_json()
      if not(tool_calls.is_empty()) {
        result["tool_calls"] = Json::array(tool_calls)
      }
      return Json::object(result)
    }
    _ => ()
  }
  let content_arr = self.content.map(ContentBlock::to_openai_json)
  {
    "role": self.role.to_string().to_json(),
    "content": Json::array(content_arr),
  }
}

///|
/// Helper to get a string field from a JSON object.
pub fn json_get_string(j : Json, field : String) -> String? {
  match j {
    Object(m) =>
      match m.get(field) {
        Some(String(s)) => Some(s)
        _ => None
      }
    _ => None
  }
}

///|
/// Helper to get an int field from a JSON object.
pub fn json_get_int(j : Json, field : String) -> Int? {
  match j {
    Object(m) =>
      match m.get(field) {
        Some(Number(n, ..)) => Some(n.to_int())
        _ => None
      }
    _ => None
  }
}

///|
/// Helper to get a JSON object field.
pub fn json_get_object(j : Json, field : String) -> Json? {
  match j {
    Object(m) => m.get(field)
    _ => None
  }
}

///|
/// Helper to get a JSON array field.
pub fn json_get_array(j : Json, field : String) -> Array[Json]? {
  match j {
    Object(m) =>
      match m.get(field) {
        Some(Array(arr)) => Some(arr)
        _ => None
      }
    _ => None
  }
}
