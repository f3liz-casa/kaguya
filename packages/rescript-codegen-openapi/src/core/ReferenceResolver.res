// ReferenceResolver.res - Utilities for resolving component schema references

// Convert a reference like "#/components/schemas/User" to module path
// If insideComponentSchemas=true, returns "User.t" (relative)
// If insideComponentSchemas=false, returns "ComponentSchemas.User.t" (fully qualified)
let refToTypePath = (~insideComponentSchemas=false, ref: string): option<string> => {
  // Handle #/components/schemas/SchemaName format
  let parts = ref->String.split("/")
  switch parts->Array.get(parts->Array.length - 1) {
  | None => None
  | Some(schemaName) => {
      let moduleName = CodegenUtils.toPascalCase(schemaName)
      if insideComponentSchemas {
        Some(`${moduleName}.t`)
      } else {
        Some(`ComponentSchemas.${moduleName}.t`)
      }
    }
  }
}

// Convert a reference like "#/components/schemas/User" to schema path
// If insideComponentSchemas=true, returns "User.schema" (relative)
// If insideComponentSchemas=false, returns "ComponentSchemas.User.schema" (fully qualified)
let refToSchemaPath = (~insideComponentSchemas=false, ref: string): option<string> => {
  // Handle #/components/schemas/SchemaName format
  let parts = ref->String.split("/")
  switch parts->Array.get(parts->Array.length - 1) {
  | None => None
  | Some(schemaName) => {
      let moduleName = CodegenUtils.toPascalCase(schemaName)
      if insideComponentSchemas {
        Some(`${moduleName}.schema`)
      } else {
        Some(`ComponentSchemas.${moduleName}.schema`)
      }
    }
  }
}
