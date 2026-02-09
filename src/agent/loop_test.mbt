///|
fn loop_json_get_field(obj : Json, key : String) -> Json? {
  match obj {
    Object(map) => map.get(key)
    _ => None
  }
}

///|
fn loop_json_get_string_field(obj : Json, key : String) -> String? {
  match loop_json_get_field(obj, key) {
    Some(String(s)) => Some(s)
    _ => None
  }
}

///|
fn loop_text_field(obj : Json, key : String) -> String {
  match loop_json_get_string_field(obj, key) {
    Some(s) => s
    None => ""
  }
}

///|
fn has_tool_result(
  messages : Array[Json],
  tool_call_id : String,
  content : String,
) -> Bool {
  for msg in messages {
    if loop_text_field(msg, "role") == "tool" &&
      loop_text_field(msg, "tool_call_id") == tool_call_id &&
      loop_text_field(msg, "content") == content {
      return true
    }
  }
  false
}

///|
test "run_agent_loop returns direct response without tools" {
  let calls = Ref::new(0)
  let result = run_agent_loop(
    [{ "role": "user".to_json(), "content": "hello".to_json() }],
    [],
    "dummy-model",
    5,
    fn(_messages, _tools, _model) {
      calls.val = calls.val + 1
      LoopResponse::new("answer", [], None)
    },
    fn(_name, _arguments) { "" },
  )
  assert_eq(result.final_content, "answer")
  assert_eq(result.iterations, 1)
  assert_eq(calls.val, 1)
}

///|
test "run_agent_loop executes tool call and continues" {
  let calls = Ref::new(0)
  let saw_tool_result = Ref::new(false)
  let result = run_agent_loop(
    [{ "role": "user".to_json(), "content": "echo hi".to_json() }],
    [{
      "type": "function".to_json(),
      "function": {
        "name": "echo".to_json(),
        "description": "echo text".to_json(),
        "parameters": {
          "type": "object".to_json(),
          "properties": { "text": { "type": "string".to_json() } },
          "required": Json::array(["text".to_json()]),
        },
      },
    }],
    "dummy-model",
    5,
    fn(messages, _tools, _model) {
      if calls.val == 0 {
        calls.val = 1
        LoopResponse::new(
          "",
          [LoopToolCall::new("call_1", "echo", { "text": "hi".to_json() })],
          None,
        )
      } else {
        calls.val = 2
        saw_tool_result.val = has_tool_result(messages, "call_1", "ECHO:hi")
        LoopResponse::new("done", [], None)
      }
    },
    fn(name, args) {
      if name != "echo" {
        return "ERR"
      }
      match loop_json_get_field(args, "text") {
        Some(String(s)) => "ECHO:" + s
        _ => "ECHO:"
      }
    },
  )
  assert_eq(result.final_content, "done")
  assert_eq(result.iterations, 2)
  assert_true(saw_tool_result.val)
}

///|
test "run_agent_loop returns fallback when max_iterations exceeded" {
  let result = run_agent_loop(
    [{ "role": "user".to_json(), "content": "loop".to_json() }],
    [],
    "dummy-model",
    1,
    fn(_messages, _tools, _model) {
      LoopResponse::new(
        "",
        [LoopToolCall::new("call_1", "echo", { "text": "hi".to_json() })],
        None,
      )
    },
    fn(_name, _arguments) { "ECHO:hi" },
  )
  assert_eq(
    result.final_content,
    "I've completed processing but have no response to give.",
  )
  assert_eq(result.iterations, 1)
}

///|
test "run_agent_loop_with_provider works with callback provider" {
  let calls = Ref::new(0)
  let provider = callback_chat_provider(fn(_messages, _tools, _model) {
    calls.val = calls.val + 1
    LoopResponse::new("from-provider", [], None)
  })
  let result = run_agent_loop_with_provider(
    [{ "role": "user".to_json(), "content": "hello".to_json() }],
    [],
    provider,
    "dummy-model",
    5,
    fn(_name, _arguments) { "" },
  )
  assert_eq(result.final_content, "from-provider")
  assert_eq(result.iterations, 1)
  assert_eq(calls.val, 1)
}
