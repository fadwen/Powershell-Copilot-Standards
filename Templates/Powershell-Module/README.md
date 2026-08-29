# ModuleName PowerShell Module

## 📖 Overview

**ModuleName** is an enterprise-grade PowerShell module that provides
[describe primary functionality and business value]. This module follows organizational standards for security,
performance, and maintainability.

## 🚀 Quick Start

### Installation

```powershell
# From PowerShell Gallery
Install-PSResource ModuleName -Scope CurrentUser -TrustRepository

# Import the module
Import-Module ModuleName
```

### Basic Usage

```powershell
# Basic function usage
Get-TemplateFunction -Name "ExampleItem"

# Pipeline processing
@("Item1", "Item2") | Get-TemplateFunction -Environment "Production"
```

## 📋 Prerequisites

- PowerShell 7.6 (LTS) — or Windows PowerShell 5.1 if the manifest is configured for it
- Required modules: PSFramework
- Appropriate permissions for target operations

## 💡 Features

- ✅ Enterprise security controls and audit logging
- ✅ Comprehensive error handling with correlation IDs
- ✅ Performance optimization and monitoring
- ✅ Cross-platform compatibility (PowerShell 7.6 LTS; the manifest targets `Core`)
- ✅ Integration with enterprise systems
- ✅ Comprehensive Pester test coverage

## 📚 Documentation

- **Functions**: See individual function help with `Get-Help Function-Name -Detailed`
- **Examples**: Check the Documentation/Examples folder
- **Troubleshooting**: See Troubleshooting folder for organized guides

### Generating Command Help

This template ships without `docs/` or `en-US/` because both are generated. Once your public
functions exist, seed the Markdown from their comment-based help:

```powershell
Install-PSResource -Name Microsoft.PowerShell.PlatyPS
Import-Module ./ModuleName.psd1 -Force

New-MarkdownCommandHelp -ModuleInfo (Get-Module ModuleName) -OutputFolder ./docs -WithModulePage
```

From that point the Markdown under `docs/ModuleName/` is the source you edit, and each public
function gets `.EXTERNALHELP ModuleName-Help.xml` added as the first entry inside its `<# #>` block,
while the rest of the block shrinks to a one-line `.SYNOPSIS`. **Add that keyword only after the
first generation** — it suppresses comment-based help, so adding it earlier means PlatyPS has no
prose to seed from.

Full workflow, build step, and CI drift gate:
[platyps.instructions.md](../../.github/instructions/platyps.instructions.md).

## 🔍 Troubleshooting

For common issues and solutions, see:

- [Common Issues](./Troubleshooting/Common/)
- [Performance Issues](./Troubleshooting/Performance/)
- [Security Issues](./Troubleshooting/Security/)

## 🤝 Contributing

1. Follow the enterprise PowerShell standards
2. Include comprehensive tests for all changes
3. Update documentation and examples
4. Ensure all quality gates pass

## 📄 License

See [LICENSE](../../LICENSE) file for details.
