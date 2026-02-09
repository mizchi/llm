///|
/// Message construction helpers extracted from nanobot context builder.

///|
pub fn add_tool_result(
  messages : Array[Json],
  tool_call_id : String,
  tool_name : String,
  result : String,
) -> Array[Json] {
  let out = messages
  out.push({
    "role": "tool".to_json(),
    "tool_call_id": tool_call_id.to_json(),
    "name": tool_name.to_json(),
    "content": result.to_json(),
  })
  out
}

///|
pub fn add_assistant_message(
  messages : Array[Json],
  content : String?,
  tool_calls : Array[Json]?,
  reasoning_content : String?,
) -> Array[Json] {
  let out = messages
  let msg : Map[String, Json] = {}
  msg["role"] = "assistant".to_json()
  msg["content"] = match content {
    Some(text) => text.to_json()
    None => "".to_json()
  }
  match tool_calls {
    Some(calls) =>
      if not(calls.is_empty()) {
        msg["tool_calls"] = Json::array(calls)
      }
    None => ()
  }
  match reasoning_content {
    Some(reasoning) =>
      if not(reasoning.is_empty()) {
        msg["reasoning_content"] = reasoning.to_json()
      }
    None => ()
  }
  out.push(Json::object(msg))
  out
}
