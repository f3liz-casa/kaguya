// IRToSuryGenerator.res - Generate Sury schema code from IR

type generationContext = {
  mutable warnings: array<Types.warning>,
  path: string,
  insideComponentSchemas: bool, // Whether we're generating inside ComponentSchemas module
}

let addWarning = (ctx: generationContext, warning: Types.warning): unit => {
  ctx.warnings->Array.push(warning)
}

// Generate Sury schema code from IR type
//  depth parameter: when > 0, use S.json for objects to avoid inline record field ambiguity
let rec generateSchemaWithContext = (~ctx: generationContext, ~depth=0, irType: SchemaIR.irType): string => {
  switch irType {
  | SchemaIR.String({constraints}) => {
      let base = "S.string"
      let withMin = constraints.minLength->Option.mapOr(base, min =>
        `${base}->S.min(${Int.toString(min)})`
      )
      let withMax = constraints.maxLength->Option.mapOr(withMin, max =>
        `${withMin}->S.max(${Int.toString(max)})`
      )
      constraints.pattern->Option.mapOr(withMax, pattern =>
        `${withMax}->S.pattern(%re("/${CodegenUtils.escapeString(pattern)}/"))`
      )
    }
  | SchemaIR.Number({constraints}) => {
      let base = "S.float"
      let withMin = constraints.minimum->Option.mapOr(base, min =>
        `${base}->S.min(${Float.toInt(min)->Int.toString})`
      )
      constraints.maximum->Option.mapOr(withMin, max =>
        `${withMin}->S.max(${Float.toInt(max)->Int.toString})`
      )
    }
  | SchemaIR.Integer({constraints}) => {
      let base = "S.int"
      let withMin = constraints.minimum->Option.mapOr(base, min =>
        `${base}->S.min(${Float.toInt(min)->Int.toString})`
      )
      constraints.maximum->Option.mapOr(withMin, max =>
        `${withMin}->S.max(${Float.toInt(max)->Int.toString})`
      )
    }
  | SchemaIR.Boolean => "S.bool"
  | SchemaIR.Null => "S.null"
  | SchemaIR.Array({items, constraints}) => {
      let itemsSchema = generateSchemaWithContext(~ctx, ~depth=depth + 1, items)
      let base = `S.array(${itemsSchema})`
      let withMin = constraints.minItems->Option.mapOr(base, min =>
        `${base}->S.min(${Int.toString(min)})`
      )
      constraints.maxItems->Option.mapOr(withMin, max =>
        `${withMin}->S.max(${Int.toString(max)})`
      )
    }
  | SchemaIR.Object({properties, additionalProperties}) => {
      // If depth > 0, use S.json to avoid inline record field ambiguity issues
      if depth > 0 {
        addWarning(
          ctx,
          FallbackToJson({
            reason: "Nested objects use S.json to avoid ReScript syntax limitations",
            context: {
              path: ctx.path,
              operation: "generating nested object schema",
              schema: None,
            },
          }),
        )
        "S.json"
      } else if Array.length(properties) == 0 {
        switch additionalProperties {
        | None => "S.json"  // Empty object with no schema - use S.json to return JSON.t type
        | Some(valueType) => {
            let valueSchema = generateSchemaWithContext(~ctx, ~depth=depth + 1, valueType)
            `S.dict(${valueSchema})`
          }
        }
      } else {
        let fields = properties->Array.map(((name, type_, required)) => {
          let fieldSchema = generateSchemaWithContext(~ctx, ~depth=depth + 1, type_)
          let fieldName = name->CodegenUtils.toCamelCase->CodegenUtils.escapeKeyword
          
          if required {
            `    ${fieldName}: s.field("${name}", ${fieldSchema}),`
          } else {
            // For optional fields in OpenAPI, the field may be missing or null
            // Use S.nullableAsOption to convert null → None, value → Some(value)
            `    ${fieldName}: s.fieldOr("${name}", S.nullableAsOption(${fieldSchema}), None),`
          }
        })
        
        let fieldsStr = Array.join(fields, "\n")
        `S.object(s => {\n${fieldsStr}\n  })`
      }
    }
  | SchemaIR.Literal(literalValue) => {
      switch literalValue {
      | SchemaIR.StringLiteral(str) => `S.literal("${CodegenUtils.escapeString(str)}")`
      | SchemaIR.NumberLiteral(num) => `S.literal(${Float.toString(num)})`
      | SchemaIR.BooleanLiteral(true) => `S.literal(true)`
      | SchemaIR.BooleanLiteral(false) => `S.literal(false)`
      | SchemaIR.NullLiteral => `S.literal(null)`
      }
    }
  | SchemaIR.Union(types) => {
      // Check if this is a T | Array<T> pattern
      // If so, normalize to Array<T> schema since ReScript doesn't support union types
      // Note: Users must wrap single values in an array, e.g., [singleValue]
      let (hasArrays, hasNonArrays, arrayItemType, nonArrayType) = types->Array.reduce(
        (false, false, None, None),
        ((hasArr, hasNonArr, arrType, nonArrType), t) => {
          switch t {
          | SchemaIR.Array({items, _}) => (true, hasNonArr, Some(items), nonArrType)
          | _ => (hasArr, true, arrType, Some(t))
          }
        }
      )
      
      // Check if it's T | Array<T> pattern by comparing types
      let isSingleItemArrayUnion = switch (arrayItemType, nonArrayType) {
        | (Some(itemType), Some(singleType)) if hasArrays && hasNonArrays && SchemaIR.equals(itemType, singleType) => true
        | _ => false
      }
      
      if isSingleItemArrayUnion {
        // T | Array<T> → S.array(T)
        // Users must wrap single values: [singleValue]
        let itemSchema = switch arrayItemType {
        | Some(itemType) => generateSchemaWithContext(~ctx, ~depth=depth + 1, itemType)
        | None => "S.json"
        }
        `S.array(${itemSchema})`
      } else if hasArrays && hasNonArrays {
        // Other mixed union with arrays and non-arrays - Sury can't handle this
        let typeNames = types
          ->Array.map(SchemaIR.toString)
          ->Array.join(" | ")
        addWarning(
          ctx,
          ComplexUnionSimplified({
            location: ctx.path,
            types: typeNames,
          }),
        )
        "S.json"
      } else {
        // Check if this union should be JSON.t (complex union)
        let allStringLiterals = types->Array.every(t => {
          switch t {
          | SchemaIR.Literal(SchemaIR.StringLiteral(_)) => true
          | _ => false
          }
        })
        
        // If it's string literals and reasonable size, generate proper union
        if allStringLiterals && Array.length(types) > 0 && Array.length(types) <= 20 {
          let variants = types->Array.map(t => generateSchemaWithContext(~ctx, ~depth=depth + 1, t))->Array.join(", ")
          `S.union([${variants}])`
        } else {
          // For complex unions that become JSON.t in types, use S.json
          let typeNames = types
            ->Array.map(SchemaIR.toString)
            ->Array.join(" | ")
          addWarning(
            ctx,
            ComplexUnionSimplified({
              location: ctx.path,
              types: typeNames,
            }),
          )
          "S.json"
        }
      }
    }
  | SchemaIR.Intersection(types) => {
      // Sury doesn't have native intersection, try to merge objects
      // For now, use the first type as base
      addWarning(
        ctx,
        IntersectionNotFullySupported({
          location: ctx.path,
          note: "Using first type only for schema generation",
        }),
      )
      switch types->Array.get(0) {
      | None => "S.unknown"
      | Some(firstType) => generateSchemaWithContext(~ctx, ~depth=depth + 1, firstType)
      }
    }
  | SchemaIR.Reference(ref) => {
      // Use relative or fully qualified path depending on context
      switch ReferenceResolver.refToSchemaPath(~insideComponentSchemas=ctx.insideComponentSchemas, ref) {
      | Some(schemaPath) => schemaPath
      | None => {
          addWarning(
            ctx,
            FallbackToJson({
              reason: `Could not resolve reference: ${ref}`,
              context: {
                path: ctx.path,
                operation: "generating reference schema",
                schema: None,
              },
            }),
          )
          "S.json"
        }
      }
    }
  | SchemaIR.Option(inner) => {
      let innerSchema = generateSchemaWithContext(~ctx, ~depth=depth + 1, inner)
      // OpenAPI uses null for optional values, but ReScript option uses undefined
      // S.nullableAsOption converts null <-> None (undefined), non-null <-> Some(value)
      `S.nullableAsOption(${innerSchema})`
    }
  | SchemaIR.Unknown => "S.json"  // Use S.json instead of S.unknown to return JSON.t type
  }
}

// Generate Sury schema from IR, returns both schema string and warnings
let generateSchema = (~depth=0, ~path="", ~insideComponentSchemas=false, irType: SchemaIR.irType): (string, array<Types.warning>) => {
  let ctx = {warnings: [], path, insideComponentSchemas}
  let schemaStr = generateSchemaWithContext(~ctx, ~depth, irType)
  (schemaStr, ctx.warnings)
}

// Generate a named schema definition
let generateNamedSchema = (~namedSchema: SchemaIR.namedSchema, ~insideComponentSchemas=false): (string, array<Types.warning>) => {
  let ctx = {warnings: [], path: `schema.${namedSchema.name}`, insideComponentSchemas}
  let schemaCode = generateSchemaWithContext(~ctx, ~depth=0, namedSchema.type_)
  // Schema name is already camelCased by the caller, just add "Schema" suffix
  let schemaName = `${namedSchema.name}Schema`
  
  let doc = switch namedSchema.description {
  | Some(desc) => CodegenUtils.generateDocComment(~description=desc, ())
  | None => ""
  }
  
  (`${doc}let ${schemaName} = ${schemaCode}`, ctx.warnings)
}

// Generate all schemas in context
let generateAllSchemas = (~context: SchemaIR.schemaContext): (array<string>, array<Types.warning>) => {
  let allWarnings = []
  let schemas = Dict.valuesToArray(context.schemas)
    ->Belt.SortArray.stableSortBy((a, b) => Pervasives.compare(a.name, b.name))
    ->Array.map(namedSchema => {
      let (schemaStr, warnings) = generateNamedSchema(~namedSchema)
      allWarnings->Array.pushMany(warnings)
      schemaStr
    })
  (schemas, allWarnings)
}
