#!/usr/bin/env node
// Example 2: Compare two OpenAPI specs and generate a diff report
//
// This example demonstrates:
// - Comparing Misskey (base) vs Cherrypick (fork)
// - Detecting added, removed, and modified endpoints
// - Identifying breaking changes
// - Generating a detailed markdown report

import { compareSpecs } from '../src/Codegen.mjs';
import { resolve } from '../src/core/SchemaRefResolver.mjs';
import { mkdirSync } from 'fs';
import { join } from 'path';

async function main() {
  console.log('🔍 Example 2: Compare Misskey vs Cherrypick APIs\n');
  
  // Create output directory
  const outputDir = join(process.cwd(), 'examples/comparison');
  mkdirSync(outputDir, { recursive: true });
  
  // Fetch both specs
  console.log('📡 Fetching Misskey API spec...');
  const misskeyResult = await resolve('https://misskey.io/api.json', 120000);
  
  if (misskeyResult.TAG !== 'Ok') {
    console.error('❌ Failed to fetch Misskey spec:', misskeyResult._0);
    process.exit(1);
  }
  
  console.log('📡 Fetching Cherrypick API spec...');
  const cherrypickResult = await resolve('https://kokonect.link/api.json', 120000);
  
  if (cherrypickResult.TAG !== 'Ok') {
    console.error('❌ Failed to fetch Cherrypick spec:', cherrypickResult._0);
    process.exit(1);
  }
  
  const misskeySpec = misskeyResult._0;
  const cherrypickSpec = cherrypickResult._0;
  
  console.log('');
  console.log(`📊 Misskey API v${misskeySpec.info.version}`);
  console.log(`📊 Cherrypick API v${cherrypickSpec.info.version}`);
  console.log('');
  
  // Compare specs
  console.log('🔄 Comparing APIs...\n');
  
  const diffReportPath = join(outputDir, 'misskey-vs-cherrypick-diff.md');
  // compareSpecs expects positional args: (baseSpec, forkSpec, baseName, forkName, outputPath)
  const diff = await compareSpecs(
    misskeySpec,
    cherrypickSpec,
    'Misskey',
    'Cherrypick',
    diffReportPath
  );
  
  // Display summary
  // Note: ReScript uses camelCase field names (addedEndpoints, removedEndpoints, etc.)
  console.log('✅ Comparison complete!\n');
  console.log('📈 Summary:');
  console.log(`   Added endpoints:    ${diff.addedEndpoints.length}`);
  console.log(`   Removed endpoints:  ${diff.removedEndpoints.length}`);
  console.log(`   Modified endpoints: ${diff.modifiedEndpoints.length}`);
  console.log(`   Added schemas:      ${diff.addedSchemas.length}`);
  console.log(`   Removed schemas:    ${diff.removedSchemas.length}`);
  console.log(`   Modified schemas:   ${diff.modifiedSchemas.length}`);
  
  // Check for breaking changes in modified endpoints
  const breakingChanges = diff.modifiedEndpoints.filter(e => e.breakingChange);
  if (breakingChanges.length > 0) {
    console.log(`\n⚠️  Breaking changes detected: ${breakingChanges.length}`);
    
    // Show first few breaking changes
    const preview = breakingChanges.slice(0, 3);
    preview.forEach(change => {
      console.log(`   • ${change.path} (${change.method}): ${change.description || 'Modified'}`);
    });
    
    if (breakingChanges.length > 3) {
      console.log(`   ... and ${breakingChanges.length - 3} more`);
    }
  }
  
  console.log(`\n📄 Detailed report saved to:`);
  console.log(`   ${diffReportPath.replace(process.cwd(), '.')}`);
  
  console.log('\n💡 What\'s in the report:');
  console.log('   • List of all new endpoints in Cherrypick');
  console.log('   • Endpoints removed from Misskey');
  console.log('   • Changes to request/response schemas');
  console.log('   • Breaking change warnings');
  
  console.log('\n🎯 Key findings:');
  if (diff.addedEndpoints.length > 0) {
    console.log(`   Cherrypick adds ${diff.addedEndpoints.length} unique endpoints!`);
    console.log('   These are fork-specific features not in base Misskey.');
  }
  
  if (diff.modifiedEndpoints.length > 0) {
    console.log(`   ${diff.modifiedEndpoints.length} endpoints have different schemas.`);
    console.log('   This may indicate API divergence between forks.');
  }
}

main().catch(err => {
  console.error('💥 Error:', err);
  process.exit(1);
});
