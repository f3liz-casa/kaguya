// DiffReportGenerator.res - Generate markdown diff reports
open Types

// Format endpoint for display
let formatEndpoint = (endpoint: endpoint): string => {
  let operationId = endpoint.operationId->Belt.Option.getWithDefault("unnamed")
  `${endpoint.method->String.toUpperCase} ${endpoint.path} (${operationId})`
}

// Format tags for display
let formatTags = (tags: option<array<string>>): string => {
  switch tags {
  | None => ""
  | Some(tags) if Belt.Array.length(tags) == 0 => ""
  | Some(tags) => ` [${Array.joinUnsafe(tags, ", ")}]`
  }
}

// Generate section for added endpoints
let generateAddedEndpointsSection = (endpoints: array<endpoint>): string => {
  if Belt.Array.length(endpoints) == 0 {
    ""
  } else {
    let lines = ["", "### Added Endpoints", ""]
    
    endpoints->Belt.Array.forEach(ep => {
      let tags = formatTags(ep.tags)
      let summary = ep.summary->Belt.Option.getWithDefault("")
      let line = `- **${formatEndpoint(ep)}**${tags}`
      let _ = Array.push(lines, line)
      
      if summary != "" {
        let _ = Array.push(lines, `  ${summary}`)
      }
      ()
    })
    
    Array.joinUnsafe(lines, "\n")
  }
}

// Generate section for removed endpoints
let generateRemovedEndpointsSection = (endpoints: array<endpoint>): string => {
  if Belt.Array.length(endpoints) == 0 {
    ""
  } else {
    let lines = ["", "### Removed Endpoints", ""]
    
    endpoints->Belt.Array.forEach(ep => {
      let tags = formatTags(ep.tags)
      let line = `- **${formatEndpoint(ep)}**${tags}`
      let _ = Array.push(lines, line)
      ()
    })
    
    Array.joinUnsafe(lines, "\n")
  }
}

// Generate section for modified endpoints
let generateModifiedEndpointsSection = (diffs: array<endpointDiff>): string => {
  if Belt.Array.length(diffs) == 0 {
    ""
  } else {
    let lines = ["", "### Modified Endpoints", ""]
    
    diffs->Belt.Array.forEach(diff => {
      let endpoint = `${diff.method->String.toUpperCase} ${diff.path}`
      let changes = []
      
      if diff.requestBodyChanged {
        let _ = Array.push(changes, "request body")
      }
      if diff.responseChanged {
        let _ = Array.push(changes, "response")
      }
      
      let changeStr = Array.joinUnsafe(changes, ", ")
      let breaking = if diff.breakingChange {
        " **⚠️ BREAKING**"
      } else {
        ""
      }
      
      let line = `- **${endpoint}**${breaking}: Changed ${changeStr}`
      let _ = Array.push(lines, line)
      ()
    })
    
    Array.joinUnsafe(lines, "\n")
  }
}

// Generate section for added schemas
let generateAddedSchemasSection = (schemas: array<string>): string => {
  if Belt.Array.length(schemas) == 0 {
    ""
  } else {
    let lines = ["", "### Added Schemas", ""]
    
    schemas->Belt.Array.forEach(name => {
      let _ = Array.push(lines, `- \`${name}\``)
      ()
    })
    
    Array.joinUnsafe(lines, "\n")
  }
}

// Generate section for removed schemas
let generateRemovedSchemasSection = (schemas: array<string>): string => {
  if Belt.Array.length(schemas) == 0 {
    ""
  } else {
    let lines = ["", "### Removed Schemas", ""]
    
    schemas->Belt.Array.forEach(name => {
      let _ = Array.push(lines, `- \`${name}\``)
      ()
    })
    
    Array.joinUnsafe(lines, "\n")
  }
}

// Generate section for modified schemas
let generateModifiedSchemasSection = (diffs: array<schemaDiff>): string => {
  if Belt.Array.length(diffs) == 0 {
    ""
  } else {
    let lines = ["", "### Modified Schemas", ""]
    
    diffs->Belt.Array.forEach(diff => {
      let breaking = if diff.breakingChange {
        " **⚠️ BREAKING**"
      } else {
        ""
      }
      
      let line = `- \`${diff.name}\`${breaking}`
      let _ = Array.push(lines, line)
      ()
    })
    
    Array.joinUnsafe(lines, "\n")
  }
}

// Generate statistics summary
let generateStatsSummary = (diff: specDiff): string => {
  let totalChanges = SpecDiffer.countChanges(diff)
  let hasBreaking = SpecDiffer.hasBreakingChanges(diff)
  
  let stats = [
    `- **Total Changes**: ${Belt.Int.toString(totalChanges)}`,
    `- **Added Endpoints**: ${Belt.Int.toString(Belt.Array.length(diff.addedEndpoints))}`,
    `- **Removed Endpoints**: ${Belt.Int.toString(Belt.Array.length(diff.removedEndpoints))}`,
    `- **Modified Endpoints**: ${Belt.Int.toString(Belt.Array.length(diff.modifiedEndpoints))}`,
    `- **Added Schemas**: ${Belt.Int.toString(Belt.Array.length(diff.addedSchemas))}`,
    `- **Removed Schemas**: ${Belt.Int.toString(Belt.Array.length(diff.removedSchemas))}`,
    `- **Modified Schemas**: ${Belt.Int.toString(Belt.Array.length(diff.modifiedSchemas))}`,
    `- **Breaking Changes**: ${hasBreaking ? "⚠️ Yes" : "✓ No"}`,
  ]
  
  Array.joinUnsafe(stats, "\n")
}

// Generate complete markdown report
let generateMarkdownReport = (
  ~diff: specDiff,
  ~baseName: string,
  ~forkName: string,
): string => {
  let sections = [
    `# API Diff Report: ${baseName} → ${forkName}`,
    "",
    "## Summary",
    "",
    generateStatsSummary(diff),
    generateAddedEndpointsSection(diff.addedEndpoints),
    generateRemovedEndpointsSection(diff.removedEndpoints),
    generateModifiedEndpointsSection(diff.modifiedEndpoints),
    generateAddedSchemasSection(diff.addedSchemas),
    generateRemovedSchemasSection(diff.removedSchemas),
    generateModifiedSchemasSection(diff.modifiedSchemas),
    "",
    "---",
    `*Generated on ${Date.make()->Date.toISOString}*`,
  ]
  
  sections
    ->Belt.Array.keep(s => s != "")
    ->Array.joinUnsafe("\n")
}

// Generate compact summary (for logs)
let generateCompactSummary = (diff: specDiff): string => {
  let added = Belt.Array.length(diff.addedEndpoints)
  let removed = Belt.Array.length(diff.removedEndpoints)
  let modified = Belt.Array.length(diff.modifiedEndpoints)
  let totalChanges = SpecDiffer.countChanges(diff)
  let breaking = if SpecDiffer.hasBreakingChanges(diff) {
    " (BREAKING CHANGES)"
  } else {
    ""
  }
  
  `Found ${Belt.Int.toString(totalChanges)} changes: +${Belt.Int.toString(added)} -${Belt.Int.toString(removed)} ~${Belt.Int.toString(modified)} endpoints${breaking}`
}

// Generate merge report
let generateMergeReport = (
  ~stats: SpecMerger.mergeStats,
  ~baseName: string,
  ~forkName: string,
): string => {
  let sections = [
    `# Merge Report: ${baseName} + ${forkName}`,
    "",
    "## Shared Code",
    "",
    `- **Shared Endpoints**: ${Belt.Int.toString(stats.sharedEndpointCount)}`,
    `- **Shared Schemas**: ${Belt.Int.toString(stats.sharedSchemaCount)}`,
    "",
    `## ${forkName} Extensions`,
    "",
    `- **Extension Endpoints**: ${Belt.Int.toString(stats.forkExtensionCount)}`,
    `- **Extension Schemas**: ${Belt.Int.toString(stats.forkSchemaCount)}`,
    "",
    "## Summary",
    "",
    `The shared base contains ${Belt.Int.toString(stats.sharedEndpointCount)} endpoints and ${Belt.Int.toString(stats.sharedSchemaCount)} schemas that are common to both specifications.`,
    "",
    `${forkName} adds ${Belt.Int.toString(stats.forkExtensionCount)} additional endpoints and ${Belt.Int.toString(stats.forkSchemaCount)} schemas on top of the shared base.`,
    "",
    "---",
    `*Generated on ${Date.make()->Date.toISOString}*`,
  ]
  
  Array.joinUnsafe(sections, "\n")
}

// Generate endpoints by tag report
let generateEndpointsByTagReport = (endpoints: array<endpoint>): string => {
  // Group endpoints by tag
  let byTag = Dict.make()
  let untagged = []
  
  endpoints->Belt.Array.forEach(ep => {
    switch ep.tags {
    | None | Some([]) => {
        let _ = Array.push(untagged, ep)
        ()
      }
    | Some(tags) => {
        tags->Belt.Array.forEach(tag => {
          let existing = switch Dict.get(byTag, tag) {
          | None => []
          | Some(arr) => arr
          }
          let _ = Array.push(existing, ep)
          Dict.set(byTag, tag, existing)
        })
      }
    }
  })
  
  let lines = ["## Endpoints by Tag", ""]
  
  // Sort tags
  let tags = Dict.keysToArray(byTag)->Belt.SortArray.stableSortBy(Pervasives.compare)
  
  tags->Belt.Array.forEach(tag => {
    switch Dict.get(byTag, tag) {
    | None => ()
    | Some(tagEndpoints) => {
        let count = Belt.Array.length(tagEndpoints)
        let _ = Array.push(lines, `### ${tag} (${Belt.Int.toString(count)})`)
        let _ = Array.push(lines, "")
        
        tagEndpoints->Belt.Array.forEach(ep => {
          let _ = Array.push(lines, `- ${formatEndpoint(ep)}`)
          ()
        })
        
        let _ = Array.push(lines, "")
        ()
      }
    }
  })
  
  // Add untagged section if any
  if Belt.Array.length(untagged) > 0 {
    let _ = Array.push(lines, `### Untagged (${Belt.Int.toString(Belt.Array.length(untagged))})`)
    let _ = Array.push(lines, "")
    
    untagged->Belt.Array.forEach(ep => {
      let _ = Array.push(lines, `- ${formatEndpoint(ep)}`)
      ()
    })
  }
  
  Array.joinUnsafe(lines, "\n")
}
