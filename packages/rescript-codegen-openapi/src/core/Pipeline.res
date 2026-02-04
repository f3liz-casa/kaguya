// SPDX-License-Identifier: MIT
// Pipeline.res - Pure data transformation pipeline
open Types

// Represents the output of a generation step
type generationOutput = {
  files: array<FileSystem.fileToWrite>,
  warnings: array<warning>,
}

// Empty output
let empty: generationOutput = {
  files: [],
  warnings: [],
}

// Combine multiple outputs
let combine = (outputs: array<generationOutput>): generationOutput => {
  let allFiles = []
  let allWarnings = []
  
  outputs->Array.forEach(output => {
    allFiles->Array.pushMany(output.files)
    allWarnings->Array.pushMany(output.warnings)
  })
  
  {
    files: allFiles,
    warnings: allWarnings,
  }
}

// Add warnings to an output
let withWarnings = (output: generationOutput, warnings: array<warning>): generationOutput => {
  {
    ...output,
    warnings: Array.concat(output.warnings, warnings),
  }
}

// Add files to an output
let withFiles = (output: generationOutput, files: array<FileSystem.fileToWrite>): generationOutput => {
  {
    ...output,
    files: Array.concat(output.files, files),
  }
}

// Create output from a single file
let fromFile = (file: FileSystem.fileToWrite): generationOutput => {
  {
    files: [file],
    warnings: [],
  }
}

// Create output from files with warnings
let fromFilesAndWarnings = (
  files: array<FileSystem.fileToWrite>,
  warnings: array<warning>,
): generationOutput => {
  {
    files,
    warnings,
  }
}

// Map over files in an output
let mapFiles = (
  output: generationOutput,
  fn: FileSystem.fileToWrite => FileSystem.fileToWrite,
): generationOutput => {
  {
    ...output,
    files: output.files->Array.map(fn),
  }
}

// Filter warnings
let filterWarnings = (
  output: generationOutput,
  predicate: warning => bool,
): generationOutput => {
  {
    ...output,
    warnings: output.warnings->Array.filter(predicate),
  }
}

// Get file count
let fileCount = (output: generationOutput): int => {
  Array.length(output.files)
}

// Get warning count
let warningCount = (output: generationOutput): int => {
  Array.length(output.warnings)
}

// Get file paths
let filePaths = (output: generationOutput): array<string> => {
  output.files->Array.map(file => file.path)
}
