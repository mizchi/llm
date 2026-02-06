///|
test "ContentBlock::to_anthropic_json - Text" {
  let block : ContentBlock = Text("hello")
  let expected =
    #|{"type":"text","text":"hello"}
  inspect(block.to_anthropic_json().stringify(), content=expected)
}

///|
test "ContentBlock::to_anthropic_json - ToolUse" {
  let block : ContentBlock = ToolUse(id="call_1", name="read_file", input={
    "path": "foo.txt".to_json(),
  })
  let expected =
    #|{"type":"tool_use","id":"call_1","name":"read_file","input":{"path":"foo.txt"}}
  inspect(block.to_anthropic_json().stringify(), content=expected)
}

///|
test "ContentBlock::to_anthropic_json - ToolResult" {
  let block : ContentBlock = ToolResult(
    tool_use_id="call_1",
    content="file content",
    is_error=false,
  )
  let expected =
    #|{"type":"tool_result","tool_use_id":"call_1","content":"file content","is_error":false}
  inspect(block.to_anthropic_json().stringify(), content=expected)
}

///|
test "Message::to_anthropic_json" {
  let msg = Message::user("hello")
  let expected =
    #|{"role":"user","content":[{"type":"text","text":"hello"}]}
  inspect(msg.to_anthropic_json().stringify(), content=expected)
}

///|
test "Message::to_openai_json - simple text" {
  let msg = Message::user("hello")
  let expected =
    #|{"role":"user","content":"hello"}
  inspect(msg.to_openai_json().stringify(), content=expected)
}

///|
test "Message::to_openai_json - tool result" {
  let msg : Message = {
    role: Tool,
    content: [
      ToolResult(tool_use_id="call_1", content="result", is_error=false),
    ],
  }
  let expected =
    #|{"role":"tool","tool_call_id":"call_1","content":"result"}
  inspect(msg.to_openai_json().stringify(), content=expected)
}

///|
test "json_get_string" {
  let j : Json = { "name": "test".to_json(), "value": Json::number(42.0) }
  inspect(json_get_string(j, "name"), content="Some(\"test\")")
  inspect(json_get_string(j, "value"), content="None")
  inspect(json_get_string(j, "missing"), content="None")
}

///|
test "json_get_int" {
  let j : Json = { "count": Json::number(42.0), "name": "test".to_json() }
  inspect(json_get_int(j, "count"), content="Some(42)")
  inspect(json_get_int(j, "name"), content="None")
  inspect(json_get_int(j, "missing"), content="None")
}
