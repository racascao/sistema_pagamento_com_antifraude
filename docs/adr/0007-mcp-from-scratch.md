# ADR 0007: MCP server implemented from scratch

## Context

The investigator exposes tools: account history, geo lookup and
similarity search over historical cases. Both an in process agent
and external clients need to call them. The Model Context Protocol
is the open standard for exposing tools to language model clients,
and SDKs exist that hide its mechanics.

This repository is a learning vehicle. The protocol itself, JSON-RPC
2.0 framing, the initialize handshake, tool listing and tool call
semantics, is exactly the material the implementation should teach.

## Decision

Implement the MCP server directly over encoding/json and stdio in
pkg/mcp, without SDK dependencies. One tool registry serves two
frontends: the stdio MCP session for external clients and direct in
process calls for the investigation advisors.

Tool failures return results flagged isError instead of protocol
errors, so a driving model can read the failure and adapt.

## Consequences

Positive: the protocol is fully visible and testable, the registry
is reused by the rule based advisor and the LLM agent loop, any MCP
client can drive the same investigation tools.

Negative: protocol revisions must be tracked by hand. The surface
implemented is the subset the system needs, tools only.
