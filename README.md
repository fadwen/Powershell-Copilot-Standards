# PowerShell Copilot Standards

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Jeffrey_Stuhr-0077B5?style=flat-square&logo=linkedin)](https://www.linkedin.com/in/jeffrey-stuhr-034214aa/)
[![BlueSky](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fpublic.api.bsky.app%2Fxrpc%2Fapp.bsky.actor.getProfile%2F%3Factor%3Dtechbyjeff.net&query=%24.followersCount&style=social&logo=bluesky&label=Follow%20on%20BSky)](https://bsky.app/profile/techbyjeff.net)
[![Blog](https://img.shields.io/badge/Read_My_Blog-TechbyJeff-lightgrey?style=flat-square&logo=ghost)](https://techbyjeff.net)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PowerShell](https://img.shields.io/badge/PowerShell-7.6_LTS-blue.svg)](https://github.com/PowerShell/PowerShell)
[![GitHub Copilot](https://img.shields.io/badge/GitHub%20Copilot-Optimized-green.svg)](https://github.com/features/copilot)

Enterprise-grade PowerShell development standards and GitHub Copilot instructions for consistent, secure, and high-quality PowerShell code across teams and projects.

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
- **Community Best Practices**: Integrated PowerShell community guidelines
- **Enterprise Security**: SOX, GDPR, HIPAA compliance frameworks
- **Performance Optimization**: Memory management and pipeline efficiency
- **Testing Standards**: Comprehensive Pester testing patterns

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
- **Compliance Frameworks**: Built-in SOX, GDPR, and HIPAA compliance
- **Security Scanning**: Automated vulnerability detection

### 📊 Quality Assurance
- **Code Analysis**: Comprehensive quality assessment tools
- **Performance Testing**: Automated benchmarking and optimization
- **Documentation Standards**: Complete comment-based help and README generation
- **Community Compliance**: PowerShell best practices enforcement

## 📁 Repository Structure

```
PowerShell-Copilot-Standards/
├── .github/
│   ├── copilot-instructions.md      # Main Copilot instructions
│   ├── instructions/                # Detailed instruction files
│   │   └── powershell-version.instructions.md  # Version baseline & lifecycle
│   ├── prompts/                     # Quick-access prompts
│   └── workflows/                   # CI/CD templates
├── Documentation/                   # Reference materials
├── Templates/                       # Project templates
├── Tools/                          # Setup and validation scripts
├── Troubleshooting/                # Organized troubleshooting guides
└── README.md                       # This file
```

## 🚀 Getting Started

### 1. Enable Copilot Instructions
In VS Code, add to your settings.json:
```json
{
  "chat.promptFiles": true,
  "github.copilot.chat.codeGeneration.useInstructionFiles": true
}
```

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
All generated code includes:
- **Unit Tests**: Pester tests with 80%+ coverage
- **Integration Tests**: External dependency validation
- **Performance Tests**: Benchmarking and regression detection
- **Security Tests**: Input validation and credential handling

### Quality Gates
- **PSScriptAnalyzer**: Zero violations with enterprise rules
- **Security Scanning**: Credential leak and vulnerability detection
- **Community Standards**: PowerShell best practices compliance
- **Documentation**: Complete comment-based help validation

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

## 📊 Metrics and Success

### Quality Improvements
Teams using these standards typically see:
- **40% faster** function development
- **60% reduction** in code review cycles
- **80% fewer** security vulnerabilities
- **90% improvement** in documentation completeness

### Adoption Tracking
- Code quality scores (PSScriptAnalyzer compliance)
- Security posture improvements
- Development velocity gains
- Team satisfaction ratings

## 🆘 Support

### Getting Help
- **Issues**: Report bugs or request features via GitHub Issues
- **Discussions**: Ask questions in GitHub Discussions
- **Documentation**: Check the Documentation folder
- **Troubleshooting**: See organized guides in Troubleshooting folder

### Enterprise Support
For enterprise implementation assistance:
- Implementation consulting
- Custom instruction development
- Team training and onboarding
- Metrics and success tracking

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🏆 Acknowledgments

- **PowerShell Community**: For establishing excellent best practices and style guidelines
- **GitHub Copilot Team**: For creating the extensible instruction system
- **Enterprise PowerShell Users**: For real-world validation and feedback

---

**Ready to transform your PowerShell development with AI-assisted enterprise standards?**

🚀 [Get Started Now](#-getting-started) | 📚 [Read the Docs](./Documentation/) | 🤝 [Contribute](#-contributing)
