// ModuleGenerator.res - Generate per-tag API modules
open Types

// Generate a module for a specific tag
let generateTagModule = (
  ~tag: string,
  ~endpoints: array<endpoint>,
  ~includeSchemas: bool=true,
): string => {
  let moduleName = CodegenUtils.toPascalCase(tag)
  let description = `API endpoints for ${tag}`
  let header = CodegenUtils.generateFileHeader(~description)
  
  let lines = [header, "", `module ${moduleName} = {`]
  
  // Generate component schemas if requested
  if includeSchemas {
    // Extract all schemas used by these endpoints
    let _schemas = Dict.make()
    
    endpoints->Belt.Array.forEachWithIndex((_idx, ep) => {
      // Collect schemas from request bodies
      switch ep.requestBody {
      | None => ()
      | Some(rb) => {
          let contentTypes = Dict.keysToArray(rb.content)
          contentTypes->Belt.Array.forEach(ct => {
            switch Dict.get(rb.content, ct) {
            | None => ()
            | Some(mediaType) => {
                switch mediaType.schema {
                | None => ()
                | Some(_schema) => {
                    // Would need to extract referenced schemas here
                    // For now, skip this step
                    ()
                  }
                }
              }
            }
          })
        }
      }
      
      // Collect schemas from responses
      let responseCodes = Dict.keysToArray(ep.responses)
      responseCodes->Belt.Array.forEach(code => {
        switch Dict.get(ep.responses, code) {
        | None => ()
        | Some(resp) => {
            switch resp.content {
            | None => ()
            | Some(content) => {
                let contentTypes = Dict.keysToArray(content)
                contentTypes->Belt.Array.forEach(ct => {
                  switch Dict.get(content, ct) {
                  | None => ()
                  | Some(mediaType) => {
                      switch mediaType.schema {
                      | None => ()
                      | Some(_schema) => {
                          // Would need to extract referenced schemas here
                          ()
                        }
                      }
                    }
                  }
                })
              }
            }
          }
        }
      })
    })
  }
  
  // Generate each endpoint
  endpoints->Belt.Array.forEachWithIndex((_idx, ep) => {
    let endpointCode = EndpointGenerator.generateEndpointCode(ep)
    let indented = CodegenUtils.indent(endpointCode, 2)
    Array.push(lines, indented)
    Array.push(lines, "")
    ()
  })
  
  Array.push(lines, "}")
  
  Array.joinUnsafe(lines, "\n")
}

// Generate all tag modules from endpoints
let generateAllTagModules = (
  ~endpoints: array<endpoint>,
  ~includeSchemas: bool=true,
): array<(string, string)> => {
  // Group endpoints by tag
  let grouped = OpenAPIParser.groupByTag(endpoints)
  let tags = Dict.keysToArray(grouped)->Belt.SortArray.stableSortBy(Pervasives.compare)
  
  tags->Belt.Array.map(tag => {
    switch Dict.get(grouped, tag) {
    | None => (tag, "")
    | Some(tagEndpoints) => {
        let moduleCode = generateTagModule(~tag, ~endpoints=tagEndpoints, ~includeSchemas)
        (tag, moduleCode)
      }
    }
  })
}

// Generate index module that re-exports all tag modules
let generateIndexModule = (~tags: array<string>, ~moduleName: string="API"): string => {
  let header = CodegenUtils.generateFileHeader(
    ~description=`Main API module - re-exports all endpoint modules`
  )
  
  let lines = [header, "", `module ${moduleName} = {`]
  
  tags->Belt.Array.forEach(tag => {
    let tagModule = CodegenUtils.toPascalCase(tag)
    Array.push(lines, `  module ${tagModule} = ${tagModule}`)
    ()
  })
  
  Array.push(lines, "}")
  
  Array.joinUnsafe(lines, "\n")
}

// Generate a flat module (all endpoints in one file)
let generateFlatModule = (
  ~moduleName: string,
  ~endpoints: array<endpoint>,
): string => {
  let description = `All API endpoints in ${moduleName}`
  let header = CodegenUtils.generateFileHeader(~description)
  
  let lines = [header, "", `module ${moduleName} = {`]
  
  endpoints->Belt.Array.forEach(ep => {
    let endpointCode = EndpointGenerator.generateEndpointCode(ep)
    let indented = CodegenUtils.indent(endpointCode, 2)
    Array.push(lines, indented)
    Array.push(lines, "")
    ()
  })
  
  Array.push(lines, "}")
  
  Array.joinUnsafe(lines, "\n")
}

// Generate shared base module
let generateSharedModule = (
  ~endpoints: array<endpoint>,
  ~schemas: option<dict<jsonSchema>>,
): string => {
  let header = CodegenUtils.generateFileHeader(
    ~description="Shared API code - common to all forks"
  )
  
  let lines = [header, "", "module Shared = {"]
  
  // Generate component schemas if present
  switch schemas {
  | None => ()
  | Some(schemasDict) => {
      let schemaNames = Dict.keysToArray(schemasDict)->Belt.SortArray.stableSortBy(Pervasives.compare)
      Array.push(lines, "  // Component Schemas")
      Array.push(lines, "")
      
      schemaNames->Belt.Array.forEach(name => {
        switch Dict.get(schemasDict, name) {
        | None => ()
        | Some(schema) => {
            // Parse JSON Schema to IR
            let (irType, _warnings) = SchemaIRParser.parseJsonSchema(schema)
            
            // Generate type code
            let (typeCode, _typeWarnings) = IRToTypeGenerator.generateNamedType(
              ~namedSchema={
                name,
                description: schema.description,
                type_: irType,
              }
            )
            
            // Generate schema code
            let (schemaCode, _schemaWarnings) = IRToSuryGenerator.generateNamedSchema(
              ~namedSchema={
                name: `${name}Schema`,
                description: schema.description,
                type_: irType,
              }
            )
            
            Array.push(lines, CodegenUtils.indent(typeCode, 2))
            Array.push(lines, CodegenUtils.indent(schemaCode, 2))
            Array.push(lines, "")
            ()
          }
        }
      })
    }
  }
  
  // Generate endpoints grouped by tag
  let grouped = OpenAPIParser.groupByTag(endpoints)
  let tags = Dict.keysToArray(grouped)->Belt.SortArray.stableSortBy(Pervasives.compare)
  
  tags->Belt.Array.forEach(tag => {
    switch Dict.get(grouped, tag) {
    | None => ()
    | Some(tagEndpoints) => {
        let tagModule = CodegenUtils.toPascalCase(tag)
        Array.push(lines, `  module ${tagModule} = {`)
        
        tagEndpoints->Belt.Array.forEach(ep => {
          let endpointCode = EndpointGenerator.generateEndpointCode(ep)
          let indented = CodegenUtils.indent(endpointCode, 4)
          Array.push(lines, indented)
          Array.push(lines, "")
          ()
        })
        
        Array.push(lines, "  }")
        Array.push(lines, "")
        ()
      }
    }
  })
  
  Array.push(lines, "}")
  
  Array.joinUnsafe(lines, "\n")
}

// Generate fork extension module
let generateExtensionModule = (
  ~forkName: string,
  ~endpoints: array<endpoint>,
  ~schemas: option<dict<jsonSchema>>,
): string => {
  let moduleName = `${CodegenUtils.toPascalCase(forkName)}Extensions`
  let header = CodegenUtils.generateFileHeader(
    ~description=`${forkName} specific extensions - additional endpoints and schemas`
  )
  
  let lines = [header, "", `module ${moduleName} = {`]
  
  // Generate extension schemas if present
  switch schemas {
  | None => ()
  | Some(schemasDict) => {
      let schemaNames = Dict.keysToArray(schemasDict)
      
      if Belt.Array.length(schemaNames) > 0 {
        Array.push(lines, "  // Extension Schemas")
        Array.push(lines, "")
        
        let sorted = schemaNames->Belt.SortArray.stableSortBy(Pervasives.compare)
        
        sorted->Belt.Array.forEach(name => {
          switch Dict.get(schemasDict, name) {
          | None => ()
          | Some(schema) => {
              // Parse JSON Schema to IR
              let (irType, _warnings) = SchemaIRParser.parseJsonSchema(schema)
              
              // Generate type code
              let (typeCode, _typeWarnings) = IRToTypeGenerator.generateNamedType(
                ~namedSchema={
                  name,
                  description: schema.description,
                  type_: irType,
                }
              )
              
              // Generate schema code
              let (schemaCode, _schemaWarnings) = IRToSuryGenerator.generateNamedSchema(
                ~namedSchema={
                  name: `${name}Schema`,
                  description: schema.description,
                  type_: irType,
                }
              )
              
              Array.push(lines, CodegenUtils.indent(typeCode, 2))
              Array.push(lines, CodegenUtils.indent(schemaCode, 2))
              Array.push(lines, "")
              ()
            }
          }
        })
      }
    }
  }
  
  // Generate extension endpoints grouped by tag
  if Belt.Array.length(endpoints) > 0 {
    Array.push(lines, "  // Extension Endpoints")
    Array.push(lines, "")
    
    let grouped = OpenAPIParser.groupByTag(endpoints)
    let tags = Dict.keysToArray(grouped)->Belt.SortArray.stableSortBy(Pervasives.compare)
    
    tags->Belt.Array.forEach(tag => {
      switch Dict.get(grouped, tag) {
      | None => ()
      | Some(tagEndpoints) => {
          let tagModule = CodegenUtils.toPascalCase(tag)
          Array.push(lines, `  module ${tagModule} = {`)
          
          tagEndpoints->Belt.Array.forEach(ep => {
            let endpointCode = EndpointGenerator.generateEndpointCode(ep)
            let indented = CodegenUtils.indent(endpointCode, 4)
            Array.push(lines, indented)
            Array.push(lines, "")
            ()
          })
          
          Array.push(lines, "  }")
          Array.push(lines, "")
          ()
        }
      }
    })
  }
  
  Array.push(lines, "}")
  
  Array.joinUnsafe(lines, "\n")
}

// Generate combined module (shared + extensions)
let generateCombinedModule = (
  ~forkName: string,
  ~sharedEndpoints: array<endpoint>,
  ~extensionEndpoints: array<endpoint>,
  ~sharedSchemas: option<dict<jsonSchema>>,
  ~extensionSchemas: option<dict<jsonSchema>>,
): string => {
  let sharedModule = generateSharedModule(~endpoints=sharedEndpoints, ~schemas=sharedSchemas)
  let extensionModule = generateExtensionModule(
    ~forkName,
    ~endpoints=extensionEndpoints,
    ~schemas=extensionSchemas,
  )
  
  Array.joinUnsafe([sharedModule, "", extensionModule], "\n")
}

// Generate tag modules as Pipeline output (DOP)
let generateTagModules = (
  ~endpoints: array<endpoint>,
  ~outputDir: string,
): Pipeline.generationOutput => {
  let tagModules = generateAllTagModules(~endpoints, ~includeSchemas=true)
  
  let files = tagModules->Array.map(((tag, code)) => {
    let filename = `${CodegenUtils.toPascalCase(tag)}.res`
    let file: FileSystem.fileToWrite = {
      path: FileSystem.makePath(outputDir, filename),
      content: code,
    }
    file
  })
  
  Pipeline.fromFilesAndWarnings(files, [])
}

// Generate flat module as Pipeline output (DOP)
let generateFlat = (
  ~moduleName: string,
  ~endpoints: array<endpoint>,
  ~outputDir: string,
): Pipeline.generationOutput => {
  let code = generateFlatModule(~moduleName, ~endpoints)
  let file: FileSystem.fileToWrite = {
    path: FileSystem.makePath(outputDir, `${moduleName}.res`),
    content: code,
  }
  Pipeline.fromFile(file)
}
