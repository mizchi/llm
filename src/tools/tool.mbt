///|
/// ToolDef defines a tool that can be called by the model.
pub(all) struct ToolDef {
  name : String
  description : String
  input_schema : Json
}

///|
pub fn ToolDef::new(
  name : String,
  description : String,
  input_schema : Json,
) -> ToolDef {
  { name, description, input_schema }
}

///|
/// ToolChoice controls how the model selects tools.
pub(all) enum ToolChoice {
  Auto
  None
  Required
  Specific(String)
}

///|
/// SchemaBuilder helps construct JSON Schema for tool input_schema.
pub(all) struct SchemaBuilder {
  properties : Map[String, Json]
  required : Array[String]
}

///|
pub fn SchemaBuilder::new() -> SchemaBuilder {
  { properties: Map::new(), required: [] }
}

///|
/// Add a string property.
pub fn SchemaBuilder::string(
  self : SchemaBuilder,
  name : String,
  description : String,
  required? : Bool = false,
) -> SchemaBuilder {
  let prop : Map[String, Json] = {}
  prop["type"] = "string".to_json()
  prop["description"] = description.to_json()
  self.properties[name] = Json::object(prop)
  if required {
    self.required.push(name)
  }
  self
}

///|
/// Add a number property.
pub fn SchemaBuilder::number(
  self : SchemaBuilder,
  name : String,
  description : String,
  required? : Bool = false,
) -> SchemaBuilder {
  let prop : Map[String, Json] = {}
  prop["type"] = "number".to_json()
  prop["description"] = description.to_json()
  self.properties[name] = Json::object(prop)
  if required {
    self.required.push(name)
  }
  self
}

///|
/// Add an integer property.
pub fn SchemaBuilder::integer(
  self : SchemaBuilder,
  name : String,
  description : String,
  required? : Bool = false,
) -> SchemaBuilder {
  let prop : Map[String, Json] = {}
  prop["type"] = "integer".to_json()
  prop["description"] = description.to_json()
  self.properties[name] = Json::object(prop)
  if required {
    self.required.push(name)
  }
  self
}

///|
/// Add a boolean property.
pub fn SchemaBuilder::boolean(
  self : SchemaBuilder,
  name : String,
  description : String,
  required? : Bool = false,
) -> SchemaBuilder {
  let prop : Map[String, Json] = {}
  prop["type"] = "boolean".to_json()
  prop["description"] = description.to_json()
  self.properties[name] = Json::object(prop)
  if required {
    self.required.push(name)
  }
  self
}

///|
/// Add a string enum property.
pub fn SchemaBuilder::string_enum(
  self : SchemaBuilder,
  name : String,
  description : String,
  values : Array[String],
  required? : Bool = false,
) -> SchemaBuilder {
  let prop : Map[String, Json] = {}
  prop["type"] = "string".to_json()
  prop["description"] = description.to_json()
  prop["enum"] = Json::array(values.map(fn(v) { v.to_json() }))
  self.properties[name] = Json::object(prop)
  if required {
    self.required.push(name)
  }
  self
}

///|
/// Add an array property with item type.
pub fn SchemaBuilder::array(
  self : SchemaBuilder,
  name : String,
  description : String,
  item_type : String,
  required? : Bool = false,
) -> SchemaBuilder {
  let items : Map[String, Json] = {}
  items["type"] = item_type.to_json()
  let prop : Map[String, Json] = {}
  prop["type"] = "array".to_json()
  prop["description"] = description.to_json()
  prop["items"] = Json::object(items)
  self.properties[name] = Json::object(prop)
  if required {
    self.required.push(name)
  }
  self
}

///|
/// Build the JSON Schema object.
pub fn SchemaBuilder::build(self : SchemaBuilder) -> Json {
  let schema : Map[String, Json] = {}
  schema["type"] = "object".to_json()
  schema["properties"] = Json::object(self.properties)
  if not(self.required.is_empty()) {
    schema["required"] = Json::array(self.required.map(fn(s) { s.to_json() }))
  }
  Json::object(schema)
}

///|
/// ToolRegistry manages available tools and their handlers.
pub(all) struct ToolRegistry {
  tools : Array[ToolDef]
  handlers : Map[String, (Json) -> String]
}

///|
pub(all) enum ToolExecuteError {
  ToolNotFound(String)
  InvalidParams(tool_name~ : String, errors~ : Array[String])
}

///|
pub fn ToolExecuteError::to_message(self : ToolExecuteError) -> String {
  match self {
    ToolNotFound(name) => "Error: Tool '" + name + "' not found"
    InvalidParams(tool_name~, errors~) =>
      "Error: Invalid parameters for tool '" +
      tool_name +
      "': " +
      errors.join("; ")
  }
}

///|
pub fn ToolRegistry::new() -> ToolRegistry {
  { tools: [], handlers: Map::new() }
}

///|
pub fn ToolRegistry::register(
  self : ToolRegistry,
  name : String,
  description : String,
  input_schema : Json,
  handler : (Json) -> String,
) -> Unit {
  self.register_def(ToolDef::new(name, description, input_schema), handler)
}

///|
pub fn ToolRegistry::register_def(
  self : ToolRegistry,
  tool : ToolDef,
  handler : (Json) -> String,
) -> Unit {
  self.tools.push(tool)
  self.handlers[tool.name] = handler
}

///|
pub fn ToolRegistry::execute(
  self : ToolRegistry,
  name : String,
  input : Json,
) -> (String, Bool) {
  match self.handlers.get(name) {
    Some(handler) => (handler(input), false)
    None => ("Tool not found: " + name, true)
  }
}

///|
pub fn ToolRegistry::execute_result(
  self : ToolRegistry,
  name : String,
  input : Json,
) -> Result[String, ToolExecuteError] {
  match self.find_tool(name) {
    None => Err(ToolNotFound(name))
    Some(tool) =>
      match self.handlers.get(name) {
        None => Err(ToolNotFound(name))
        Some(handler) => {
          let errors = validate_tool_input(input, tool.input_schema)
          if not(errors.is_empty()) {
            return Err(InvalidParams(tool_name=name, errors~))
          }
          Ok(handler(input))
        }
      }
  }
}

///|
/// Execute with schema validation before handler invocation.
pub fn ToolRegistry::execute_validated(
  self : ToolRegistry,
  name : String,
  input : Json,
) -> (String, Bool) {
  match self.find_tool(name) {
    Some(tool) => {
      let errors = validate_tool_input(input, tool.input_schema)
      if not(errors.is_empty()) {
        return (
          "Invalid tool input for '" + name + "': " + errors.join("; "),
          true,
        )
      }
      self.execute(name, input)
    }
    None => self.execute(name, input)
  }
}

///|
pub fn ToolRegistry::get_defs(self : ToolRegistry) -> Array[ToolDef] {
  self.tools
}

///|
pub fn ToolRegistry::has(self : ToolRegistry, name : String) -> Bool {
  self.find_tool(name) is Some(_)
}

///|
pub fn ToolRegistry::definitions(self : ToolRegistry) -> Array[Json] {
  let out : Array[Json] = []
  for tool in self.tools {
    out.push(tool.to_openai_json())
  }
  out
}

///|
fn ToolRegistry::find_tool(self : ToolRegistry, name : String) -> ToolDef? {
  for tool in self.tools {
    if tool.name == name {
      return Some(tool)
    }
  }
  None
}

///|
/// Convert ToolDef to Anthropic format JSON.
pub fn ToolDef::to_anthropic_json(self : ToolDef) -> Json {
  {
    "name": self.name.to_json(),
    "description": self.description.to_json(),
    "input_schema": self.input_schema,
  }
}

///|
/// Convert ToolDef to OpenAI format JSON.
pub fn ToolDef::to_openai_json(self : ToolDef) -> Json {
  {
    "type": "function".to_json(),
    "function": {
      "name": self.name.to_json(),
      "description": self.description.to_json(),
      "parameters": self.input_schema,
    },
  }
}
