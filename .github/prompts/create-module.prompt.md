---
mode: 'agent'
description: 'Generates complete PowerShell module structure'
tools: ['codebase']
---

Create a complete PowerShell module for ${workspaceFolderBasename} with enterprise standards:

**Module Specifications:**
- **Module Name**: ${input:moduleName:MyEnterpriseModule}
- **Primary Purpose**: ${input:purpose:Describe the main business function this module serves}
- **Target Audience**: ${input:audience:System Administrators,Developers,End Users,Automation Systems}
- **Complexity Level**: ${input:complexity:Simple (1-5 functions),Medium (5-15 functions),Complex (15+ functions)}

**Module Structure to Generate:**
```
${input:moduleName}/
├── ${input:moduleName}.psd1           # Module manifest
├── ${input:moduleName}.psm1           # Root module file
├── Public/                            # Exported functions
├── Private/                           # Internal functions
├── Classes/                           # PowerShell classes
├── Tests/                            # Pester test suite
├── Troubleshooting/                  # Documentation
├── Configuration/                    # Config templates
└── README.md                         # Documentation
```

**Requirements:**
- Generate module manifest with proper metadata and versioning
- Create folder structure with sample function templates
- Include comprehensive README with installation instructions
- Generate basic Pester test framework
- Include troubleshooting documentation templates
- Follow semantic versioning and PowerShell Gallery compatibility
