///|
/// ToolDef defines a tool that can be called by the model.
pub(all) struct ToolDef {
  name : String
  description : String
  input_schema : Json
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
  self.tools.push({ name, description, input_schema })
  self.handlers[name] = handler
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
pub fn ToolRegistry::get_defs(self : ToolRegistry) -> Array[ToolDef] {
  self.tools
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
