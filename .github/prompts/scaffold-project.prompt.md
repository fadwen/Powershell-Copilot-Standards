---
mode: 'agent'
description: 'Creates complete project scaffold with CI/CD'
tools: ['codebase', 'githubRepo']
---

Generate complete project scaffold for ${input:projectName:PowerShell-Project}:

**Project Type**: ${input:projectType:PowerShell Module,Script Collection,Enterprise Application}
**CI/CD Platform**: ${input:cicd:GitHub Actions,Azure DevOps,Jenkins,GitLab CI}
**Deployment Target**: ${input:deployment:PowerShell Gallery,Internal Repository,Direct Deployment}

**Generate Complete Structure:**
- Project folder organization following enterprise standards
- CI/CD pipeline configuration for ${input:cicd}
- Quality gates and security scanning integration
- Automated testing and deployment workflows
- Documentation templates and troubleshooting guides
- Configuration management setup
- License and governance files

**Include Enterprise Integrations:**
- Code signing setup for ${input:deployment}
- Security scanning and compliance validation
- Performance benchmarking and monitoring
- Automated release notes and versioning