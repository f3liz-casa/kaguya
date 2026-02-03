// Example usage of rescript-mfm
// Basic examples that demonstrate the core functionality

// ============================================================
// Basic Parsing
// ============================================================

let basicExample = () => {
  Console.log("=== Basic Parsing ===")
  
  let text = "Hello **world**! I'm @ai, A bot of misskey! :heart:"
  Console.log("Input: " ++ text)
  
  let nodes = Mfm.parse(text)
  Console.log2("Parsed nodes:", nodes)
  
  let reconstructed = Mfm.toString(nodes)
  Console.log("Reconstructed: " ++ reconstructed)
}

// ============================================================
// Simple Parsing (Emoji + Text only)
// ============================================================

let simpleExample = () => {
  Console.log("\n=== Simple Parsing ===")
  
  let text = "I like the hot soup :soup: :fire:"
  Console.log("Input: " ++ text)
  
  let nodes = Mfm.parseSimple(text)
  Console.log2("Simple parsed nodes:", nodes)
  
  let reconstructed = Mfm.toString(nodes)
  Console.log("Reconstructed: " ++ reconstructed)
}

// ============================================================
// Extracting Specific Node Types
// ============================================================

let extractionExample = () => {
  Console.log("\n=== Extracting Node Types ===")
  
  let text = "Hello @alice@example.com and @bob! Check #misskey and #fediverse :heart:"
  Console.log("Input: " ++ text)
  
  let nodes = Mfm.parse(text)
  
  // Extract mentions
  let mentions = Mfm.getAllOfType(nodes, "mention")
  Console.log("Mentions found: " ++ Int.toString(mentions->Array.length))
  
  // Extract hashtags
  let hashtags = Mfm.getAllOfType(nodes, "hashtag")
  Console.log("Hashtags found: " ++ Int.toString(hashtags->Array.length))
  
  // Extract emojis
  let emojis = Mfm.getAllOfType(nodes, "emojiCode")
  Console.log("Emojis found: " ++ Int.toString(emojis->Array.length))
  
  // Check if contains specific types
  Console.log("Has mentions: " ++ Bool.toString(Mfm.containsType(nodes, "mention")))
  Console.log("Has URLs: " ++ Bool.toString(Mfm.containsType(nodes, "url")))
}

// ============================================================
// Extracting Text Content
// ============================================================

let textExtractionExample = () => {
  Console.log("\n=== Text Extraction ===")
  
  let text = "Hello **world**! This is *italic* and ~~strikethrough~~"
  Console.log("Input: " ++ text)
  
  let nodes = Mfm.parse(text)
  let plainText = Mfm.extractText(nodes)
  Console.log("Plain text: " ++ plainText)
}

// ============================================================
// Inspecting Nodes
// ============================================================

let inspectionExample = () => {
  Console.log("\n=== Inspecting Nodes ===")
  
  let text = "$[tada Hello!] **Bold text** and *italic*"
  Console.log("Input: " ++ text)
  
  let nodes = Mfm.parse(text)
  
  Console.log("Node types in order:")
  Mfm.inspect(nodes, node => {
    Console.log("  - " ++ node.type_)
  })
}

// ============================================================
// Nest Limit Example
// ============================================================

let nestLimitExample = () => {
  Console.log("\n=== Nest Limit ===")
  
  let text = "**bold1 **bold2 **bold3 **bold4****"
  Console.log("Input: " ++ text)
  
  // Parse with default nest limit (20)
  let nodes1 = Mfm.parse(text)
  Console.log2("With default limit:", nodes1)
  
  // Parse with custom nest limit
  let nodes2 = Mfm.parse(~nestLimit=2, text)
  Console.log2("With limit 2:", nodes2)
}

// ============================================================
// Run All Examples
// ============================================================

let runAllExamples = () => {
  basicExample()
  simpleExample()
  extractionExample()
  textExtractionExample()
  inspectionExample()
  nestLimitExample()
}

// Run examples if this is the main module
if %external(__filename) == %external(__main__) {
  runAllExamples()
}
