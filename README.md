# PowerShell Copilot Standards

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Jeffrey_Stuhr-0077B5?style=flat-square&logo=linkedin)](https://www.linkedin.com/in/jeffrey-stuhr-034214aa/)
[![BlueSky](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fpublic.api.bsky.app%2Fxrpc%2Fapp.bsky.actor.getProfile%2F%3Factor%3Dtechbyjeff.net&query=%24.followersCount&style=social&logo=bluesky&label=Follow%20on%20BSky)](https://bsky.app/profile/techbyjeff.net)
[![Blog](https://img.shields.io/badge/Read_My_Blog-TechbyJeff-lightgrey?style=flat-square&logo=ghost)](https://techbyjeff.net)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PowerShell](https://img.shields.io/badge/PowerShell-7.6_LTS-blue.svg)](https://github.com/PowerShell/PowerShell)
[![GitHub Copilot](https://img.shields.io/badge/GitHub%20Copilot-Optimized-green.svg)](https://github.com/features/copilot)

Enterprise-grade PowerShell development standards and GitHub Copilot instructions for consistent, secure, and
high-quality PowerShell code across teams and projects.

> **Target versions** (verified 2026-08-01): **PowerShell 7.6 (LTS)** is the default target,
> supported through 14-Nov-2028. Windows PowerShell 5.1 remains supported as a compatibility
> target. **PowerShell 7.4 and 7.5 both reach end of support on 10-Nov-2026** — plan upgrades now.
> See [powershell-version.instructions.md](.github/instructions/powershell-version.instructions.md)
> for the full lifecycle table, version-gated features, and breaking changes.

## 🚀 Quick Start

### For New Projects

```bash
# Use as template repository or clone
git clone https://github.com/fadwen/PowerShell-Copilot-Standards.git
cd PowerShell-Copilot-Standards

# Install standards in your project
./Tools/Install-CopilotStandards.ps1 -ProjectPath "C:\YourProject" -StandardsType "Module"
```

### For Existing Projects

```bash
# Add as submodule
git submodule add https://github.com/fadwen/PowerShell-Copilot-Standards.git .copilot-standards

# Link instructions (Windows)
mklink .github\copilot-instructions.md .copilot-standards\.github\copilot-instructions.md

# Link instructions (Linux/macOS)
ln -s .copilot-standards/.github/copilot-instructions.md .github/copilot-instructions.md
```

## 📋 What's Included

### 🤖 GitHub Copilot Integration

- **Main Instructions**: Comprehensive enterprise PowerShell standards
- **Prompt Files**: Quick-access prompts for common tasks
- **Variable Prompts**: Interactive code generation
- **Quality Gates**: Automated validation and enforcement

### 📚 PowerShell Standards

- **Version Baseline**: PowerShell 7.6 (LTS) targeting, with the support lifecycle, version-gated
  cmdlets, and breaking changes for 7.5/7.6 documented in one place
- **Community Best Practices**: Integrated PowerShell community guidelines
- **Enterprise Security**: Audit logging, credential handling, and data-classification patterns
  covering controls that SOX, GDPR, and HIPAA programmes commonly ask for
- **Performance Optimization**: Memory management and pipeline efficiency, including the
  version-dependent `+=` guidance that changed in PowerShell 7.5
- **Modern Tooling**: `Install-PSResource` (Microsoft.PowerShell.PSResourceGet) over PowerShellGet
  v2, with a capability check for Windows PowerShell 5.1 fallback
- **Testing Standards**: Pester 6 patterns — `Should-*` assertions, `BeforeDiscovery` data,
  self-contained test files, and 12 supporting guides covering mocking, CI, and templates

### 🛠️ Development Tools

- **Project Templates**: Module, script collection, and application templates
- **Validation Scripts**: Automated standards compliance checking
- **CI/CD Integration**: GitHub Actions and Azure DevOps templates
- **Troubleshooting Guides**: Organized problem-solving documentation

## 🎯 Key Features

### ✨ Automatic Code Generation

- **Enterprise Functions**: Complete functions with security, error handling, and documentation
- **Module Scaffolding**: Full module structure with tests and documentation
- **CI/CD Pipelines**: Automated quality gates and deployment workflows

### 🔒 Security by Design

- **Input Validation**: Comprehensive sanitization and validation patterns
- **Credential Management**: SecretManagement integration and secure handling
- **Regulatory Patterns**: Audit-trail, consent, and access-control patterns for SOX, GDPR, and
  HIPAA work. These are code patterns and review prompts — they support a compliance programme but
  do not constitute one, and none of it substitutes for your own controls, evidence, and audit
- **Security Scanning**: Automated vulnerability detection

### 📊 Quality Assurance

- **Code Analysis**: Comprehensive quality assessment tools
- **Performance Testing**: Automated benchmarking and optimization
- **Documentation Standards**: Complete comment-based help and README generation
- **Community Compliance**: PowerShell best practices enforcement

## 📁 Repository Structure

```text
PowerShell-Copilot-Standards/
├── .github/
│   ├── copilot-instructions.md          # Main Copilot instructions (applied automatically)
│   ├── instructions/                    # 12 scoped instruction files, applied by `applyTo` glob
│   │   ├── powershell-version.instructions.md   # Version baseline, lifecycle, breaking changes
│   │   ├── pester.instructions.md               # Pester 6 core testing standards
│   │   └── pester-supporting-docs/              # 12 guides: mocking, CI, templates, v6 migration
│   ├── prompts/                         # 10 `/prompt-name` files for Copilot Chat
│   └── workflows/                       # Quality gates run on every pull request
├── Documentation/                       # Reference materials and worked examples
├── Templates/                           # Module, script-collection, and application templates
├── Tools/                               # Install-CopilotStandards, Test-StandardsCompliance
├── Troubleshooting/                     # Organized problem-solving guides
├── .markdownlint.json                   # Documentation lint rules enforced in CI
└── README.md                            # This file
```

## 🚀 Getting Started

### 1. Enable Copilot Instructions

Current VS Code picks these up with no configuration: `.github/copilot-instructions.md` is applied
automatically, `.github/instructions/*.instructions.md` apply to files matching their `applyTo`
glob, and `.github/prompts/*.prompt.md` are available as `/prompt-name` in Copilot Chat.

You only need settings if you keep these files somewhere other than the defaults:

```json
{
  "chat.instructionsFilesLocations": { ".github/instructions": true },
  "chat.promptFilesLocations": { ".github/prompts": true }
}
```

> Older guidance recommended `chat.promptFiles` and
> `github.copilot.chat.codeGeneration.useInstructionFiles`. Settings-based instructions were
> deprecated in VS Code 1.102 in favour of the file-based layout above; neither setting is required
> now.

### 2. Choose Your Integration Method

#### Option A: Template Repository (New Projects)

1. Click "Use this template" above
2. Create your new repository
3. Start developing with standards automatically applied

#### Option B: Git Submodule (Existing Projects)

```bash
git submodule add https://github.com/fadwen/PowerShell-Copilot-Standards.git .copilot-standards
```

#### Option C: Direct Copy (Simple Projects)

```powershell
./Tools/Install-CopilotStandards.ps1 -ProjectPath "." -StandardsType "Basic"
```

### 3. Verify Setup

```powershell
# Test standards compliance
./Tools/Test-StandardsCompliance.ps1 -Path "."

# Create your first function using Copilot
# In VS Code, type: /new-function
```

## 💡 Usage Examples

### Quick Function Creation

```powershell
# Use the new-function prompt in Copilot Chat
/new-function
# Copilot will prompt for: function name, purpose, parameters
# Generates complete enterprise-standard function with tests
```

### Security Review

```powershell
# Select PowerShell code, then use security-review prompt
/security-review
# Comprehensive security analysis with compliance validation
```

### Performance Optimization

```powershell
# Select code that needs optimization
/optimize-performance
# Get specific optimization recommendations with benchmarks
```

## 🧪 Testing and Quality

### Automated Testing

Standards for the code you generate — Pester 6 throughout:

- **Unit Tests**: Pester tests targeting 80%+ coverage
- **Integration Tests**: External dependency validation
- **Performance Tests**: Benchmarking and regression detection
- **Security Tests**: Input validation and credential handling

### Quality Gates

These run against this repository on every pull request, and the templates set the same gates up
for yours:

- **PSScriptAnalyzer**: Zero errors in production files (test files are analyzed separately, since
  patterns like a hardcoded `-ComputerName 'MOCKSERVER'` are legitimate in a mock)
- **Pester**: Fails on `FailedCount` _and_ `FailedContainersCount` — a file that fails discovery
  contributes zero failed tests and would otherwise read green
- **Coverage**: Measured over `Tools/` and `Documentation/Examples/`, the code this repository ships
  and holds up as exemplary. Templates are excluded: they are scaffolding to copy, so covering a
  placeholder measures nothing
- **Security Scanning**: Credential leak and vulnerability detection. Secret patterns apply to all
  files; code-execution patterns apply only to `.ps1`/`.psm1`, since a `.psd1` is restricted data
  and cannot invoke a cmdlet
- **Documentation**: markdownlint over all Markdown, plus comment-based help validation
- **Community Standards**: PowerShell best practices compliance

## 🔧 Customization

### Team-Specific Instructions

Create `.instructions.md` files in your project for team-specific standards:

```markdown
---
applyTo: "**/*.ps1"
---
# Team-specific PowerShell standards
- Use specific naming conventions for your domain
- Include team-specific validation patterns
- Reference team tools and processes
```

### Project-Specific Prompts

Add custom prompts for your specific use cases:

```markdown
---
mode: 'agent'
description: 'Creates infrastructure automation function'
---
Create function for infrastructure management with:
- SCOM integration
- ServiceNow ticket correlation
- Active Directory validation
```

## 📚 Documentation

### Core Documentation

- **[PowerShell Version Baseline](./.github/instructions/powershell-version.instructions.md)**:
  Support lifecycle, choosing a target, version-gated features, breaking changes
- **[Pester 6 Testing Standards](./.github/instructions/pester.instructions.md)**: Core testing
  requirements, with [12 supporting guides](./.github/instructions/pester-supporting-docs/) for
  mocking, CI, templates, and v6 migration
- **[Implementation Guide](./Documentation/Implementation-Guide.md)**: Step-by-step setup and usage
- **[PowerShell Best Practices](./Documentation/PowerShell-Best-Practices.md)**: Community standards reference
- **[Enterprise Extensions](./Documentation/Enterprise-Extensions.md)**: Organization-specific additions

### Quick References

- **[Prompt Files Guide](./Documentation/Prompt-Files-Guide.md)**: How to use and create prompts
- **[Troubleshooting](./Troubleshooting/)**: Organized problem-solving guides
- **[Examples](./Documentation/Examples/)**: Real-world usage examples

## 🤝 Contributing

### Adding New Standards

1. Create feature branch: `git checkout -b feature/new-standard`
2. Add instruction files with comprehensive examples
3. Include validation tests and documentation
4. Submit pull request with impact assessment

### Improving Existing Standards

1. Test changes with real-world scenarios
2. Validate backward compatibility
3. Update documentation and examples
4. Include performance impact analysis

## 📊 Measuring Adoption

No benchmark study backs this repository, so it makes no claims about what adopting it will do for
your team. Measure it in your own environment instead — the quality gates emit most of what you
need:

- **PSScriptAnalyzer findings** per pull request, split by severity
- **Test coverage** and pass rate from the Pester gate
- **Security scan findings** — hardcoded secrets and unsafe patterns caught before merge
- **Documentation completeness** — comment-based help present on exported functions, markdownlint
  clean

Track these before and after adoption if you want a real before/after comparison.

## 🆘 Support

### Getting Help

- **Issues**: Report bugs or request features via GitHub Issues
- **Discussions**: Ask questions in GitHub Discussions
- **Documentation**: Check the Documentation folder
- **Troubleshooting**: See organized guides in Troubleshooting folder

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🏆 Acknowledgments

- **PowerShell Community**: For establishing excellent best practices and style guidelines
- **GitHub Copilot Team**: For creating the extensible instruction system
- **Enterprise PowerShell Users**: For real-world validation and feedback

---

**Ready to transform your PowerShell development with AI-assisted enterprise standards?**

🚀 [Get Started Now](#-getting-started) | 📚 [Read the Docs](./Documentation/) | 🤝 [Contribute](#-contributing)
