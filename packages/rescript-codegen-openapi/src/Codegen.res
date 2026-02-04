// Codegen.res - Main code generation orchestrator (DOP refactored)
open Types

// Alias to avoid shadowing by Types.Error
module Result = Belt.Result

// Promise bindings
@val external promiseAll: array<promise<'a>> => promise<array<'a>> = "Promise.all"

// Generate code from a single spec (pure - returns data)
let generateSingleSpecPure = (
  ~spec: openAPISpec,
  ~config: generationConfig,
): result<Pipeline.generationOutput, codegenError> => {
  try {
    // Generate ComponentSchemas module if component schemas exist
    let componentOutput = ComponentSchemaGenerator.generate(~spec, ~outputDir=config.outputDir)
    
    // Parse endpoints
    let allEndpoints = OpenAPIParser.getAllEndpoints(spec)
    
    // Filter by tags if specified
    let endpoints = switch config.includeTags {
    | None => allEndpoints
    | Some(includeTags) => {
        let excludeTags = config.excludeTags->Belt.Option.getWithDefault([])
        OpenAPIParser.filterByTags(~endpoints=allEndpoints, ~includeTags, ~excludeTags)
      }
    }
    
    // Generate output based on strategy
    let endpointOutput = switch config.strategy {
    | Separate | SharedBase | ConditionalCompilation => {
        // For single spec, generate flat or per-tag modules
        switch config.modulePerTag {
        | false => {
            // Flat module
            ModuleGenerator.generateFlat(~moduleName="API", ~endpoints, ~outputDir=config.outputDir)
          }
        | true => {
            // Per-tag modules
            ModuleGenerator.generateTagModules(~endpoints, ~outputDir=config.outputDir)
          }
        }
      }
    }
    
    // Combine all outputs
    let combined = Pipeline.combine([componentOutput, endpointOutput])
    
    Ok(combined)
  } catch {
  | JsExn(err) => {
      let message = err->JsExn.message->Belt.Option.getWithDefault("Unknown error")
      Result.Error(UnknownError({message, context: None}))
    }
  | _ => Result.Error(UnknownError({message: "Unknown error", context: None}))
  }
}

// Generate code from a single spec (with side effects)
let generateSingleSpec = async (
  ~spec: openAPISpec,
  ~config: generationConfig,
): generationResult => {
  switch generateSingleSpecPure(~spec, ~config) {
  | Error(err) => Error(err)
  | Ok(output) => {
      // Perform side effect: write files to disk
      switch FileSystem.writeFiles(output.files) {
      | Error(errors) => {
          let message = `Failed to write files: ${Array.join(errors, ", ")}`
          Error(UnknownError({message, context: None}))
        }
      | Ok(filePaths) => {
          Ok({
            generatedFiles: filePaths,
            diff: None,
            warnings: output.warnings,
          })
        }
      }
    }
  }
}

// Process a single fork (pure - returns data)
let processForkPure = (
  ~baseSpec: openAPISpec,
  ~baseEndpoints: array<endpoint>,
  ~fork: forkSpec,
  ~config: generationConfig,
): result<Pipeline.generationOutput, codegenError> => {
  try {
    let forkEndpoints = OpenAPIParser.getAllEndpoints(fork.spec)
    
    // Generate diff
    let diff = SpecDiffer.generateDiff(
      ~baseSpec,
      ~forkSpec=fork.spec,
      ~baseEndpoints,
      ~forkEndpoints,
    )
    
    // Prepare diff report file if requested
    let diffReportFile = if config.generateDiffReport {
      let report = DiffReportGenerator.generateMarkdownReport(
        ~diff,
        ~baseName="base",
        ~forkName=fork.name,
      )
      let reportPath = FileSystem.makePath(config.outputDir, `${fork.name}-diff.md`)
      Some({FileSystem.path: reportPath, content: report})
    } else {
      None
    }
    
    // Merge specs based on strategy
    let (sharedSpec, extensionsSpec) = SpecMerger.mergeSpecs(
      ~baseSpec,
      ~forkSpec=fork.spec,
      ~baseEndpoints,
      ~forkEndpoints,
      ~strategy=config.strategy,
    )
    
    let sharedEndpoints = OpenAPIParser.getAllEndpoints(sharedSpec)
    let extensionEndpoints = OpenAPIParser.getAllEndpoints(extensionsSpec)
    
    // Get schemas
    let sharedSchemas = sharedSpec.components->Belt.Option.flatMap(c => c.schemas)
    let extensionSchemas = extensionsSpec.components->Belt.Option.flatMap(c => c.schemas)
    
    // Generate merge report
    let mergeStats = SpecMerger.getMergeStats(
      ~baseEndpoints,
      ~forkEndpoints,
      ~baseSchemas=baseSpec.components->Belt.Option.flatMap(c => c.schemas),
      ~forkSchemas=fork.spec.components->Belt.Option.flatMap(c => c.schemas),
    )
    
    let mergeReport = DiffReportGenerator.generateMergeReport(
      ~stats=mergeStats,
      ~baseName="base",
      ~forkName=fork.name,
    )
    
    let mergeReportPath = FileSystem.makePath(config.outputDir, `${fork.name}-merge.md`)
    let mergeReportFile = {FileSystem.path: mergeReportPath, content: mergeReport}
    
    // Generate code based on strategy
    let codeFile = switch config.strategy {
    | Separate => {
        // Generate complete fork code
        let code = ModuleGenerator.generateFlatModule(
          ~moduleName=CodegenUtils.toPascalCase(fork.name),
          ~endpoints=forkEndpoints,
        )
        
        let outputPath = FileSystem.makePath(config.outputDir, `${fork.name}.res`)
        {FileSystem.path: outputPath, content: code}
      }
    | SharedBase | ConditionalCompilation => {
        // Generate shared + extensions
        let code = ModuleGenerator.generateCombinedModule(
          ~forkName=fork.name,
          ~sharedEndpoints,
          ~extensionEndpoints,
          ~sharedSchemas,
          ~extensionSchemas,
        )
        
        let outputPath = FileSystem.makePath(config.outputDir, `${fork.name}.res`)
        {FileSystem.path: outputPath, content: code}
      }
    }
    
    // Combine all files
    let files = switch diffReportFile {
    | None => [mergeReportFile, codeFile]
    | Some(diffFile) => [diffFile, mergeReportFile, codeFile]
    }
    
    Ok(Pipeline.fromFilesAndWarnings(files, []))
  } catch {
  | JsExn(err) => {
      let message = err->JsExn.message->Belt.Option.getWithDefault("Unknown error")
      Result.Error(UnknownError({message, context: None}))
    }
  | _ => Result.Error(UnknownError({message: "Unknown error", context: None}))
  }
}

// Generate code from multiple specs (pure - returns data)
let generateMultiSpecPure = (
  ~baseSpec: openAPISpec,
  ~forkSpecs: array<forkSpec>,
  ~config: generationConfig,
): result<Pipeline.generationOutput, codegenError> => {
  try {
    // Parse base endpoints once
    let baseEndpoints = OpenAPIParser.getAllEndpoints(baseSpec)
    
    // Process each fork and collect outputs
    let forkResults = forkSpecs->Belt.Array.map(fork => {
      processForkPure(~baseSpec, ~baseEndpoints, ~fork, ~config)
    })
    
    // Check for errors
    let errors = forkResults->Belt.Array.keepMap(result => {
      switch result {
      | Result.Error(err) => Some(err)
      | Ok(_) => None
      }
    })
    
    if Belt.Array.length(errors) > 0 {
      Result.Error(errors->Belt.Array.getExn(0)) // Return first error
    } else {
      // Extract successful outputs and combine
      let outputs = forkResults->Belt.Array.keepMap(result => {
        switch result {
        | Ok(output) => Some(output)
        | Result.Error(_) => None
        }
      })
      
      Ok(Pipeline.combine(outputs))
    }
  } catch {
  | JsExn(err) => {
      let message = err->JsExn.message->Belt.Option.getWithDefault("Unknown error")
      Result.Error(UnknownError({message, context: None}))
    }
  | _ => Result.Error(UnknownError({message: "Unknown error", context: None}))
  }
}

// Generate code from multiple specs (with side effects)
let generateMultiSpec = async (
  ~baseSpec: openAPISpec,
  ~forkSpecs: array<forkSpec>,
  ~config: generationConfig,
): generationResult => {
  switch generateMultiSpecPure(~baseSpec, ~forkSpecs, ~config) {
  | Error(err) => Error(err)
  | Ok(output) => {
      // Perform side effect: write files to disk
      switch FileSystem.writeFiles(output.files) {
      | Error(errors) => {
          let message = `Failed to write files: ${Array.join(errors, ", ")}`
          Error(UnknownError({message, context: None}))
        }
      | Ok(filePaths) => {
          Ok({
            generatedFiles: filePaths,
            diff: None, // Could include aggregate diff here
            warnings: output.warnings,
          })
        }
      }
    }
  }
}

// Compare two specs and generate diff report (pure - returns data)
let compareSpecsPure = (
  ~baseSpec: openAPISpec,
  ~forkSpec: openAPISpec,
  ~baseName as _baseName: string="base",
  ~forkName as _forkName: string="fork",
): specDiff => {
  let baseEndpoints = OpenAPIParser.getAllEndpoints(baseSpec)
  let forkEndpoints = OpenAPIParser.getAllEndpoints(forkSpec)
  
  SpecDiffer.generateDiff(
    ~baseSpec,
    ~forkSpec,
    ~baseEndpoints,
    ~forkEndpoints,
  )
}

// Compare two specs and generate diff report (with optional file write)
let compareSpecs = async (
  ~baseSpec: openAPISpec,
  ~forkSpec: openAPISpec,
  ~baseName: string="base",
  ~forkName: string="fork",
  ~outputPath: option<string>=?,
): specDiff => {
  let diff = compareSpecsPure(~baseSpec, ~forkSpec, ~baseName, ~forkName)
  
  // Write report if output path provided
  switch outputPath {
  | None => ()
  | Some(path) => {
      let report = DiffReportGenerator.generateMarkdownReport(
        ~diff,
        ~baseName,
        ~forkName,
      )
      let file: FileSystem.fileToWrite = {path, content: report}
      let _ = FileSystem.writeFile(file)
      ()
    }
  }
  
  diff
}

// Main generation function
let generate = async (config: generationConfig): generationResult => {
  // Resolve and parse specs
  let baseSpecResult = await SchemaRefResolver.resolve(config.specPath)
  
  switch baseSpecResult {
  | Result.Error(err) => Result.Error(SpecResolutionError({
      url: config.specPath,
      message: err,
    }))
  | Ok(baseSpec) => {
      // Check if we have fork specs
      switch config.forkSpecs {
      | None | Some([]) => await generateSingleSpec(~spec=baseSpec, ~config)
      | Some(forkConfigs) => {
          // Resolve all fork specs
          let forkSpecsPromises = forkConfigs->Belt.Array.map(async forkConfig => {
            let forkSpecResult = await SchemaRefResolver.resolve(forkConfig.specPath)
            
            switch forkSpecResult {
            | Result.Error(err) => Result.Error(SpecResolutionError({
                url: forkConfig.specPath,
                message: `Failed to resolve ${forkConfig.name}: ${err}`,
              }))
            | Ok(spec) => Ok({name: forkConfig.name, spec: spec})
            }
          })
          
          let forkSpecsResults = await promiseAll(forkSpecsPromises)
          
          // Check for errors
          let errors = forkSpecsResults->Belt.Array.keepMap(result => {
            switch result {
            | Result.Error(err) => Some(err)
            | Ok(_) => None
            }
          })
          
          if Belt.Array.length(errors) > 0 {
            Result.Error(errors->Belt.Array.getExn(0)) // Return first error
          } else {
            // Extract successful fork specs
            let forkSpecs = forkSpecsResults->Belt.Array.keepMap(result => {
              switch result {
              | Ok(forkSpec) => Some(forkSpec)
              | Result.Error(_) => None
              }
            })
            
            await generateMultiSpec(~baseSpec, ~forkSpecs, ~config)
          }
        }
      }
    }
  }
}

// Utility: Generate from URL
let generateFromUrl = async (
  ~url: string,
  ~outputDir: string,
  ~config: option<generationConfig>=?,
): generationResult => {
  let defaultConfig = {
    specPath: url,
    outputDir: outputDir,
    strategy: SharedBase,
    includeTags: None,
    excludeTags: None,
    modulePerTag: true,
    generateDiffReport: true,
    breakingChangeHandling: Warn,
    forkSpecs: None,
  }
  
  let finalConfig = config->Belt.Option.getWithDefault(defaultConfig)
  await generate({...finalConfig, specPath: url})
}

// Utility: Generate from file
let generateFromFile = async (
  ~filePath: string,
  ~outputDir: string,
  ~config: option<generationConfig>=?,
): generationResult => {
  let defaultConfig = {
    specPath: filePath,
    outputDir: outputDir,
    strategy: SharedBase,
    includeTags: None,
    excludeTags: None,
    modulePerTag: true,
    generateDiffReport: true,
    breakingChangeHandling: Warn,
    forkSpecs: None,
  }
  
  let finalConfig = config->Belt.Option.getWithDefault(defaultConfig)
  await generate({...finalConfig, specPath: filePath})
}
