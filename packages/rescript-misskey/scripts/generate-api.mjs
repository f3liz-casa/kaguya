#!/usr/bin/env node
// Generate type-safe Misskey API client from OpenAPI spec
// This replaces the manual misskey-js bindings with auto-generated code

import { generateFromUrl } from '../../rescript-codegen-openapi/src/Codegen.mjs';
import { mkdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

async function main() {
  console.log('📦 Generating Misskey API client from OpenAPI spec\n');
  
  // Create output directory
  const outputDir = join(__dirname, '../src/generated');
  mkdirSync(outputDir, { recursive: true });
  
  console.log('📡 Fetching Misskey API spec from https://misskey.io/api.json...');
  console.log('⏳ This may take a moment (parsing 400+ endpoints)...\n');
  
  // Generate from OpenAPI spec
  const result = await generateFromUrl(
    'https://misskey.io/api.json',  // url
    outputDir,                       // outputDir
    {                                // config
      specPath: 'https://misskey.io/api.json',
      outputDir,
      strategy: 'SharedBase',        // Single spec uses all endpoints
      modulePerTag: true,             // Generate one module per API tag
      generateDiffReport: false,      // No diff for single spec
      breakingChangeHandling: 'Warn',
      includeTags: undefined,         // Include all tags
      excludeTags: undefined,         // Don't exclude any
      forkSpecs: undefined,           // No forks for single spec
    }
  );
  
  if (result.TAG === 'Ok') {
    const { generatedFiles } = result._0;
    
    console.log('✅ Code generation complete!\n');
    console.log(`📁 Generated ${generatedFiles.length} files:`);
    
    generatedFiles.forEach(file => {
      console.log(`   - ${file.replace(process.cwd(), '.')}`);
    });
    
    console.log('\n💡 Generated code includes:');
    console.log('   • ReScript type definitions for all request/response schemas');
    console.log('   • Sury validation schemas with runtime type checking');
    console.log('   • Type-safe endpoint functions with validated inputs/outputs');
    console.log('   • Organized by API tags (Admin, Notes, Users, etc.)');
    
    console.log('\n🚀 Next step: Update MisskeyJS modules to use generated code');
    
  } else {
    console.error('❌ Generation failed:', result._0);
    process.exit(1);
  }
}

main().catch(err => {
  console.error('💥 Error:', err);
  process.exit(1);
});
