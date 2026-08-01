# PowerShell Copilot Standards Implementation Guide

## 🚀 Quick Setup Guide

### Prerequisites

- GitHub Copilot subscription
- VS Code with GitHub Copilot extension
- PowerShell 7.6 (LTS) recommended; Windows PowerShell 5.1 supported for legacy estates
- Git for version control

### Step 1: Confirm VS Code Picks Up the Instructions

No configuration is required. Current VS Code loads `.github/copilot-instructions.md`
automatically, applies `.github/instructions/*.instructions.md` to files matching their `applyTo`
glob, and exposes `.github/prompts/*.prompt.md` as `/prompt-name` in Copilot Chat.

Settings are only needed when these files live outside the default locations:

```json
{
  "chat.instructionsFilesLocations": { ".github/instructions": true },
  "chat.promptFilesLocations": { ".github/prompts": true }
}
```

To open settings.json:

1. Press `Ctrl+Shift+P` (Windows/Linux) or `Cmd+Shift+P` (Mac)
2. Type "Preferences: Open Settings (JSON)"
3. Add the settings above

> Earlier guidance used `chat.promptFiles` and
> `github.copilot.chat.codeGeneration.useInstructionFiles`. Settings-based instructions were
> deprecated in VS Code 1.102 in favour of the file-based layout above.

### Step 2: Choose Implementation Method

#### Method A: New Project from Template

1. Go to this repository on GitHub
2. Click "Use this template" → "Create a new repository"
3. Name your project and create it
4. Clone and start developing

#### Method B: Add to Existing Project

```bash
# Navigate to your project
cd /path/to/your/project

# Add as submodule
git submodule add https://github.com/fadwen/PowerShell-Copilot-Standards.git .copilot-standards

# Create symbolic link to instructions
# Windows:
mklink .github\copilot-instructions.md .copilot-standards\.github\copilot-instructions.md

# Linux/macOS:
ln -s .copilot-standards/.github/copilot-instructions.md .github/copilot-instructions.md
```

#### Method C: Direct Copy (Simple Projects)

```powershell
# Clone the standards repository
git clone https://github.com/fadwen/PowerShell-Copilot-Standards.git

# Copy files to your project
Copy-Item -Path "PowerShell-Copilot-Standards\.github\*" -Destination "YourProject\.github\" -Recurse -Force
```

### Step 3: Verify Setup

1. **Test Copilot Integration**
   - Open a `.ps1` file in VS Code
   - Open Copilot Chat (`Ctrl+Shift+I`)
   - Type `/new-function` - you should see your custom prompt

2. **Validate Standards**

   ```powershell
   # If you have the tools directory
   .\Tools\Test-StandardsCompliance.ps1 -Path "." -Detailed
   ```

### Step 4: Create Your First Function

1. Open Copilot Chat in VS Code
2. Type `/new-function`
3. Follow the prompts to specify:
   - Function name (e.g., "Get-ServerHealth")
   - Purpose (e.g., "Monitor server performance metrics")
   - Parameters (e.g., "ComputerName:string[], Threshold:int")

Copilot will generate a complete enterprise-standard function with:

- Approved PowerShell verb
- Comprehensive comment-based help
- Proper parameter validation
- Error handling with correlation IDs
- Basic Pester tests

## 🎯 Daily Usage Patterns

### Quick Development Tasks

- `/new-function` - Create new PowerShell function
- `/security-review` - Analyze code for security issues
- `/optimize-performance` - Improve code performance
- `/create-test` - Generate Pester test suite

### Code Quality Tasks

- `/code-analysis` - Comprehensive code quality analysis
- `/validate-standards` - Check community standards compliance

### Advanced Tasks

- Create modules with proper structure
- Generate CI/CD pipelines
- Build compliance-ready scripts

## 📚 Learning Path

### Week 1: Basics

1. Set up Copilot instructions
2. Create first function using prompts
3. Run standards validation
4. Review generated documentation

### Week 2: Intermediate

1. Create a complete module
2. Use security and performance prompts
3. Set up automated testing
4. Integrate with CI/CD

### Week 3: Advanced

1. Customize instructions for your team
2. Create project-specific prompts
3. Set up compliance frameworks
4. Train team members

## 🔧 Troubleshooting Setup

### Common Issues

**Copilot doesn't use instructions**

- Check that `.github/copilot-instructions.md` exists at the workspace root
- Confirm instruction files sit under `.github/instructions/` with an `applyTo` glob that matches
  the file being edited
- If the files live elsewhere, set `chat.instructionsFilesLocations` / `chat.promptFilesLocations`
- Restart VS Code after moving or adding files

**Prompts don't appear**

- Ensure `.github/prompts/*.prompt.md` files exist
- Verify file extensions are correct (`.prompt.md`)
- Check that prompt files have proper front matter

**Standards not applied**

- Verify instruction files are in `.github/instructions/`
- Check `applyTo` patterns in instruction files
- Ensure you're working with PowerShell files (`.ps1`, `.psm1`)

### Getting Help

- Check the [Troubleshooting](../Troubleshooting/) directory
- Review existing GitHub Issues
- Create a new issue with detailed information
