# GitHub Copilot Prompt Files Guide

## 🎯 Understanding Prompt Files

Prompt files are Markdown files with a `.prompt.md` extension that contain reusable instructions for GitHub Copilot. They allow you to create interactive, customizable code generation experiences.

## 📁 Prompt File Structure

### Basic Structure
```markdown
---
mode: 'agent'
description: 'Brief description of what this prompt does'
tools: ['codebase', 'githubRepo']  # Optional: tools Copilot can use
---

# Prompt Title

Your prompt content with instructions for Copilot...

Variables: ${input:variableName:defaultValue}
Context: ${file}, ${workspaceFolder}, ${selection}
```

### Available Modes
- **`agent`**: Generates new content or performs complex analysis
- **`edit`**: Modifies existing selected code
- **`ask`**: Answers questions about code or provides guidance

### Available Tools
- **`codebase`**: Access to your entire codebase for context
- **`githubRepo`**: Access to repository information and history
- **`terminal`**: Can suggest terminal commands
- **`web`**: Can search for additional information

## 🔧 Variable Types

### Input Variables
```markdown
${input:variableName}                    # Simple input prompt
${input:functionName:Get-Something}      # Input with default value
${input:purpose:What does this do?}      # Input with descriptive prompt
```

### Context Variables
```markdown
${file}                    # Current file path
${fileBasename}           # Current file name
${fileDirname}            # Current file directory
${workspaceFolder}        # Workspace root path
${workspaceFolderBasename} # Workspace folder name
${selection}              # Currently selected text
${selectedText}           # Same as selection
```

## 📝 Creating Effective Prompts

### 1. Clear Instructions
```markdown
Create a PowerShell function with these requirements:
- Use approved verb from Get-Verb
- Include comprehensive comment-based help
- Implement proper error handling
- Add correlation ID tracking
```

### 2. Context Awareness
```markdown
For the ${workspaceFolderBasename} project in ${fileBasename}:

Function specifications:
- Name: ${input:functionName:Get-Something}
- Purpose: ${input:purpose}
```

### 3. Progressive Examples
```markdown
**Basic Example**: Simple usage scenario
**Advanced Example**: Complex real-world usage
**Enterprise Example**: Full integration scenario
```

## 🎨 Prompt File Examples

### Simple Function Creation
```markdown
---
mode: 'agent'
description: 'Creates a basic PowerShell function'
---

Create a PowerShell function named ${input:functionName:Get-Data} that:
- ${input:purpose:What should this function do?}
- Follows enterprise standards
- Includes proper error handling
```

### Interactive Security Review
```markdown
---
mode: 'edit'
description: 'Performs security analysis on selected code'
---

Analyze this PowerShell code for security issues:

**Code to Review:**
```powershell
${selection}
```

**Analysis Areas:**
- Input validation: ${input:checkInput:Yes}
- Credential handling: ${input:checkCreds:Yes}
- Compliance: ${input:framework:General}

Provide specific remediation recommendations.
```

### Context-Aware Module Creation
```markdown
---
mode: 'agent'
description: 'Creates module structure for current workspace'
tools: ['codebase']
---

Create a PowerShell module for ${workspaceFolderBasename}:

**Module Details:**
- Name: ${input:moduleName:${workspaceFolderBasename}}
- Purpose: ${input:purpose}
- Complexity: ${input:complexity:Medium}

**Current Context:**
- Working in: ${fileDirname}
- Workspace: ${workspaceFolder}
```

## 🚀 Using Prompt Files

### Method 1: Copilot Chat Command
```
/prompt-name
```
Example: `/new-function`

### Method 2: Attach Context Menu
1. Open Copilot Chat
2. Click the attachment icon (📎)
3. Select "Prompts"
4. Choose your prompt file

### Method 3: Command Palette
1. Press `Ctrl+Shift+P` (Windows/Linux) or `Cmd+Shift+P` (Mac)
2. Type "Chat: Run Prompt"
3. Select your prompt file

## 🎯 Best Practices

### 1. Descriptive File Names
```
new-function.prompt.md           # ✅ Clear purpose
security-review.prompt.md        # ✅ Specific task
analyze-code.prompt.md           # ✅ Action-oriented

my-prompt.prompt.md             # ❌ Vague
test.prompt.md                  # ❌ Unclear
```

### 2. Meaningful Descriptions
```markdown
description: 'Creates enterprise-standard PowerShell function'  # ✅ Clear
description: 'Makes a function'                                # ❌ Vague
```

### 3. Smart Defaults
```markdown
${input:functionName:Get-Something}        # ✅ Helpful default
${input:purpose:What does this do?}        # ✅ Descriptive prompt
${input:functionName}                      # ❌ No guidance
```

### 4. Progressive Complexity
Start simple, add complexity as needed:
```markdown
# Basic version
Create a function named ${input:name}

# Enhanced version  
Create a function for ${workspaceFolderBasename} project:
- Name: ${input:name:Get-Data}
- Purpose: ${input:purpose}
- Environment: ${input:env:Development}
```

## 🔧 Troubleshooting Prompt Files

### Common Issues

**Prompt doesn't appear in Copilot**
- Verify file extension is `.prompt.md`
- Check that file is in `.github/prompts/` directory
- Ensure front matter is properly formatted
- Restart VS Code

**Variables don't work**
- Check syntax: `${input:variableName}`
- Verify no spaces in variable names
- Ensure proper front matter formatting

**Copilot ignores instructions**
- Make instructions more specific
- Add examples of expected output
- Use imperative language ("Create", "Generate", "Analyze")
- Break complex tasks into steps

### Debugging Tips
```markdown
# Add debug information to your prompts
**Debug Info:**
- Workspace: ${workspaceFolder}
- File: ${file}
- Selection length: ${selection.length}

This helps verify variables are working correctly.
```

## 📚 Advanced Techniques

### Conditional Logic
```markdown
**Analysis Type:** ${input:analysisType:Security,Performance,Quality}

${if analysisType === 'Security'}
Focus on security vulnerabilities and compliance.
${endif}

${if analysisType === 'Performance'}
Focus on optimization opportunities and benchmarks.
${endif}
```

### Multi-Step Workflows
```markdown
**Step 1:** Create the main function
**Step 2:** Generate comprehensive tests
**Step 3:** Add integration documentation
**Step 4:** Create usage examples

Execute all steps for: ${input:functionName}
```

### Template Integration
```markdown
Use the ${workspaceFolderBasename} project template:
- Reference existing patterns in ${workspaceFolder}
- Follow established conventions from ${file}
- Integrate with current architecture
```

## 🎨 Customization Examples

### Team-Specific Prompts
```markdown
---
mode: 'agent'
description: 'Creates infrastructure automation function for our team'
---

Create PowerShell function for infrastructure team:
- Include SCOM integration hooks
- Add ServiceNow ticket correlation
- Follow our naming convention: Verb-InfraNoun
- Target environment: ${input:environment:Production}
```

### Project-Specific Prompts
```markdown
---
mode: 'agent'  
description: 'Creates function specific to this project architecture'
tools: ['codebase']
---

Analyze ${workspaceFolderBasename} codebase patterns and create function:
- Follow existing error handling patterns
- Use established logging framework
- Integrate with current data access layer
- Function: ${input:functionName}
```

This guide provides everything you need to create, use, and customize prompt files for your PowerShell development workflow.
