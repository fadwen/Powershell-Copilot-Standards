# PowerShell Script Collection Layout

A reference layout for script collections that follow enterprise standards.

> This directory documents a structure; it contains no files to copy.
> `Tools/Install-CopilotStandards.ps1 -StandardsType Basic` creates the equivalent folders in a
> target project. For a template with working code, use
> [Templates/Powershell-Module](../Powershell-Module/).

## 📁 Structure

```text
ScriptCollection/
├── Scripts/
│   ├── Administration/
│   ├── Monitoring/
│   └── Utilities/
├── Configuration/
├── Tests/
├── Troubleshooting/
└── Documentation/
```

## 🚀 Usage

1. Create the structure with `Install-CopilotStandards.ps1 -StandardsType Basic`
2. Rename folders as appropriate
3. Follow enterprise PowerShell standards for all scripts
4. Include comprehensive testing and documentation

## 📋 Standards

All scripts must include:

- Comprehensive comment-based help
- Parameter validation
- Error handling with correlation IDs
- Security controls
- Performance considerations
