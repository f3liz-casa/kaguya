// ComponentSchemaGenerator.res - Generate shared component schema module
// This module generates a ComponentSchemas.res file with all shared types and schemas
// from the OpenAPI components.schemas section

// Extract schema names that this IR type references
let rec extractReferences = (irType: SchemaIR.irType): array<string> => {
  switch irType {
  | SchemaIR.Reference(ref) => {
      // Extract schema name from ref like "#/components/schemas/User"
      let parts = ref->String.split("/")
      switch parts->Array.get(parts->Array.length - 1) {
      | None => []
      | Some(name) => [name]
      }
    }
  | SchemaIR.Array({items}) => extractReferences(items)
  | SchemaIR.Object({properties}) => {
      properties->Array.flatMap(((_, propType, _)) => extractReferences(propType))
    }
  | SchemaIR.Union(types) | SchemaIR.Intersection(types) => {
      types->Array.flatMap(extractReferences)
    }
  | SchemaIR.Option(inner) => extractReferences(inner)
  | _ => []
  }
}

// Generate a component module with both type and schema
let generateComponentModule = (~namedSchema: SchemaIR.namedSchema): (string, array<Types.warning>) => {
  let allWarnings = []
  
  // Generate type - use relative paths since modules are sorted by dependency
  let ctx = {IRToTypeGenerator.warnings: [], path: `ComponentSchemas.${namedSchema.name}`, insideComponentSchemas: true}
  let typeCode = IRToTypeGenerator.generateTypeWithContext(~ctx, ~depth=0, namedSchema.type_)
  allWarnings->Array.pushMany(ctx.warnings)
  
  // Generate schema
  let schemaCtx = {IRToSuryGenerator.warnings: [], path: `ComponentSchemas.${namedSchema.name}`, insideComponentSchemas: true}
  let schemaCode = IRToSuryGenerator.generateSchemaWithContext(~ctx=schemaCtx, ~depth=0, namedSchema.type_)
  allWarnings->Array.pushMany(schemaCtx.warnings)
  
  let typeName = CodegenUtils.toPascalCase(namedSchema.name)
  let doc = switch namedSchema.description {
  | Some(desc) => CodegenUtils.generateDocComment(~description=desc, ())
  | None => ""
  }
  
  let moduleCode = `${doc}module ${typeName} = {
  type t = ${typeCode}
  
  let schema = ${schemaCode}
}`

  (moduleCode, allWarnings)
}

// Generate the full ComponentSchemas module file (pure - returns data)
let generateComponentSchemasModule = (
  ~spec: Types.openAPISpec,
): (string, array<Types.warning>) => {
  let allWarnings = []
  
  // Parse component schemas to IR
  let (context, parseWarnings) = switch spec.components {
  | None => ({SchemaIR.schemas: Dict.make()}, [])
  | Some(components) => {
      switch components.schemas {
      | None => ({SchemaIR.schemas: Dict.make()}, [])
      | Some(schemas) => SchemaIRParser.parseComponentSchemas(schemas)
      }
    }
  }
  
  allWarnings->Array.pushMany(parseWarnings)
  
  // Topologically sort schemas by dependencies
  // This ensures a schema is only generated after all schemas it references
  let sortedSchemas = {
    let schemas = Dict.valuesToArray(context.schemas)
    let schemaDict = Dict.fromArray(schemas->Array.map(s => (s.name, s)))
    
    // Build dependency graph: schema -> list of schemas it depends on
    let dependencies = Dict.make()
    schemas->Array.forEach(schema => {
      let deps = extractReferences(schema.type_)
        ->Array.filter(dep => Dict.has(schemaDict, dep)) // Only keep valid dependencies
      Dict.set(dependencies, schema.name, deps)
    })
    
    // Topological sort using Kahn's algorithm
    let sorted = []
    let inDegree = Dict.make()
    
    // Initialize in-degree counts (how many schemas depend on this one)
    schemas->Array.forEach(schema => {
      Dict.set(inDegree, schema.name, 0)
    })
    
    // Calculate in-degrees: for each schema, increment in-degree of its dependencies
    schemas->Array.forEach(schema => {
      let deps = Dict.get(dependencies, schema.name)->Belt.Option.getWithDefault([])
      deps->Array.forEach(dep => {
        let current = Dict.get(inDegree, schema.name)->Belt.Option.getWithDefault(0)
        Dict.set(inDegree, schema.name, current + 1)
      })
    })
    
    // Start with schemas that have no dependencies (in-degree = 0)
    let queue = []
    schemas->Array.forEach(schema => {
      if Dict.get(inDegree, schema.name)->Belt.Option.getWithDefault(0) == 0 {
        Array.push(queue, schema)
      }
    })
    
    // Process queue
    while Array.length(queue) > 0 {
      switch Array.shift(queue) {
      | None => ()
      | Some(schema) => {
          Array.push(sorted, schema)
          
          // For each schema that depends on the current one, reduce its in-degree
          schemas->Array.forEach(dependent => {
            let deps = Dict.get(dependencies, dependent.name)->Belt.Option.getWithDefault([])
            if deps->Array.includes(schema.name) {
              let current = Dict.get(inDegree, dependent.name)->Belt.Option.getWithDefault(0)
              let newDegree = current - 1
              Dict.set(inDegree, dependent.name, newDegree)
              if newDegree == 0 {
                Array.push(queue, dependent)
              }
            }
          })
        }
      }
    }
    
    // If there are remaining schemas (cycles), add them alphabetically
    let sortedNames = sorted->Array.map(s => s.name)
    let remaining = schemas
      ->Array.filter(s => !Array.includes(sortedNames, s.name))
      ->Belt.SortArray.stableSortBy((a, b) => Pervasives.compare(a.name, b.name))
    
    Array.concat(sorted, remaining)
  }
  
  // Generate component modules
  let componentModules = sortedSchemas->Array.map(namedSchema => {
    let (moduleCode, warnings) = generateComponentModule(~namedSchema)
    allWarnings->Array.pushMany(warnings)
    moduleCode
  })
  
  let header = CodegenUtils.generateFileHeader(~description="Component Schemas - Shared types and validation schemas")
  
  let moduleContent = if Array.length(componentModules) == 0 {
    `${header}

// No component schemas defined in the OpenAPI spec
`
  } else {
    `${header}

${Array.join(componentModules, "\n\n")}
`
  }
  
  (moduleContent, allWarnings)
}

// Check if component schemas exist
let hasComponentSchemas = (spec: Types.openAPISpec): bool => {
  switch spec.components {
  | None => false
  | Some(components) => {
      switch components.schemas {
      | None => false
      | Some(schemas) => Dict.keysToArray(schemas)->Array.length > 0
      }
    }
  }
}

// Get component schema names for reference resolution
let getComponentSchemaNames = (spec: Types.openAPISpec): array<string> => {
  switch spec.components {
  | None => []
  | Some(components) => {
      switch components.schemas {
      | None => []
      | Some(schemas) => Dict.keysToArray(schemas)
      }
    }
  }
}

// Generate component schemas as Pipeline output (DOP)
let generate = (
  ~spec: Types.openAPISpec,
  ~outputDir: string,
): Pipeline.generationOutput => {
  if !hasComponentSchemas(spec) {
    Pipeline.empty
  } else {
    let (content, warnings) = generateComponentSchemasModule(~spec)
    let file: FileSystem.fileToWrite = {
      path: FileSystem.makePath(outputDir, "ComponentSchemas.res"),
      content,
    }
    Pipeline.fromFilesAndWarnings([file], warnings)
  }
}
