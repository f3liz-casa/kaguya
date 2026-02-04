// Test script to fetch and parse Misskey/Cherrypick APIs
import { resolve } from '../src/core/SchemaRefResolver.mjs';
import { getAllEndpoints, getAllTags } from '../src/core/OpenAPIParser.mjs';

async function testParser() {
  console.log('🧪 Testing rescript-codegen-openapi\n');
  
  // Test 1: Parse Misskey API
  console.log('📡 Fetching misskey.io/api.json...');
  const misskeyResult = await resolve('https://misskey.io/api.json', 120000);
  
  if (misskeyResult.TAG === 'Ok') {
    const spec = misskeyResult._0;
    console.log(`✅ Misskey API v${spec.info.version}`);
    
    const endpoints = getAllEndpoints(spec);
    console.log(`   Total endpoints: ${endpoints.length}`);
    
    const tags = getAllTags(endpoints);
    console.log(`   Tags: ${tags.slice(0, 10).join(', ')}${tags.length > 10 ? ', ...' : ''}`);
  } else {
    console.error('❌ Failed to parse Misskey:', misskeyResult._0);
    return;
  }
  
  console.log('');
  
  // Test 2: Parse Cherrypick API
  console.log('📡 Fetching kokonect.link/api.json...');
  const cherrypickResult = await resolve('https://kokonect.link/api.json', 120000);
  
  if (cherrypickResult.TAG === 'Ok') {
    const spec = cherrypickResult._0;
    console.log(`✅ Cherrypick API v${spec.info.version}`);
    
    const endpoints = getAllEndpoints(spec);
    console.log(`   Total endpoints: ${endpoints.length}`);
    
    const tags = getAllTags(endpoints);
    console.log(`   Tags: ${tags.slice(0, 10).join(', ')}${tags.length > 10 ? ', ...' : ''}`);
  } else {
    console.error('❌ Failed to parse Cherrypick:', cherrypickResult._0);
    return;
  }
  
  console.log('\n✨ All tests passed!');
}

testParser().catch(err => {
  console.error('💥 Error:', err);
  process.exit(1);
});
