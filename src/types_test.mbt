///|
test "Role::to_string" {
  inspect(Role::User.to_string(), content="user")
  inspect(Role::Assistant.to_string(), content="assistant")
  inspect(Role::System.to_string(), content="system")
  inspect(Role::Tool.to_string(), content="tool")
}

///|
test "Role::from_string" {
  inspect(Role::from_string("user"), content="user")
  inspect(Role::from_string("assistant"), content="assistant")
  inspect(Role::from_string("system"), content="system")
  inspect(Role::from_string("tool"), content="tool")
  inspect(Role::from_string("unknown"), content="user")
}

///|
test "Message::text" {
  let msg = Message::text(User, "hello")
  inspect(msg.role, content="user")
  inspect(msg.get_text(), content="hello")
}

///|
test "Message::user" {
  let msg = Message::user("hi")
  inspect(msg.role, content="user")
  inspect(msg.get_text(), content="hi")
}

///|
test "Message::assistant" {
  let msg = Message::assistant("reply")
  inspect(msg.role, content="assistant")
  inspect(msg.get_text(), content="reply")
}

///|
test "Message::get_text with multiple blocks" {
  let msg : Message = {
    role: Assistant,
    content: [Text("hello "), Text("world")],
  }
  inspect(msg.get_text(), content="hello world")
}

///|
test "Message::get_text ignores non-text blocks" {
  let msg : Message = {
    role: Assistant,
    content: [Text("text"), ToolUse(id="1", name="tool", input=Json::null())],
  }
  inspect(msg.get_text(), content="text")
}

///|
test "FinishReason::from_string" {
  inspect(FinishReason::from_string("stop"), content="Stop")
  inspect(FinishReason::from_string("end_turn"), content="Stop")
  inspect(FinishReason::from_string("tool_use"), content="ToolUse")
  inspect(FinishReason::from_string("tool_calls"), content="ToolUse")
  inspect(FinishReason::from_string("length"), content="Length")
  inspect(FinishReason::from_string("max_tokens"), content="Length")
  inspect(FinishReason::from_string("content_filter"), content="ContentFilter")
  inspect(FinishReason::from_string("error"), content="Error")
  inspect(FinishReason::from_string("xyz"), content="Unknown(xyz)")
}
