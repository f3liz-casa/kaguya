// SPDX-License-Identifier: MIT
// SchemaCodeGenerator.res - Generate complete Sury schema code with types

// Generate both type and schema for a named schema
let generateTypeAndSchema = (name: string, schema: Types.jsonSchema): string => {
  // Parse JSON Schema to IR
  let (irType, _warnings) = SchemaIRParser.parseJsonSchema(schema)
  
  // Generate type code
  let (typeDef, _typeWarnings) = IRToTypeGenerator.generateNamedType(
    ~namedSchema={
      name,
      description: schema.description,
      type_: irType,
    }
  )
  
  // Generate schema code
  let (schemaDef, _schemaWarnings) = IRToSuryGenerator.generateNamedSchema(
    ~namedSchema={
      name: `${name}Schema`,
      description: schema.description,
      type_: irType,
    }
  )
  
  `${typeDef}\n\n${schemaDef}`
}

// Generate schemas for all components
let generateComponentSchemas = (components: option<Types.components>): string => {
  switch components->Option.flatMap(c => c.schemas) {
  | None => "// No component schemas defined\n"
  | Some(schemas) => {
      let schemaCode = schemas
        ->Dict.toArray
        ->Array.map(((name, schema)) => {
          generateTypeAndSchema(name, schema)
        })
        ->Array.join("\n\n")
      
      `// Component Schemas\n\n${schemaCode}`
    }
  }
}

// Generate request/response types and schemas for an operation
let generateOperationSchemas = (
  operationId: string,
  operation: Types.operation,
): string => {
  let parts = []
  
  // Handle request body
  let requestSchemaOpt = operation.requestBody->Option.flatMap(body => {
    body.content
    ->Dict.get("application/json")
    ->Option.flatMap(media => media.schema)
  })
  
  switch requestSchemaOpt {
  | None => ()
  | Some(schema) => {
      let requestName = `${CodegenUtils.toPascalCase(operationId)}Request`
      let (irType, _warnings) = SchemaIRParser.parseJsonSchema(schema)
      
      let (typeDef, _typeWarnings) = IRToTypeGenerator.generateNamedType(
        ~namedSchema={
          name: requestName,
          description: schema.description,
          type_: irType,
        }
      )
      
      let (schemaDef, _schemaWarnings) = IRToSuryGenerator.generateNamedSchema(
        ~namedSchema={
          name: `${requestName}Schema`,
          description: schema.description,
          type_: irType,
        }
      )
      
      parts->Array.push(typeDef)
      parts->Array.push(schemaDef)
    }
  }
  
  // Handle response
  let responseSchemaOpt = {
    let response200 = operation.responses->Dict.get("200")
    let response201 = operation.responses->Dict.get("201")
    let response = response200->Option.orElse(response201)
    
    response->Option.flatMap(resp => {
      resp.content
      ->Option.flatMap(content => content->Dict.get("application/json"))
      ->Option.flatMap(media => media.schema)
    })
  }
  
  switch responseSchemaOpt {
  | None => ()
  | Some(schema) => {
      let responseName = `${CodegenUtils.toPascalCase(operationId)}Response`
      let (irType, _warnings) = SchemaIRParser.parseJsonSchema(schema)
      
      let (typeDef, _typeWarnings) = IRToTypeGenerator.generateNamedType(
        ~namedSchema={
          name: responseName,
          description: schema.description,
          type_: irType,
        }
      )
      
      let (schemaDef, _schemaWarnings) = IRToSuryGenerator.generateNamedSchema(
        ~namedSchema={
          name: `${responseName}Schema`,
          description: schema.description,
          type_: irType,
        }
      )
      
      parts->Array.push(typeDef)
      parts->Array.push(schemaDef)
    }
  }
  
  parts->Array.join("\n\n")
}

// Generate module with endpoint types and schemas
let generateEndpointModule = (
  path: string,
  method: Types.httpMethod,
  operation: Types.operation,
): string => {
  let operationId = OpenAPIParser.getOperationId(path, method, operation)
  let moduleName = CodegenUtils.toPascalCase(operationId)
  
  let doc = CodegenUtils.generateDocComment(
    ~summary=?operation.summary,
    ~description=?operation.description,
    ()
  )
  
  let schemas = generateOperationSchemas(operationId, operation)
  
  let methodStr = switch method {
  | #GET => "GET"
  | #POST => "POST"
  | #PUT => "PUT"
  | #PATCH => "PATCH"
  | #DELETE => "DELETE"
  | #HEAD => "HEAD"
  | #OPTIONS => "OPTIONS"
  }
  
  let endpointInfo = `  let endpoint = "${path}"\n  let method = #${methodStr}`
  
  `${doc}module ${moduleName} = {\n${CodegenUtils.indent(schemas, 1)}\n\n${endpointInfo}\n}`
}
