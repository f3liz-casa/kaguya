// SPDX-License-Identifier: MIT
// OpenAPIParser.res - Parse OpenAPI 3.1 specs

// Parse HTTP method from string
let parseMethod = (methodStr: string): option<Types.httpMethod> => {
  switch methodStr->String.toLowerCase {
  | "get" => Some(#GET)
  | "post" => Some(#POST)
  | "put" => Some(#PUT)
  | "patch" => Some(#PATCH)
  | "delete" => Some(#DELETE)
  | "head" => Some(#HEAD)
  | "options" => Some(#OPTIONS)
  | _ => None
  }
}

// Convert httpMethod to string
let httpMethodToString = (method: Types.httpMethod): string => {
  switch method {
  | #GET => "get"
  | #POST => "post"
  | #PUT => "put"
  | #PATCH => "patch"
  | #DELETE => "delete"
  | #HEAD => "head"
  | #OPTIONS => "options"
  }
}

// Convert tuple to endpoint
let tupleToEndpoint = ((path, method, operation): (string, Types.httpMethod, Types.operation)): Types.endpoint => {
  {
    path,
    method: httpMethodToString(method),
    operationId: operation.operationId,
    summary: operation.summary,
    description: operation.description,
    tags: operation.tags,
    requestBody: operation.requestBody,
    responses: operation.responses,
    parameters: operation.parameters,
  }
}

// Extract operations from a path item
let getOperations = (path: string, pathItem: Types.pathItem): array<(string, Types.httpMethod, Types.operation)> => {
  let operations = []
  
  pathItem.get->Option.forEach(op => operations->Array.push((path, #GET, op)))
  pathItem.post->Option.forEach(op => operations->Array.push((path, #POST, op)))
  pathItem.put->Option.forEach(op => operations->Array.push((path, #PUT, op)))
  pathItem.patch->Option.forEach(op => operations->Array.push((path, #PATCH, op)))
  pathItem.delete->Option.forEach(op => operations->Array.push((path, #DELETE, op)))
  pathItem.head->Option.forEach(op => operations->Array.push((path, #HEAD, op)))
  pathItem.options->Option.forEach(op => operations->Array.push((path, #OPTIONS, op)))
  
  operations
}

// Get all endpoints from the spec
let getAllEndpoints = (spec: Types.openAPISpec): array<Types.endpoint> => {
  let pathsArray = spec.paths->Dict.toArray
  
  pathsArray
  ->Array.flatMap(((path, pathItem)) => getOperations(path, pathItem))
  ->Array.map(tupleToEndpoint)
}

// Group endpoints by tag
let groupByTag = (
  endpoints: array<Types.endpoint>
): Dict.t<array<Types.endpoint>> => {
  let grouped = Dict.make()
  
  endpoints->Array.forEach(endpoint => {
    let tags = endpoint.tags->Option.getOr(["default"])
    
    tags->Array.forEach(tag => {
      let existing = grouped->Dict.get(tag)->Option.getOr([])
      existing->Array.push(endpoint)
      grouped->Dict.set(tag, existing)
    })
  })
  
  grouped
}

// Get all schemas from components
let getAllSchemas = (spec: Types.openAPISpec): Dict.t<Types.jsonSchema> => {
  spec.components
  ->Option.flatMap(c => c.schemas)
  ->Option.getOr(Dict.make())
}

// Extract operation ID or generate one
let getOperationId = (path: string, method: Types.httpMethod, operation: Types.operation): string => {
  operation.operationId->Option.getOr({
    // Generate operation ID from path and method
    let methodStr = switch method {
    | #GET => "get"
    | #POST => "post"
    | #PUT => "put"
    | #PATCH => "patch"
    | #DELETE => "delete"
    | #HEAD => "head"
    | #OPTIONS => "options"
    }
    
    let pathParts = path
      ->String.replaceAll("/", "_")
      ->String.replaceAll("{", "")
      ->String.replaceAll("}", "")
      ->String.replaceAll("-", "_")
    
    `${methodStr}${pathParts}`
  })
}

// Filter endpoints by tags
let filterByTags = (
  ~endpoints: array<Types.endpoint>,
  ~includeTags: array<string>,
  ~excludeTags: array<string>,
): array<Types.endpoint> => {
  endpoints->Array.filter(endpoint => {
    let operationTags = endpoint.tags->Option.getOr([])
    
    // Check include tags
    let included = operationTags->Array.some(tag => includeTags->Array.includes(tag))
    
    // Check exclude tags
    let excluded = operationTags->Array.some(tag => excludeTags->Array.includes(tag))
    
    included && !excluded
  })
}

// Get unique tags from all endpoints
let getAllTags = (endpoints: array<Types.endpoint>): array<string> => {
  endpoints
  ->Array.flatMap(endpoint => endpoint.tags->Option.getOr([]))
  ->Set.fromArray
  ->Set.toArray
}
