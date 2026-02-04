#!/usr/bin/env node
// Example 1: Generate type-safe API client from a single OpenAPI spec
//
// This example demonstrates:
// - Fetching and parsing an OpenAPI 3.1 spec from a URL
// - Generating ReScript types and Sury validation schemas
// - Creating per-tag modules (Admin.res, Notes.res, etc.)
// - Using the unified IR pipeline for better type inference

import { generateFromUrl } from '../src/Codegen.mjs';
import { mkdirSync } from 'fs';
import { join } from 'path';

async function main() {
  console.log('📦 Example 1: Generate from Single OpenAPI Spec\n');
  
  // Create output directory
  const outputDir = join(process.cwd(), 'examples/single-spec/generated');
  mkdirSync(outputDir, { recursive: true });
  
  console.log('📡 Fetching Misskey API spec from https://misskey.io/api.json...');
  console.log('⏳ This may take a moment (parsing 400+ endpoints)...\n');
  
  // Call with separate arguments (ReScript labeled parameters compile to positional args)
  const result = await generateFromUrl(
    'https://misskey.io/api.json',  // url
    outputDir,                       // outputDir
    {                                // config (optional)
      specPath: 'https://misskey.io/api.json',
      outputDir,
      strategy: 'SharedBase',      // Single spec uses all endpoints
      modulePerTag: true,           // Generate one module per API tag (Admin.res, Notes.res, etc.)
      generateDiffReport: false,    // No diff for single spec
      breakingChangeHandling: 'Warn',
      includeTags: undefined,       // Include all tags
      excludeTags: undefined,       // Don't exclude any
      forkSpecs: undefined,         // No forks for single spec
    }
  );
  
  if (result.TAG === 'Ok') {
    const { generatedFiles } = result._0;
    
    console.log('✅ Code generation complete!\n');
    console.log(`📁 Generated ${generatedFiles.length} files:`);
    
    generatedFiles.forEach(file => {
      console.log(`   - ${file.replace(process.cwd(), '.')}`);
    });
    
    console.log('\n💡 What was generated:');
    console.log('   • ReScript type definitions for all request/response schemas');
    console.log('   • Sury validation schemas with runtime type checking');
    console.log('   • Type-safe endpoint functions with validated inputs/outputs');
    console.log('   • Organized by API tags (Admin, Notes, Users, etc.)');
    
    console.log('\n🚀 Next steps:');
    console.log('   1. Import the generated modules in your ReScript project');
    console.log('   2. Use the type-safe API functions with auto-completion');
    console.log('   3. Enjoy runtime validation powered by Sury');
    
  } else {
    console.error('❌ Generation failed:', result._0);
    process.exit(1);
  }
}

main().catch(err => {
  console.error('💥 Error:', err);
  process.exit(1);
});
