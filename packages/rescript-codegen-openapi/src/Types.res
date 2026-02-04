// SPDX-License-Identifier: MIT
// Types.res - Shared type definitions for OpenAPI code generation

// JSON Schema types
type rec jsonSchemaType = 
  | String
  | Number
  | Integer
  | Boolean  
  | Array(jsonSchemaType)
  | Object
  | Null
  | Unknown

and jsonSchema = {
  @as("type") type_: option<jsonSchemaType>,
  properties: option<Dict.t<jsonSchema>>,
  items: option<jsonSchema>,
  required: option<array<string>>,
  enum: option<array<JSON.t>>,
  @as("$ref") ref: option<string>,
  allOf: option<array<jsonSchema>>,
  oneOf: option<array<jsonSchema>>,
  anyOf: option<array<jsonSchema>>,
  description: option<string>,
  format: option<string>,
  minLength: option<int>,
  maxLength: option<int>,
  minimum: option<float>,
  maximum: option<float>,
  pattern: option<string>,
  nullable: option<bool>,
}

// OpenAPI 3.1 types
type httpMethod = [
  | #GET
  | #POST
  | #PUT
  | #PATCH
  | #DELETE
  | #HEAD
  | #OPTIONS
]

type mediaType = {
  schema: option<jsonSchema>,
  example: option<JSON.t>,
  examples: option<Dict.t<JSON.t>>,
}

type requestBody = {
  description: option<string>,
  content: Dict.t<mediaType>,
  required: option<bool>,
}

type response = {
  description: string,
  content: option<Dict.t<mediaType>>,
}

type parameter = {
  name: string,
  @as("in") in_: string, // "query", "header", "path", "cookie"
  description: option<string>,
  required: option<bool>,
  schema: option<jsonSchema>,
}

type operation = {
  operationId: option<string>,
  summary: option<string>,
  description: option<string>,
  tags: option<array<string>>,
  requestBody: option<requestBody>,
  responses: Dict.t<response>,
  parameters: option<array<parameter>>,
}

// Endpoint combines path, method, and operation for easier processing
type endpoint = {
  path: string,
  method: string,
  operationId: option<string>,
  summary: option<string>,
  description: option<string>,
  tags: option<array<string>>,
  requestBody: option<requestBody>,
  responses: Dict.t<response>,
  parameters: option<array<parameter>>,
}

type pathItem = {
  get: option<operation>,
  post: option<operation>,
  put: option<operation>,
  patch: option<operation>,
  delete: option<operation>,
  head: option<operation>,
  options: option<operation>,
  parameters: option<array<parameter>>,
}

type components = {
  schemas: option<Dict.t<jsonSchema>>,
}

type info = {
  title: string,
  version: string,
  description: option<string>,
}

type openAPISpec = {
  openapi: string,
  info: info,
  paths: Dict.t<pathItem>,
  components: option<components>,
}

// Generation config types
type generationStrategy = 
  | Separate
  | SharedBase
  | ConditionalCompilation

type forkSpecConfig = {
  name: string,
  specPath: string,
}

type forkSpec = {
  name: string,
  spec: openAPISpec,
}

type breakingChangeHandling = 
  | Error
  | Warn
  | Ignore

type generationConfig = {
  // Input spec path (URL or file path)
  specPath: string,
  
  // Multi-fork specs
  forkSpecs: option<array<forkSpecConfig>>,
  
  // Output
  outputDir: string,
  strategy: generationStrategy,
  modulePerTag: bool,
  
  // Filtering
  includeTags: option<array<string>>,
  excludeTags: option<array<string>>,
  
  // Diff options
  generateDiffReport: bool,
  breakingChangeHandling: breakingChangeHandling,
}

// Diff types  
type endpointDiff = {
  path: string,
  method: string,
  requestBodyChanged: bool,
  responseChanged: bool,
  breakingChange: bool,
}

type schemaDiff = {
  name: string,
  breakingChange: bool,
}

type specDiff = {
  addedEndpoints: array<endpoint>,
  removedEndpoints: array<endpoint>,
  modifiedEndpoints: array<endpointDiff>,
  addedSchemas: array<string>,
  removedSchemas: array<string>,
  modifiedSchemas: array<schemaDiff>,
}

// Error context for better debugging
type errorContext = {
  path: string, // JSON path like "paths./api/notes.post.requestBody"
  operation: string, // "parsing schema", "generating type", etc.
  schema: option<jsonSchema>,
}

// Structured error types
type codegenError =
  | SpecResolutionError({url: string, message: string})
  | SchemaParseError({context: errorContext, reason: string})
  | ReferenceError({ref: string, context: errorContext})
  | ValidationError({schema: string, input: JSON.t, issues: array<string>})
  | CircularSchemaError({ref: string, depth: int, path: string})
  | FileWriteError({filePath: string, message: string})
  | InvalidConfigError({field: string, message: string})
  | UnknownError({message: string, context: option<errorContext>})

// Warning types for non-fatal issues
type warning =
  | FallbackToJson({reason: string, context: errorContext})
  | UnsupportedFeature({feature: string, fallback: string, location: string})
  | DepthLimitReached({depth: int, path: string})
  | MissingSchema({ref: string, location: string})
  | IntersectionNotFullySupported({location: string, note: string})
  | ComplexUnionSimplified({location: string, types: string})

// Code generation types
type generationSuccess = {
  generatedFiles: array<string>,
  diff: option<specDiff>,
  warnings: array<warning>,
}

type generationResult = result<generationSuccess, codegenError>

// Helper functions for creating errors
module CodegenError = {
  let toString = (error: codegenError): string => {
    switch error {
    | SpecResolutionError({url, message}) => 
        `Failed to resolve spec from '${url}': ${message}`
    | SchemaParseError({context, reason}) => 
        `Failed to parse schema at '${context.path}' (${context.operation}): ${reason}`
    | ReferenceError({ref, context}) => 
        `Failed to resolve reference '${ref}' at '${context.path}' (${context.operation})`
    | ValidationError({schema, issues}) => 
        `Validation failed for schema '${schema}': ${issues->Array.join(", ")}`
    | CircularSchemaError({ref, depth, path}) => 
        `Circular schema detected for '${ref}' at depth ${depth->Int.toString} (path: ${path})`
    | FileWriteError({filePath, message}) => 
        `Failed to write file '${filePath}': ${message}`
    | InvalidConfigError({field, message}) => 
        `Invalid configuration for field '${field}': ${message}`
    | UnknownError({message, context}) => 
        switch context {
        | Some(ctx) => `Unknown error at '${ctx.path}' (${ctx.operation}): ${message}`
        | None => `Unknown error: ${message}`
        }
    }
  }

  let toStringError = (error: codegenError): string => toString(error)
}

// Helper functions for creating warnings
module Warning = {
  let toString = (warning: warning): string => {
    switch warning {
    | FallbackToJson({reason, context}) => 
        `⚠️  Falling back to JSON.t at '${context.path}' (${context.operation}): ${reason}`
    | UnsupportedFeature({feature, fallback, location}) => 
        `⚠️  Unsupported feature '${feature}' at '${location}', using fallback: ${fallback}`
    | DepthLimitReached({depth, path}) => 
        `⚠️  Depth limit ${depth->Int.toString} reached at '${path}', using simplified type`
    | MissingSchema({ref, location}) => 
        `⚠️  Schema reference '${ref}' not found at '${location}'`
    | IntersectionNotFullySupported({location, note}) => 
        `⚠️  Intersection type at '${location}' not fully supported: ${note}`
    | ComplexUnionSimplified({location, types}) => 
        `⚠️  Complex union at '${location}' simplified (types: ${types})`
    }
  }

  let print = (warnings: array<warning>): unit => {
    if warnings->Array.length > 0 {
      Console.log("\n⚠️  Warnings:")
      warnings->Array.forEach(w => Console.log(toString(w)))
    }
  }
}
