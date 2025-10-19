def schema_path(name)
  Rails.root.join("docs", "schemas", "#{name}.schema.json")
end

def load_schema(name)
  JSONSchemer.schema(Pathname.new(schema_path(name)))
end

def expect_json_schema!(payload, schema_name = "game_state")
  errors = load_schema(schema_name).validate(payload).to_a
  expect(errors).to be_empty, "Schema #{schema_name} errors:\n#{errors.map(&:to_h)}"
end
