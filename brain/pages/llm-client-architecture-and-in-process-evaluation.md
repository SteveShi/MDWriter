---
id: llm-client-architecture-and-in-process-evaluation
title: LLM Client Architecture and In-Process MLX Evaluation
category: decision
status: active
tags: [ai, llm, architecture, mlx, chatclientkit]
created: "2026-10-20T00:10:46"
updated: "2026-10-20T00:11:16"
---

<!-- compiled_truth -->
# LLM Client Architecture & In-Process MLX Evaluation

## Context & Evaluation Trigger
Evaluated the architectural feasibility and potential benefits of introducing `ChatClientKit` (by Lakr233) or embedding in-process MLX inference (`mlx-swift-lm`) into MDWriter.

## Architectural Decision
**Reject direct adoption of `ChatClientKit` as a package dependency.** 
Maintain MDWriter's current **Out-of-Process / Local Daemon** architecture (via standard OpenAI-compatible HTTP endpoints to Ollama, LM Studio, oMLX, llama.cpp, Jan, etc.) alongside the native Apple FoundationModels engine.

## Rationale & Trade-offs
1. **Editor Stability & Memory Isolation (High Risk)**:
   - Hosting a 7B/8B model in-process via `mlx-swift-lm` consumes 4GB-8GB of unified memory. Metal Out-of-Memory (OOM) triggers uncatchable `SIGKILL` by macOS, killing the entire text editor and causing unsaved data loss.
   - Managing models through external background services (Ollama) ensures zero memory pressure on the editor process (which stays at ~30MB cold) and protects document integrity if the model server crashes.
2. **Build System & CI Fragility**:
   - `mlx-swift-lm` is a heavyweight dependency with frequent API changes and lengthy C++/Metal compilation times. Adding it would destabilize the clean, automated GitHub Actions release workflow.
3. **Existing Feature Superset**:
   - MDWriter already possesses a tailored Agent engine far beyond generic chat client capabilities: 29 domain-specific writing tools, native Model Context Protocol (MCP) client, Apple `NaturalLanguage` local vector RAG, and Vision OCR.

## Valuable Concepts to Retain & Adopt in Future Roadmap
1. **OpenAI `/v1/responses` Streaming Protocol**:
   - Study `RemoteResponsesChatClient`'s chunk handling to upgrade MDWriter's `OpenAIClient` and `SSEParser` if local providers (Ollama / vLLM / OpenRouter) standardize on the new `/v1/responses` endpoint.
2. **Built-in 0.5B Sub-Model for Zero-Config Ghost Text**:
   - If MDWriter later introduces an out-of-the-box, zero-configuration offline mode for single-sentence predictions (`GhostTextController`), reference the in-process MLX/llama.cpp Swift bindings to bundle an ultra-lightweight (0.5B-1B) quantized model, ideally isolated in an XPC Service to prevent editor crashes.


## Timeline

- time: 2026-10-20T00:10:46
  kind: decision
  summary: "Created this page: LLM Client Architecture and In-Process MLX Evaluation"
  source: created via brain create-page
  affects: [llm-client-architecture-and-in-process-evaluation]

- time: 2026-10-20T00:11:16
  kind: decision
  summary: Evaluation of ChatClientKit and in-process MLX inference vs out-of-process architecture
  source: brain update-truth
  affects: [llm-client-architecture-and-in-process-evaluation]
