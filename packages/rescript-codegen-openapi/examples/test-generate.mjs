#!/usr/bin/env node
// Quick test with local small spec

import { generateFromUrl } from '../src/Codegen.mjs';
import { mkdirSync } from 'fs';
import { join } from 'path';

async function main() {
  console.log('🧪 Quick test\n');
  
  const outputDir = join(process.cwd(), 'examples/test-output');
  mkdirSync(outputDir, { recursive: true });
  
  console.log('📡 Testing with small spec...');
  
  // Use a smaller API for testing
  const result = await generateFromUrl(
    'https://petstore3.swagger.io/api/v3/openapi.json',
    outputDir,
  );
  
  if (result.TAG === 'Ok') {
    const success = result._0;
    console.log('✅ Success!');
    console.log(`Generated ${success.generatedFiles.length} files:`);
    success.generatedFiles.forEach(f => console.log(`  - ${f}`));
    
    console.log('\n📋 Checking warnings...');
    console.log(`warnings type: ${typeof success.warnings}, value:`, success.warnings);
    
    if (success.warnings && success.warnings.length > 0) {
      console.log(`\n⚠️  Warnings (${success.warnings.length}):`);
      success.warnings.slice(0, 5).forEach(w => {
        console.log(`  - ${w.TAG}`);
      });
      if (success.warnings.length > 5) {
        console.log(`  ... and ${success.warnings.length - 5} more`);
      }
    } else {
      console.log('No warnings!');
    }
  } else {
    const error = result._0;
    console.error('❌ Failed!');
    console.error('Error type:', error.TAG);
    console.error('Details:', JSON.stringify(error, null, 2));
  }
}

main().catch(err => {
  console.error('💥 Error:', err);
  process.exit(1);
});
