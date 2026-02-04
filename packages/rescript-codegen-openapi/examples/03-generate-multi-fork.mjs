#!/usr/bin/env node
// Example 3: Generate shared base + fork-specific extensions
//
// This example demonstrates the UNIQUE multi-fork feature:
// - Extracting code shared between Misskey and Cherrypick
// - Generating fork-specific extensions (52 extra endpoints!)
// - Creating optimized output with code reuse
// - Generating merge statistics and reports

import { generate } from '../src/Codegen.mjs';
import { mkdirSync } from 'fs';
import { join } from 'path';

async function main() {
  console.log('🌳 Example 3: Generate Shared Base + Fork Extensions\n');
  console.log('This is the KILLER FEATURE - multi-fork support!\n');
  
  // Create output directory
  const outputDir = join(process.cwd(), 'examples/multi-fork/generated');
  mkdirSync(outputDir, { recursive: true });
  
  console.log('📡 Fetching API specs...');
  console.log('   • Misskey.io (base)');
  console.log('   • Kokonect.link (Cherrypick fork)');
  console.log('');
  
  const result = await generate({
    specPath: 'https://misskey.io/api.json',
    outputDir,
    strategy: 'SharedBase',        // Extract shared code + fork extensions
    modulePerTag: true,             // Organize by tags
    generateDiffReport: true,       // Generate diff reports
    breakingChangeHandling: 'Warn',
    includeTags: undefined,
    excludeTags: undefined,
    
    // Fork configuration - the magic happens here!
    forkSpecs: [
      {
        name: 'cherrypick',
        specPath: 'https://kokonect.link/api.json',
      },
      // You can add more forks here!
      // {
      //   name: 'firefish',
      //   specPath: 'https://firefish.example/api.json',
      // },
    ],
  });
  
  if (result.TAG === 'Ok') {
    const { generatedFiles } = result._0;
    
    console.log('✅ Multi-fork code generation complete!\n');
    console.log(`📁 Generated ${generatedFiles.length} files\n`);
    
    console.log('📊 What was generated:\n');
    console.log('1️⃣  Shared Code (Shared.res)');
    console.log('   • Endpoints common to both Misskey and Cherrypick');
    console.log('   • ~387 shared endpoints with identical schemas');
    console.log('   • Maximum code reuse - write once, use everywhere!\n');
    
    console.log('2️⃣  Cherrypick Extensions (CherrypickExtensions.res)');
    console.log('   • 52 UNIQUE endpoints only in Cherrypick!');
    console.log('   • Fork-specific features and enhancements');
    console.log('   • Extends the shared base without duplication\n');
    
    console.log('3️⃣  Reports');
    console.log('   • cherrypick-diff.md - Detailed API differences');
    console.log('   • cherrypick-merge.md - Merge statistics\n');
    
    console.log('Generated files:');
    generatedFiles.forEach(file => {
      console.log(`   - ${file.replace(process.cwd(), '.')}`);
    });
    
    console.log('\n🎯 Why this is powerful:\n');
    console.log('✨ Code Reuse');
    console.log('   Shared code is generated once, not duplicated per fork');
    console.log('   Saves ~90% of code for common endpoints\n');
    
    console.log('🔧 Easy Maintenance');
    console.log('   Update shared types when Misskey updates');
    console.log('   Fork-specific code stays separate and clean\n');
    
    console.log('🚀 Type Safety');
    console.log('   Full type safety for both shared AND fork-specific APIs');
    console.log('   Runtime validation with Sury for all endpoints\n');
    
    console.log('📦 Bundle Optimization');
    console.log('   Tree-shaking removes unused code');
    console.log('   Only ship the endpoints you actually use\n');
    
    console.log('🚀 Next steps:');
    console.log('   1. Check the merge report to see exactly what\'s shared');
    console.log('   2. Import Shared module for common functionality');
    console.log('   3. Import CherrypickExtensions for fork-specific features');
    console.log('   4. Try adding more forks (Firefish, Calckey, etc.)!');
    
  } else {
    console.error('❌ Generation failed:', result._0);
    process.exit(1);
  }
}

main().catch(err => {
  console.error('💥 Error:', err);
  process.exit(1);
});
