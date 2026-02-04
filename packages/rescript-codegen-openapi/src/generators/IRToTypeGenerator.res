// IRToTypeGenerator.res - Generate ReScript types from IR

type generationContext = {
  mutable warnings: array<Types.warning>,
  path: string,
  insideComponentSchemas: bool, // Whether we're generating inside ComponentSchemas module
}

let addWarning = (ctx: generationContext, warning: Types.warning): unit => {
  ctx.warnings->Array.push(warning)
}

// Generate ReScript type from IR type with depth limit to prevent infinite recursion
let rec generateTypeWithContext = (~ctx: generationContext, ~depth=0, irType: SchemaIR.irType): string => {
  // Safety: Prevent infinite recursion
  if depth > 20 {
    addWarning(
      ctx,
      DepthLimitReached({
        depth: depth,
        path: ctx.path,
      }),
    )
    "JSON.t"
  } else {
    switch irType {
    | SchemaIR.String(_) => "string"
    | SchemaIR.Number(_) => "float"
    | SchemaIR.Integer(_) => "int"
    | SchemaIR.Boolean => "bool"
    | SchemaIR.Null => "unit" // Or could be a variant
     | SchemaIR.Array({items, _}) => {
        let itemType = generateTypeWithContext(~ctx, ~depth=depth + 1, items)
        // Check if item is an inline object - if so, use JSON.t to avoid inline record syntax errors
        let itemTypeStr = switch items {
        | SchemaIR.Object({properties, _}) when Array.length(properties) > 0 => {
            addWarning(
              ctx,
              FallbackToJson({
                reason: "Inline objects in arrays not supported in ReScript",
                context: {
                  path: ctx.path,
                  operation: "generating array item type",
                  schema: None,
                },
              }),
            )
            "JSON.t"
          }
        | _ => itemType
        }
        `array<${itemTypeStr}>`
      }
    | SchemaIR.Object({properties, additionalProperties}) => {
        // If depth > 0, use JSON.t to match schema generator behavior and avoid nested record issues
        if depth > 0 && Array.length(properties) > 0 {
          addWarning(
            ctx,
            FallbackToJson({
              reason: "Nested objects use JSON.t to avoid ReScript syntax limitations",
              context: {
                path: ctx.path,
                operation: "generating nested object type",
                schema: None,
              },
            }),
          )
          "JSON.t"
        } else if Array.length(properties) == 0 {
          switch additionalProperties {
          | None => "JSON.t" // Empty object
          | Some(valueType) => {
              let valueTypeStr = generateTypeWithContext(~ctx, ~depth=depth + 1, valueType)
              `dict<${valueTypeStr}>`
            }
          }
        } else {
          let fields = properties->Array.map(((name, type_, required)) => {
            let fieldType = generateTypeWithContext(~ctx, ~depth=depth + 1, type_)
            // For optional fields, wrap the type in option<T> instead of using `?`
            let finalFieldType = if required {
              fieldType
            } else {
              `option<${fieldType}>`
            }
            let fieldName = name->CodegenUtils.toCamelCase
            let escapedFieldName = fieldName->CodegenUtils.escapeKeyword
            // Add @as annotation if field name was escaped
            let asAnnotation = if escapedFieldName != fieldName {
              `@as("${name}") `
            } else {
              ""
            }
            `  ${asAnnotation}${escapedFieldName}: ${finalFieldType},`
          })
          
          let fieldsStr = Array.join(fields, "\n")
          `{\n${fieldsStr}\n}`
        }
      }
    | SchemaIR.Literal(literalValue) => {
        // For literals, we can use polymorphic variants or just the base type
        switch literalValue {
        | SchemaIR.StringLiteral(_) => "string"
        | SchemaIR.NumberLiteral(_) => "float"
        | SchemaIR.BooleanLiteral(_) => "bool"
        | SchemaIR.NullLiteral => "unit"
        }
      }
    | SchemaIR.Union(types) => {
        // Check if this is a T | Array<T> pattern
        // If so, normalize to Array<T> since ReScript doesn't support union types in records
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
          // T | Array<T> → Array<T>
          // Users must wrap single values: [singleValue]
          let itemTypeStr = switch arrayItemType {
          | Some(itemType) => generateTypeWithContext(~ctx, ~depth=depth + 1, itemType)
          | None => "JSON.t"
          }
          `array<${itemTypeStr}>`
        } else {
          // Try to generate polymorphic variants for string literals
          let allStringLiterals = types->Array.every(t => {
            switch t {
            | SchemaIR.Literal(SchemaIR.StringLiteral(_)) => true
            | _ => false
            }
          })
          
          if allStringLiterals && Array.length(types) > 0 && Array.length(types) <= 20 {
            // Generate polymorphic variant
            let variants = types->Array.map(t => {
              switch t {
              | SchemaIR.Literal(SchemaIR.StringLiteral(str)) => {
                  let variantName = CodegenUtils.toPascalCase(str)
                  `#${variantName}`
                }
              | _ => "#Unknown"
              }
            })
            `[${Array.join(variants, " | ")}]`
          } else {
            // For complex unions (not just string literals), use JSON.t
            // ReScript doesn't support union types in record fields or type aliases
            // The runtime validation via Sury will handle the union logic
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
            "JSON.t"
          }
        }
      }
    | SchemaIR.Intersection(types) => {
        // For intersections, try to merge object types
        // For now, use the first type
        addWarning(
          ctx,
          IntersectionNotFullySupported({
            location: ctx.path,
            note: "Using first type only, consider implementing object merging",
          }),
        )
        switch types->Array.get(0) {
        | None => "JSON.t"
        | Some(firstType) => generateTypeWithContext(~ctx, ~depth=depth + 1, firstType)
        }
      }
    | SchemaIR.Option(innerType) => {
        let innerTypeStr = generateTypeWithContext(~ctx, ~depth=depth + 1, innerType)
        `option<${innerTypeStr}>`
      }
    | SchemaIR.Reference(ref) => {
        // Use relative or fully qualified path depending on context
        switch ReferenceResolver.refToTypePath(~insideComponentSchemas=ctx.insideComponentSchemas, ref) {
        | Some(typePath) => typePath
        | None => {
            addWarning(
              ctx,
              FallbackToJson({
                reason: `Could not resolve reference: ${ref}`,
                context: {
                  path: ctx.path,
                  operation: "generating reference type",
                  schema: None,
                },
              }),
            )
            "JSON.t"
          }
        }
      }
    | SchemaIR.Unknown => "JSON.t"
    }
  }
}

// Generate ReScript type from IR, returns both type string and warnings
let generateType = (~depth=0, ~path="", ~insideComponentSchemas=false, irType: SchemaIR.irType): (string, array<Types.warning>) => {
  let ctx = {warnings: [], path, insideComponentSchemas}
  let typeStr = generateTypeWithContext(~ctx, ~depth, irType)
  (typeStr, ctx.warnings)
}

// Generate a named type declaration
let generateNamedType = (~namedSchema: SchemaIR.namedSchema, ~insideComponentSchemas=false): (string, array<Types.warning>) => {
  let ctx = {warnings: [], path: `type.${namedSchema.name}`, insideComponentSchemas}
  let typeCode = generateTypeWithContext(~ctx, ~depth=0, namedSchema.type_)
  // Type name is already camelCased by the caller, don't convert it again
  let typeName = namedSchema.name
  
  let doc = switch namedSchema.description {
  | Some(desc) => CodegenUtils.generateDocComment(~description=desc, ())
  | None => ""
  }
  
  (`${doc}type ${typeName} = ${typeCode}`, ctx.warnings)
}

// Generate all types in context
let generateAllTypes = (~context: SchemaIR.schemaContext): (array<string>, array<Types.warning>) => {
  let allWarnings = []
  let types = Dict.valuesToArray(context.schemas)
    ->Belt.SortArray.stableSortBy((a, b) => Pervasives.compare(a.name, b.name))
    ->Array.map(namedSchema => {
      let (typeStr, warnings) = generateNamedType(~namedSchema)
      allWarnings->Array.pushMany(warnings)
      typeStr
    })
  (types, allWarnings)
}

// Generate both type and schema together
let generateTypeAndSchema = (~namedSchema: SchemaIR.namedSchema): ((string, string), array<Types.warning>) => {
  let (typeCode, typeWarnings) = generateNamedType(~namedSchema)
  let (schemaCode, schemaWarnings) = IRToSuryGenerator.generateNamedSchema(~namedSchema)
  let allWarnings = Array.concat(typeWarnings, schemaWarnings)
  ((typeCode, schemaCode), allWarnings)
}
