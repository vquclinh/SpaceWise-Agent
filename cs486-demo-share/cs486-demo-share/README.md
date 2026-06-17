# Database Design Agent Project

This project requires each group to build and improve an AI agent that reads a business requirement and generates database design artifacts from requirement analysis to SQL query design.

## 1. Install OpenCode

OpenCode installation guide: [https://opencode.ai/docs/](https://opencode.ai/docs/)

After installation, open the project folder and start OpenCode:

```bash
cd path/to/your/project
opencode
```

During setup, choose the LLM provider and model that your group will use.

> Do not commit API keys, access tokens, or private credentials to Git.

---

### Connect OpenCode to an LLM Model

After installing OpenCode, each group must connect OpenCode to at least one LLM provider before running the database design agent.

OpenCode provider guide: [https://opencode.ai/docs/providers/](https://opencode.ai/docs/providers/)  
OpenCode model guide: [https://opencode.ai/docs/models/](https://opencode.ai/docs/models/)

#### Step 1: Start OpenCode

Open the project folder in the terminal:

```bash
cd path/to/your/project
opencode
```

#### Step 2: Connect an LLM Provider

Inside OpenCode, run:

```text
/connect
```

Then select the LLM provider that your group wants to use, such as OpenAI, Anthropic, Gemini, OpenRouter, OpenCode Zen, or another supported provider.

When requested, enter the API key or login information for the selected provider.

> Do not commit API keys, access tokens, or private credentials to Git.

#### Step 3: Select an LLM Model

After connecting the provider, run:

```text
/models
```

Choose the model that your group wants to use for the project.

## 2. Project Goal

The agent must read the business requirement and generate the following database design artifacts:

1. Business Requirement Analysis
2. Conceptual Database Design
3. Logical Database Design
4. Database Design Validation
5. Database Implementation
6. Sample Data Preparation
7. Query Design

The group must also evaluate and improve the agent during the development process.

---

## 3. Demo Project Structure

The demo Git repository include the following files and folders, your group could adapt it:

```text
.
├── .opencode/
│   ├── commands/
│   │   └── design-db.md
│   └── skills/
│       └── db-design-pipeline/
│           ├── templates/
│           └── SKILL.md
├── req/
│   └── business-requirement.md
├── outputs/
├── AGENTS.md
├── README.md
└── .gitignore
```

---

## 4. Main Files and Folders

| File / Folder | Purpose |
|---|---|
| `.opencode/` | Stores OpenCode commands, skills, and related configuration. |
| `.opencode/commands/design-db.md` | Defines the custom command used to run the database design pipeline. |
| `.opencode/skills/db-design-pipeline/SKILL.md` | Defines the agent workflow, rules, design steps, and output requirements. |
| `.opencode/skills/db-design-pipeline/templates/` | Stores templates used by the agent to generate consistent outputs. |
| `req/business-requirement.md` | Contains the input business requirement. |
| `outputs/` | Stores all generated project artifacts. |
| `AGENTS.md` | Contains project-level instructions for the agent. |
| `README.md` | Explains how to install, run, and evaluate the project. |
| `.gitignore` | Excludes private or unnecessary files from Git. |

---

## 5. How to Run the Agent

Open the project folder:

```bash
cd path/to/your/project
opencode
```

Run the custom command:

```text
/design-db req/business-requirement.md
```

If your group uses a different command name, update this README with the correct command.

---

## 6. Required Output Artifacts

The `outputs/` folder must contain the following files:

```text
01-business-req-analysis-G<Group number>.md
02-erd-design-G<Group number>.md
03-logical-design-G<Group number>.md
04-design-validation-G<Group number>.md
05-db-definition-G<Group number>.sql
06-sample-data-G<Group number>.sql
07-query-design-G<Group number>.sql
```

Example for Group 01:

```text
01-business-req-analysis-G01.md
02-erd-design-G01.md
03-logical-design-G01.md
04-design-validation-G01.md
05-db-definition-G01.sql
06-sample-data-G01.sql
07-query-design-G01.sql
```


## 7. Notes on LLM Model Usage and Cost Control

Using LLM models may consume tokens and API credits. To avoid unnecessary cost:

- Use a cheaper or faster model for early drafts.
- Use a stronger model only for difficult reasoning, validation, and final review.
- Do not repeatedly regenerate all files from scratch.
- Ask the agent to update only the specific file or section that needs improvement.
- Keep prompts short, clear, and specific.
- Avoid sending unnecessary files such as `node_modules/`, `.git/`, logs, or large temporary files.
- Stop the agent if it loops or repeatedly produces similar outputs.
- Never commit API keys or tokens to Git.

Good prompt example:

```text
Read req/business-requirement.md and generate only outputs/01-business-req-analysis-G01.md.
```

Better than:

```text
Read the whole project and redo everything.
```

Another good prompt example:

```text
Use outputs/02-erd-design-G01.md to generate only outputs/03-logical-design-G01.md. Do not modify other files.
```

---

## 8. Academic Integrity

Students may use AI tools to support the project, but they are responsible for reviewing, evaluating, and improving the generated outputs.

Do not submit raw AI output without understanding or validation.

Each group must be able to explain:

- How the agent was configured.
- How the agent was improved.
- Why the final database design is valid.
- How the SQL scripts and queries work.