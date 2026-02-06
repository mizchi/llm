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
