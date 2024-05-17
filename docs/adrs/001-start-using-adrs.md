---
status: decided
date: 17-05-2024
deciders: Kamil Kołodziej
---
# Start using ADRs to document any major (non)architectural decisions for the project

## Context and Problem Statement

Right now, we don't have any place where we keep decisions about the project.
We would like to keep a log of any major decisions made which affect the application.

## Decision Drivers

* One place to keep all the decisions made
* Easy to read and write
* Close to the code

## Considered Options

* ADRs inside the repo
* Google Docs
* Confluence

## Decision Outcome

Chosen option: "ADRs inside the repo", because:

- Documentation is near the code and is easily accessible for anyone (contributors)
- No need to lock on to other providers
- Support for Markdown

### Consequences

From now on, when a major decision is made, we are going to write an ADR for it.
Anything that changes the architecture, provider, configuration, etc. should have an ADR. For other cases, the contributor shall decide if one is necessary.
If a request for an ADR arises on PR, it's recommended to provide one with clear explanation for the decision.
We write this to have a record and also to be able to come back to it later on in the future. Because of that, we are going to keep the standard described in the template.

## More Information

We won't write ADRs for decisions that occurred in the past. This is a change that's going to have effect from now on.
