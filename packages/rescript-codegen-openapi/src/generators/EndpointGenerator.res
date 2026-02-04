// EndpointGenerator.res - Generate API endpoint functions
open Types

// Check if an IR type contains any component schema references
let rec containsComponentSchemaReference = (irType: SchemaIR.irType): bool => {
  switch irType {
  | SchemaIR.Reference(_) => true
  | SchemaIR.Array({items}) => containsComponentSchemaReference(items)
  | SchemaIR.Object({properties}) => {
      properties->Array.some(((_, propType, _)) => containsComponentSchemaReference(propType))
    }
  | SchemaIR.Union(types) | SchemaIR.Intersection(types) => {
      types->Array.some(containsComponentSchemaReference)
    }
  | SchemaIR.Option(inner) => containsComponentSchemaReference(inner)
  | _ => false
  }
}

// Check if an endpoint uses component schemas
let endpointUsesComponentSchemas = (endpoint: endpoint): bool => {
  // Check request body
  let requestUsesRefs = switch endpoint.requestBody {
  | None => false
  | Some(rb) => {
      let contentTypes = Dict.keysToArray(rb.content)
      Belt.Array.get(contentTypes, 0)
        ->Belt.Option.flatMap(ct => Dict.get(rb.content, ct))
        ->Belt.Option.flatMap(mt => mt.schema)
        ->Belt.Option.map(schema => {
          let (irType, _) = SchemaIRParser.parseJsonSchema(schema)
          containsComponentSchemaReference(irType)
        })
        ->Belt.Option.getWithDefault(false)
    }
  }
  
  // Check response
  let responseUsesRefs = {
    let successCodes = ["200", "201", "202", "204"]
    successCodes
      ->Belt.Array.keepMap(code => Dict.get(endpoint.responses, code))
      ->Belt.Array.get(0)
      ->Belt.Option.flatMap(resp => resp.content)
      ->Belt.Option.flatMap(content => {
        let contentTypes = Dict.keysToArray(content)
        Belt.Array.get(contentTypes, 0)->Belt.Option.flatMap(ct => Dict.get(content, ct))
      })
      ->Belt.Option.flatMap(mt => mt.schema)
      ->Belt.Option.map(schema => {
        let (irType, _) = SchemaIRParser.parseJsonSchema(schema)
        containsComponentSchemaReference(irType)
      })
      ->Belt.Option.getWithDefault(false)
  }
  
  requestUsesRefs || responseUsesRefs
}

// Helper to convert JSON Schema to IR and generate code
// The IR parser handles $ref resolution, so we just parse and generate
let generateTypeAndSchemaFromJsonSchema = (
  ~jsonSchema: jsonSchema,
  ~typeName: string,
  ~schemaName: string,
): (string, string) => {
  // Parse JSON Schema to IR (handles refs, arrays, objects, etc.)
  let (irType, _warnings) = SchemaIRParser.parseJsonSchema(jsonSchema)
  
  // Generate type code from IR
  let (typeCode, _typeWarnings) = IRToTypeGenerator.generateNamedType(
    ~namedSchema={
      name: typeName,
      description: jsonSchema.description,
      type_: irType,
    }
  )
  
  // Generate schema code from IR
  let (schemaCode, _schemaWarnings) = IRToSuryGenerator.generateNamedSchema(
    ~namedSchema={
      name: schemaName,
      description: jsonSchema.description,
      type_: irType,
    }
  )
  
  (typeCode, schemaCode)
}

// Generate parameter extraction code
let generateParameterExtraction = (parameters: option<array<parameter>>): string => {
  switch parameters {
  | None => ""
  | Some(params) if Belt.Array.length(params) == 0 => ""
  | Some(params) => {
      let lines = params->Belt.Array.map(param => {
        let name = param.name
        let in_ = param.in_
        `  // ${in_} parameter: ${name}`
      })
      
      Array.joinUnsafe(lines, "\n")
    }
  }
}

// Generate request body code
let generateRequestBodyCode = (requestBody: option<requestBody>, ~functionName: string): (string, string) => {
  switch requestBody {
  | None => ("", "~body as _")
  | Some(rb) => {
      // Get first content type (usually application/json)
      let contentTypes = Dict.keysToArray(rb.content)
      let firstContentType = Belt.Array.get(contentTypes, 0)
      
      switch firstContentType {
      | None => ("", "~body as _")
      | Some(_contentType) => {
          let required = rb.required->Belt.Option.getWithDefault(false)
          let bodyParam = if required {
            "~body"
          } else {
            "~body=?"
          }
          
          let schemaName = `${functionName}Request`
          let validation = if required {
            `  let validatedBody = ${schemaName}Schema->S.parseOrThrow(body)`
          } else {
            `  let validatedBody = body->Belt.Option.map(b => ${schemaName}Schema->S.parseOrThrow(b))`
          }
          
          (validation, bodyParam)
        }
      }
    }
  }
}

// Generate response handling code
let generateResponseCode = (responses: dict<response>, ~functionName: string): string => {
  // Look for success response (200, 201, etc.)
  let successCodes = ["200", "201", "202", "204"]
  let successResponse = successCodes->Belt.Array.keepMap(code => {
    Dict.get(responses, code)
  })->Belt.Array.get(0)
  
  switch successResponse {
  | None => "  // No response schema defined\n  response"
  | Some(resp) => {
      switch resp.content {
      | None => "  response"
      | Some(content) => {
          let contentTypes = Dict.keysToArray(content)
          let firstContentType = Belt.Array.get(contentTypes, 0)
          
           switch firstContentType {
           | None => "  response"
           | Some(_) => {
               let schemaName = `${functionName}Response`
               `  let validatedResponse = ${schemaName}Schema->S.parseOrThrow(response)\n  validatedResponse`
             }
           }
        }
      }
    }
  }
}

// Generate endpoint function
let generateEndpointFunction = (endpoint: endpoint): string => {
  let path = endpoint.path
  let method = endpoint.method->String.toUpperCase
  let functionName = CodegenUtils.generateOperationName(endpoint.operationId, endpoint.path, endpoint.method)
  let _requestTypeName = `${functionName}Request`
  let responseTypeName = `${functionName}Response`
  
  // Generate parameter extraction
  let paramCode = generateParameterExtraction(endpoint.parameters)
  
  // Generate request body code (now with function name)
  let (bodyValidation, bodyParam) = generateRequestBodyCode(endpoint.requestBody, ~functionName)
  
  // Generate response code (now with function name)
  let responseCode = generateResponseCode(endpoint.responses, ~functionName)
  
  // Generate function signature
  let hasBody = endpoint.requestBody->Belt.Option.isSome
  let params = if hasBody {
    `${bodyParam}, ~fetch`
  } else {
    "~fetch"
  }
  
  let summary = endpoint.summary->Belt.Option.getWithDefault("API endpoint")
  
  let lines = [
    `// ${summary}`,
    `let ${functionName} = (${params}): promise<${responseTypeName}> => {`,
  ]
  
  if paramCode != "" {
    Array.push(lines, paramCode)
  }
  
  if bodyValidation != "" {
    Array.push(lines, bodyValidation)
  }
  
  Array.push(lines, `  `)
  Array.push(lines, `  fetch(`)
  Array.push(lines, `    ~url="${path}",`)
  Array.push(lines, `    ~method_="${method}",`)
  
  if hasBody {
    Array.push(lines, `    ~body=validatedBody,`)
  }
  
  Array.push(lines, `  )->Promise.then(response => {`)
  Array.push(lines, responseCode)
  Array.push(lines, `->Promise.resolve`)
  Array.push(lines, `  })`)
  Array.push(lines, `}`)
  
  Array.joinUnsafe(lines, "\n")
}

// Generate endpoint function with types and schemas
let generateEndpointCode = (endpoint: endpoint): string => {
  let functionName = CodegenUtils.generateOperationName(endpoint.operationId, endpoint.path, endpoint.method)
  let requestTypeName = `${functionName}Request`
  let responseTypeName = `${functionName}Response`
  
  // Get request body schema
  let requestSchemaOpt = endpoint.requestBody->Belt.Option.flatMap(rb => {
    let contentTypes = Dict.keysToArray(rb.content)
    Belt.Array.get(contentTypes, 0)->Belt.Option.flatMap(ct => {
      Dict.get(rb.content, ct)->Belt.Option.flatMap(mt => mt.schema)
    })
  })
  
  // Get response schema
  let responseSchemaOpt = {
    let successCodes = ["200", "201", "202", "204"]
    successCodes->Belt.Array.keepMap(code => {
      Dict.get(endpoint.responses, code)
    })->Belt.Array.get(0)->Belt.Option.flatMap(resp => {
      resp.content->Belt.Option.flatMap(content => {
        let contentTypes = Dict.keysToArray(content)
        Belt.Array.get(contentTypes, 0)->Belt.Option.flatMap(ct => {
          Dict.get(content, ct)->Belt.Option.flatMap(mt => mt.schema)
        })
      })
    })
  }
  
  let sections = []
  
  // Generate request type and schema if present
  switch requestSchemaOpt {
  | None => ()
  | Some(schema) => {
      let (typeCode, schemaCode) = generateTypeAndSchemaFromJsonSchema(
        ~jsonSchema=schema,
        ~typeName=requestTypeName,
        ~schemaName=`${functionName}Request`,
      )
      
      Array.push(sections, typeCode)
      Array.push(sections, schemaCode)
      ()
    }
  }
  
  // Generate response type and schema if present
  switch responseSchemaOpt {
  | None => {
      // No response schema - generate a unit type
      Array.push(sections, `type ${responseTypeName} = unit`)
      ()
    }
  | Some(schema) => {
      let (typeCode, schemaCode) = generateTypeAndSchemaFromJsonSchema(
        ~jsonSchema=schema,
        ~typeName=responseTypeName,
        ~schemaName=`${functionName}Response`,
      )
      
      Array.push(sections, typeCode)
      Array.push(sections, schemaCode)
      ()
    }
  }
  
  // Generate the endpoint function
  Array.push(sections, generateEndpointFunction(endpoint))
  
  Array.joinUnsafe(sections, "\n\n")
}

// Generate module for a single endpoint
let generateEndpointModule = (~endpoint: endpoint): string => {
  let moduleName = CodegenUtils.toPascalCase(CodegenUtils.generateOperationName(endpoint.operationId, endpoint.path, endpoint.method))
  
  let header = CodegenUtils.generateFileHeader(
    ~description=endpoint.summary->Belt.Option.getWithDefault(`API endpoint: ${endpoint.path}`)
  )
  
  // Check if we need to import ComponentSchemas
  let needsComponentSchemas = endpointUsesComponentSchemas(endpoint)
  
  let lines = [
    header,
    "",
  ]
  
  // Add import if needed
  if needsComponentSchemas {
    Array.push(lines, "open ComponentSchemas")
    Array.push(lines, "")
  }
  
  Array.push(lines, `module ${moduleName} = {`)
  Array.push(lines, CodegenUtils.indent(generateEndpointCode(endpoint), 2))
  Array.push(lines, "}")
  
  Array.joinUnsafe(lines, "\n")
}

// Generate multiple endpoint functions in a single module
let generateEndpointsModule = (
  ~moduleName: string,
  ~endpoints: array<endpoint>,
  ~description: option<string>=?,
): string => {
  let desc = description->Belt.Option.getWithDefault(`API endpoints for ${moduleName}`)
  let header = CodegenUtils.generateFileHeader(~description=desc)
  
  // Check if any endpoint uses component schemas
  let needsComponentSchemas = endpoints->Array.some(endpointUsesComponentSchemas)
  
  let endpointCodes = endpoints->Belt.Array.map(ep => {
    CodegenUtils.indent(generateEndpointCode(ep), 2)
  })
  
  let lines = [
    header,
    "",
  ]
  
  // Add import if needed
  if needsComponentSchemas {
    Array.push(lines, "open ComponentSchemas")
    Array.push(lines, "")
  }
  
  Array.push(lines, `module ${moduleName} = {`)
  
  endpointCodes->Belt.Array.forEach(code => {
    Array.push(lines, code)
    Array.push(lines, "")
    ()
  })
  
  Array.push(lines, "}")
  
  Array.joinUnsafe(lines, "\n")
}

// Generate simple endpoint signature (for interface files)
let generateEndpointSignature = (endpoint: endpoint): string => {
  let functionName = CodegenUtils.generateOperationName(endpoint.operationId, endpoint.path, endpoint.method)
  let responseTypeName = `${functionName}Response`
  
  let hasBody = endpoint.requestBody->Belt.Option.isSome
  let params = if hasBody {
    "~body: 'body, ~fetch: fetchFn"
  } else {
    "~fetch: fetchFn"
  }
  
  let summary = endpoint.summary->Belt.Option.getWithDefault("")
  let lines = if summary != "" {
    [`// ${summary}`, `let ${functionName}: (${params}) => promise<${responseTypeName}>`]
  } else {
    [`let ${functionName}: (${params}) => promise<${responseTypeName}>`]
  }
  
  Array.joinUnsafe(lines, "\n")
}
