# Configuration

1. Create the Config File
   ```bash
   mkdir -p ~/.config/promptly
   touch ~/.config/promptly/config.json
   ```

2. Example Configuration
   ```json
   {
     "scheme": "http",
     "host": "webui.example.com",
     "port": 5678,
     "model": "gpt-3.5-turbo"
   }
   ```

3. Parameter Overview
   - model: Model identifier.
   - host (default: api.openai.com): API host address.
   - port (default: 443): API port number.
   - scheme (default: https): API scheme, 'http' or 'https'.
   - path (default: v1/chat/completions): completions API path.
   - organizationId (optional): Your organization ID for OpenAI.
   - rawOutput (default: false): When true, the raw response stream is output.

## Using llama.cpp

Launch the llama server:
```bash
llama-server -hf bartowski/DeepSeek-R1-Distill-Qwen-32B-GGUF
```

Config:
```json
{
  "host": "localhost",
  "port": 8080,
  "scheme": "http"
}
```

## Using Ollama

Config:
```json
{
  "model": "qwen2.5-coder:7b",
  "scheme": "http",
  "port": 11434,
  "host": "localhost",
  "tokenName": "ollama"
}
```

## Using OpenAI

Config:
```json
{
  "organizationId": "org-123",
  "model": "gpt-4o-mini",
  "tokenName": "openai"
}
```

## Using OpenWebUI

Config:
```json
{
  "path": "api/chat/completions",
  "tokenName": "openwebui"
}
```
