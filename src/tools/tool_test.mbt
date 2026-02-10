///|
fn json_get_string(j : Json, field : String) -> String? {
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
fn json_get_object(j : Json, field : String) -> Json? {
  match j {
    Object(m) => m.get(field)
    _ => None
  }
}

///|
test "ToolRegistry - register and execute" {
  let registry = ToolRegistry::new()
  let schema : Json = { "type": "object".to_json() }
  registry.register("greet", "Greet a person", schema, fn(input) {
    let name = match json_get_string(input, "name") {
      Some(n) => n
      None => "world"
    }
    "Hello, " + name + "!"
  })
  let defs = registry.get_defs()
  inspect(defs.length(), content="1")
  inspect(defs[0].name, content="greet")
  let (result, is_error) = registry.execute("greet", {
    "name": "Alice".to_json(),
  })
  inspect(result, content="Hello, Alice!")
  inspect(is_error, content="false")
}

///|
test "ToolRegistry - execute unknown tool" {
  let registry = ToolRegistry::new()
  let (result, is_error) = registry.execute("unknown", Json::null())
  inspect(result, content="Tool not found: unknown")
  inspect(is_error, content="true")
}

///|
test "ToolDef::to_anthropic_json" {
  let schema : Json = {
    "type": "object".to_json(),
    "properties": { "path": { "type": "string".to_json() } },
  }
  let tool : ToolDef = {
    name: "read_file",
    description: "Read a file",
    input_schema: schema,
  }
  let j = tool.to_anthropic_json()
  inspect(
    json_get_string(j, "name"),
    content=(
      #|Some("read_file")
    ),
  )
  inspect(
    json_get_string(j, "description"),
    content=(
      #|Some("Read a file")
    ),
  )
}

///|
test "ToolDef::to_openai_json" {
  let schema : Json = {
    "type": "object".to_json(),
    "properties": { "path": { "type": "string".to_json() } },
  }
  let tool : ToolDef = {
    name: "read_file",
    description: "Read a file",
    input_schema: schema,
  }
  let j = tool.to_openai_json()
  inspect(
    json_get_string(j, "type"),
    content=(
      #|Some("function")
    ),
  )
  let has_func = not(json_get_object(j, "function") is None)
  inspect(has_func, content="true")
}

///|
test "ToolDef::new constructs definition" {
  let schema : Json = { "type": "object".to_json() }
  let tool = ToolDef::new("echo", "echo text", schema)
  inspect(tool.name, content="echo")
  inspect(tool.description, content="echo text")
}

///|
test "ToolRegistry::register_def and execute_result" {
  let registry = ToolRegistry::new()
  let tool = ToolDef::new("echo", "echo text", {
    "type": "object".to_json(),
    "properties": { "text": { "type": "string".to_json() } },
    "required": Json::array(["text".to_json()]),
  })
  registry.register_def(tool, fn(input) {
    let text = match input {
      Object(map) =>
        match map.get("text") {
          Some(String(s)) => s
          _ => ""
        }
      _ => ""
    }
    "ECHO:" + text
  })
  assert_true(registry.has("echo"))
  let ok = registry.execute_result("echo", { "text": "hi".to_json() })
  match ok {
    Ok(result) => assert_eq(result, "ECHO:hi")
    Err(_) => assert_true(false)
  }
  let invalid = registry.execute_result("echo", {})
  match invalid {
    Ok(_) => assert_true(false)
    Err(InvalidParams(tool_name~, errors~)) => {
      assert_eq(tool_name, "echo")
      assert_true(errors.length() > 0)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "ToolRegistry::definitions builds openai function array" {
  let registry = ToolRegistry::new()
  registry.register_def(
    ToolDef::new("sum", "sum numbers", {
      "type": "object".to_json(),
      "properties": { "a": { "type": "number".to_json() } },
    }),
    fn(_input) { "ok" },
  )
  let defs = registry.definitions()
  assert_eq(defs.length(), 1)
  inspect(json_get_string(defs[0], "type"), content="Some(\"function\")")
}
